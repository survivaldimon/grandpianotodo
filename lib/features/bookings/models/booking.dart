import 'package:flutter/material.dart';
import 'package:kabinet/shared/models/base_model.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Тип повторения бронирования
enum RecurrenceType {
  once, // Разовое бронирование
  weekly, // Еженедельное повторение
}

/// Бронирование кабинета (разовое или постоянное расписание)
///
/// Объединяет функционал простых броней и постоянного расписания ученика:
/// - recurrenceType = once, studentId = null → простая бронь кабинета
/// - recurrenceType = weekly, studentId != null → постоянное расписание ученика
class Booking extends BaseModel {
  final String institutionId;
  final String createdBy;

  // Время
  /// Дата брони (NULL для еженедельных повторений)
  final DateTime? date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  // Повторение
  final RecurrenceType recurrenceType;

  /// День недели для еженедельного повторения (1=Пн, 7=Вс, ISO 8601)
  final int? dayOfWeek;
  final DateTime? validFrom;
  final DateTime? validUntil;

  // Привязка к ученику (для постоянного расписания)
  final String? studentId;
  final String? teacherId;
  final String? subjectId;
  final String? lessonTypeId;

  // Механизм паузы
  final bool isPaused;
  final DateTime? pauseUntil;

  // Временная замена кабинета
  final String? replacementRoomId;
  final DateTime? replacementUntil;

  // Отслеживание сгенерированных занятий
  final DateTime? lastGeneratedDate;

  // Описание (для простых броней)
  final String? description;

  // Шаблон занятия (отображается как занятие, при проведении создаёт lesson)
  final bool isLessonTemplate;

  // Joined данные
  final Profile? creator;
  final List<Room> rooms;
  final Student? student;
  final Profile? teacher;
  final Subject? subject;
  final LessonType? lessonType;
  final Room? replacementRoom;
  final List<BookingException>? exceptions;

  const Booking({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.createdBy,
    this.date,
    required this.startTime,
    required this.endTime,
    this.recurrenceType = RecurrenceType.once,
    this.dayOfWeek,
    this.validFrom,
    this.validUntil,
    this.studentId,
    this.teacherId,
    this.subjectId,
    this.lessonTypeId,
    this.isPaused = false,
    this.pauseUntil,
    this.replacementRoomId,
    this.replacementUntil,
    this.lastGeneratedDate,
    this.description,
    this.isLessonTemplate = false,
    this.creator,
    this.rooms = const [],
    this.student,
    this.teacher,
    this.subject,
    this.lessonType,
    this.replacementRoom,
    this.exceptions,
  });

  // ============================================
  // Computed properties
  // ============================================

  /// Это еженедельное повторение?
  bool get isRecurring => recurrenceType == RecurrenceType.weekly;

  /// Это бронь с привязкой к ученику (постоянное расписание)?
  bool get isStudentBooking => studentId != null;

  /// Это простая бронь кабинета (без ученика)?
  bool get isRoomOnlyBooking => studentId == null;

  /// Это шаблон занятия (отображается как занятие, а не как слот)?
  bool get isLessonTemplateBooking =>
      isRecurring && isLessonTemplate && studentId != null;

  /// Длительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
  }

  /// Названия кабинетов через запятую
  String get roomNames => rooms.map((r) => r.displayName).join(', ');

  /// Первый ID кабинета (для однокабинетных броней)
  String? get primaryRoomId => rooms.isNotEmpty ? rooms.first.id : null;

  /// Короткое название дня недели
  String get dayName {
    if (dayOfWeek == null) return '';
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[dayOfWeek!];
  }

  /// Полное название дня недели
  String get dayNameFull {
    if (dayOfWeek == null) return '';
    const days = [
      '',
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье'
    ];
    return days[dayOfWeek!];
  }

  /// Форматированное время (например "14:00 - 15:00")
  String get timeRange {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  /// Есть ли временная замена кабинета
  bool get hasReplacement =>
      replacementRoomId != null && replacementUntil != null;

  // ============================================
  // Methods
  // ============================================

  /// Возвращает актуальный кабинет ID на указанную дату
  String getEffectiveRoomId(DateTime date) {
    if (replacementRoomId != null &&
        replacementUntil != null &&
        !date.isAfter(replacementUntil!)) {
      return replacementRoomId!;
    }
    return primaryRoomId ?? '';
  }

  /// Возвращает актуальный кабинет на указанную дату
  Room? getEffectiveRoom(DateTime date) {
    if (replacementRoomId != null &&
        replacementUntil != null &&
        !date.isAfter(replacementUntil!) &&
        replacementRoom != null) {
      return replacementRoom;
    }
    return rooms.isNotEmpty ? rooms.first : null;
  }

  /// Проверяет, действует ли бронь на указанную дату
  bool isValidForDate(DateTime date) {
    // Для разовых броней — простая проверка даты
    if (!isRecurring) {
      return this.date?.year == date.year &&
          this.date?.month == date.month &&
          this.date?.day == date.day;
    }

    // Для еженедельных — проверка дня недели
    if (date.weekday != dayOfWeek) return false;

    // Проверка паузы
    if (isPaused) {
      if (pauseUntil == null) return false; // Бессрочная пауза
      if (!date.isAfter(pauseUntil!)) return false; // Ещё на паузе
    }

    // Проверка периода действия
    if (validFrom != null && date.isBefore(validFrom!)) return false;
    if (validUntil != null && date.isAfter(validUntil!)) return false;

    // Проверка исключений
    if (exceptions != null) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      for (final exc in exceptions!) {
        final excDate = DateTime(
          exc.exceptionDate.year,
          exc.exceptionDate.month,
          exc.exceptionDate.day,
        );
        if (excDate == normalizedDate) {
          return false;
        }
      }
    }

    return true;
  }

  /// Проверяет конфликт времени с указанным интервалом
  bool hasTimeOverlap(TimeOfDay otherStart, TimeOfDay otherEnd) {
    final myStartMinutes = startTime.hour * 60 + startTime.minute;
    final myEndMinutes = endTime.hour * 60 + endTime.minute;
    final otherStartMinutes = otherStart.hour * 60 + otherStart.minute;
    final otherEndMinutes = otherEnd.hour * 60 + otherEnd.minute;

    return myStartMinutes < otherEndMinutes && myEndMinutes > otherStartMinutes;
  }

  // ============================================
  // Serialization
  // ============================================

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Парсинг времени из строки "HH:MM:SS"
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    // Парсинг кабинетов из booking_rooms join
    List<Room> parseRooms(dynamic bookingRooms) {
      if (bookingRooms == null) return [];
      if (bookingRooms is! List) return [];

      return bookingRooms
          .where((br) => br['rooms'] != null)
          .map((br) => Room.fromJson(br['rooms'] as Map<String, dynamic>))
          .toList();
    }

    // Парсинг исключений
    List<BookingException>? parseExceptions(dynamic exceptionsData) {
      if (exceptionsData == null) return null;
      if (exceptionsData is! List) return null;

      return exceptionsData
          .map((e) => BookingException.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Парсинг recurrence_type
    RecurrenceType parseRecurrenceType(String? value) {
      if (value == 'weekly') return RecurrenceType.weekly;
      return RecurrenceType.once;
    }

    return Booking(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      institutionId: json['institution_id'] as String,
      createdBy: json['created_by'] as String,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      startTime: parseTime(json['start_time'] as String),
      endTime: parseTime(json['end_time'] as String),
      recurrenceType: parseRecurrenceType(json['recurrence_type'] as String?),
      dayOfWeek: json['day_of_week'] as int?,
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      studentId: json['student_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      lessonTypeId: json['lesson_type_id'] as String?,
      isPaused: json['is_paused'] as bool? ?? false,
      pauseUntil: json['pause_until'] != null
          ? DateTime.parse(json['pause_until'] as String)
          : null,
      replacementRoomId: json['replacement_room_id'] as String?,
      replacementUntil: json['replacement_until'] != null
          ? DateTime.parse(json['replacement_until'] as String)
          : null,
      lastGeneratedDate: json['last_generated_date'] != null
          ? DateTime.parse(json['last_generated_date'] as String)
          : null,
      description: json['description'] as String?,
      isLessonTemplate: json['is_lesson_template'] as bool? ?? false,
      creator: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      rooms: parseRooms(json['booking_rooms']),
      student: json['students'] != null
          ? Student.fromJson(json['students'] as Map<String, dynamic>)
          : null,
      teacher: json['teachers'] != null
          ? Profile.fromJson(json['teachers'] as Map<String, dynamic>)
          : null,
      subject: json['subjects'] != null
          ? Subject.fromJson(json['subjects'] as Map<String, dynamic>)
          : null,
      lessonType: json['lesson_types'] != null
          ? LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>)
          : null,
      replacementRoom: json['replacement_rooms'] != null
          ? Room.fromJson(json['replacement_rooms'] as Map<String, dynamic>)
          : null,
      exceptions: parseExceptions(json['booking_exceptions']),
    );
  }

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'created_by': createdBy,
        'date': date?.toIso8601String().split('T').first,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'recurrence_type': recurrenceType == RecurrenceType.weekly ? 'weekly' : 'once',
        'day_of_week': dayOfWeek,
        'valid_from': validFrom?.toIso8601String().split('T').first,
        'valid_until': validUntil?.toIso8601String().split('T').first,
        'student_id': studentId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'lesson_type_id': lessonTypeId,
        'is_paused': isPaused,
        'pause_until': pauseUntil?.toIso8601String().split('T').first,
        'replacement_room_id': replacementRoomId,
        'replacement_until': replacementUntil?.toIso8601String().split('T').first,
        'description': description,
        'is_lesson_template': isLessonTemplate,
      };

  Booking copyWith({
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    RecurrenceType? recurrenceType,
    int? dayOfWeek,
    DateTime? validFrom,
    DateTime? validUntil,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    bool? isPaused,
    DateTime? pauseUntil,
    String? replacementRoomId,
    DateTime? replacementUntil,
    DateTime? lastGeneratedDate,
    String? description,
    bool? isLessonTemplate,
    List<Room>? rooms,
    Student? student,
    Profile? teacher,
    Subject? subject,
    LessonType? lessonType,
    Room? replacementRoom,
    List<BookingException>? exceptions,
  }) =>
      Booking(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        createdBy: createdBy,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        recurrenceType: recurrenceType ?? this.recurrenceType,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        validFrom: validFrom ?? this.validFrom,
        validUntil: validUntil ?? this.validUntil,
        studentId: studentId ?? this.studentId,
        teacherId: teacherId ?? this.teacherId,
        subjectId: subjectId ?? this.subjectId,
        lessonTypeId: lessonTypeId ?? this.lessonTypeId,
        isPaused: isPaused ?? this.isPaused,
        pauseUntil: pauseUntil ?? this.pauseUntil,
        replacementRoomId: replacementRoomId ?? this.replacementRoomId,
        replacementUntil: replacementUntil ?? this.replacementUntil,
        lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
        description: description ?? this.description,
        isLessonTemplate: isLessonTemplate ?? this.isLessonTemplate,
        creator: creator,
        rooms: rooms ?? this.rooms,
        student: student ?? this.student,
        teacher: teacher ?? this.teacher,
        subject: subject ?? this.subject,
        lessonType: lessonType ?? this.lessonType,
        replacementRoom: replacementRoom ?? this.replacementRoom,
        exceptions: exceptions ?? this.exceptions,
      );
}

/// Исключение из бронирования (дата когда бронь не действует)
class BookingException {
  final String id;
  final String bookingId;
  final DateTime exceptionDate;
  final String? reason;
  final DateTime createdAt;
  final String createdBy;

  const BookingException({
    required this.id,
    required this.bookingId,
    required this.exceptionDate,
    this.reason,
    required this.createdAt,
    required this.createdBy,
  });

  factory BookingException.fromJson(Map<String, dynamic> json) =>
      BookingException(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        exceptionDate: DateTime.parse(json['exception_date'] as String),
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        createdBy: json['created_by'] as String,
      );

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'exception_date': exceptionDate.toIso8601String().split('T').first,
        'reason': reason,
        'created_by': createdBy,
      };
}

/// Связь бронирования с автоматически созданным занятием
class BookingLesson {
  final String id;
  final String bookingId;
  final String lessonId;
  final DateTime generatedDate;
  final DateTime generatedAt;

  const BookingLesson({
    required this.id,
    required this.bookingId,
    required this.lessonId,
    required this.generatedDate,
    required this.generatedAt,
  });

  factory BookingLesson.fromJson(Map<String, dynamic> json) => BookingLesson(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        lessonId: json['lesson_id'] as String,
        generatedDate: DateTime.parse(json['generated_date'] as String),
        generatedAt: DateTime.parse(json['generated_at'] as String),
      );
}
