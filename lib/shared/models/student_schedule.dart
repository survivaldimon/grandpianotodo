import 'package:flutter/material.dart';
import 'package:kabinet/shared/models/base_model.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Постоянный слот в расписании ученика
/// Хранит день недели + время, отображается бессрочно
class StudentSchedule extends BaseModel {
  final String institutionId;
  final String studentId;
  final String teacherId;
  final String roomId;
  final String? subjectId;
  final String? lessonTypeId;

  /// День недели (1 = Понедельник, 7 = Воскресенье, ISO 8601)
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  final bool isActive;
  final bool isPaused;
  final DateTime? pauseUntil;

  /// Временная замена кабинета
  final String? replacementRoomId;
  final DateTime? replacementUntil;

  /// Даты действия (опционально)
  final DateTime? validFrom;
  final DateTime? validUntil;

  final String createdBy;

  /// Связанные объекты (join)
  final Student? student;
  final Profile? teacher;
  final Room? room;
  final Room? replacementRoom;
  final Subject? subject;
  final LessonType? lessonType;

  /// Исключения (даты когда слот не действует)
  final List<ScheduleException>? exceptions;

  const StudentSchedule({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.studentId,
    required this.teacherId,
    required this.roomId,
    this.subjectId,
    this.lessonTypeId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.isPaused = false,
    this.pauseUntil,
    this.replacementRoomId,
    this.replacementUntil,
    this.validFrom,
    this.validUntil,
    required this.createdBy,
    this.student,
    this.teacher,
    this.room,
    this.replacementRoom,
    this.subject,
    this.lessonType,
    this.exceptions,
  });

  /// Короткое название дня недели
  String get dayName {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[dayOfWeek];
  }

  /// Полное название дня недели
  String get dayNameFull {
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
    return days[dayOfWeek];
  }

  /// Длительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
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

  /// Возвращает актуальный кабинет ID на указанную дату
  String getEffectiveRoomId(DateTime date) {
    if (replacementRoomId != null &&
        replacementUntil != null &&
        !date.isAfter(replacementUntil!)) {
      return replacementRoomId!;
    }
    return roomId;
  }

  /// Возвращает актуальный кабинет на указанную дату
  Room? getEffectiveRoom(DateTime date) {
    if (replacementRoomId != null &&
        replacementUntil != null &&
        !date.isAfter(replacementUntil!) &&
        replacementRoom != null) {
      return replacementRoom;
    }
    return room;
  }

  /// Проверяет, действует ли слот на указанную дату
  bool isValidForDate(DateTime date) {
    // Проверка активности
    if (!isActive) return false;

    // Проверка дня недели
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

  factory StudentSchedule.fromJson(Map<String, dynamic> json) =>
      StudentSchedule(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        studentId: json['student_id'] as String,
        teacherId: json['teacher_id'] as String,
        roomId: json['room_id'] as String,
        subjectId: json['subject_id'] as String?,
        lessonTypeId: json['lesson_type_id'] as String?,
        dayOfWeek: json['day_of_week'] as int,
        startTime: _parseTime(json['start_time'] as String),
        endTime: _parseTime(json['end_time'] as String),
        isActive: json['is_active'] as bool? ?? true,
        isPaused: json['is_paused'] as bool? ?? false,
        pauseUntil: json['pause_until'] != null
            ? DateTime.parse(json['pause_until'] as String)
            : null,
        replacementRoomId: json['replacement_room_id'] as String?,
        replacementUntil: json['replacement_until'] != null
            ? DateTime.parse(json['replacement_until'] as String)
            : null,
        validFrom: json['valid_from'] != null
            ? DateTime.parse(json['valid_from'] as String)
            : null,
        validUntil: json['valid_until'] != null
            ? DateTime.parse(json['valid_until'] as String)
            : null,
        createdBy: json['created_by'] as String,
        student: json['students'] != null
            ? Student.fromJson(json['students'] as Map<String, dynamic>)
            : null,
        teacher: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
        room: json['rooms'] != null
            ? Room.fromJson(json['rooms'] as Map<String, dynamic>)
            : null,
        replacementRoom: json['replacement_rooms'] != null
            ? Room.fromJson(json['replacement_rooms'] as Map<String, dynamic>)
            : null,
        subject: json['subjects'] != null
            ? Subject.fromJson(json['subjects'] as Map<String, dynamic>)
            : null,
        lessonType: json['lesson_types'] != null
            ? LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>)
            : null,
        exceptions: json['schedule_exceptions'] != null
            ? (json['schedule_exceptions'] as List)
                .map((e) =>
                    ScheduleException.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'student_id': studentId,
        'teacher_id': teacherId,
        'room_id': roomId,
        'subject_id': subjectId,
        'lesson_type_id': lessonTypeId,
        'day_of_week': dayOfWeek,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'is_active': isActive,
        'is_paused': isPaused,
        'pause_until': pauseUntil?.toIso8601String().split('T').first,
        'replacement_room_id': replacementRoomId,
        'replacement_until':
            replacementUntil?.toIso8601String().split('T').first,
        'valid_from': validFrom?.toIso8601String().split('T').first,
        'valid_until': validUntil?.toIso8601String().split('T').first,
        'created_by': createdBy,
      };

  StudentSchedule copyWith({
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isActive,
    bool? isPaused,
    DateTime? pauseUntil,
    String? replacementRoomId,
    DateTime? replacementUntil,
    DateTime? validFrom,
    DateTime? validUntil,
    List<ScheduleException>? exceptions,
  }) =>
      StudentSchedule(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        studentId: studentId,
        teacherId: teacherId ?? this.teacherId,
        roomId: roomId ?? this.roomId,
        subjectId: subjectId ?? this.subjectId,
        lessonTypeId: lessonTypeId ?? this.lessonTypeId,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        isActive: isActive ?? this.isActive,
        isPaused: isPaused ?? this.isPaused,
        pauseUntil: pauseUntil ?? this.pauseUntil,
        replacementRoomId: replacementRoomId ?? this.replacementRoomId,
        replacementUntil: replacementUntil ?? this.replacementUntil,
        validFrom: validFrom ?? this.validFrom,
        validUntil: validUntil ?? this.validUntil,
        createdBy: createdBy,
        student: student,
        teacher: teacher,
        room: room,
        replacementRoom: replacementRoom,
        subject: subject,
        lessonType: lessonType,
        exceptions: exceptions ?? this.exceptions,
      );

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

/// Исключение из расписания (дата когда слот не действует)
class ScheduleException {
  final String id;
  final String scheduleId;
  final DateTime exceptionDate;
  final String? reason;
  final DateTime createdAt;
  final String createdBy;

  const ScheduleException({
    required this.id,
    required this.scheduleId,
    required this.exceptionDate,
    this.reason,
    required this.createdAt,
    required this.createdBy,
  });

  factory ScheduleException.fromJson(Map<String, dynamic> json) =>
      ScheduleException(
        id: json['id'] as String,
        scheduleId: json['schedule_id'] as String,
        exceptionDate: DateTime.parse(json['exception_date'] as String),
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        createdBy: json['created_by'] as String,
      );

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'exception_date': exceptionDate.toIso8601String().split('T').first,
        'reason': reason,
        'created_by': createdBy,
      };
}
