import 'package:flutter/material.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/models/lesson.dart';

/// Исключение (пропущенная дата) для постоянного расписания
class LessonScheduleException {
  final String id;
  final String scheduleId;
  final DateTime exceptionDate;
  final String? reason;
  final DateTime createdAt;

  const LessonScheduleException({
    required this.id,
    required this.scheduleId,
    required this.exceptionDate,
    this.reason,
    required this.createdAt,
  });

  factory LessonScheduleException.fromJson(Map<String, dynamic> json) {
    return LessonScheduleException(
      id: json['id'] as String,
      scheduleId: json['schedule_id'] as String,
      exceptionDate: DateTime.parse(json['exception_date'] as String),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schedule_id': scheduleId,
      'exception_date': '${exceptionDate.year}-${exceptionDate.month.toString().padLeft(2, '0')}-${exceptionDate.day.toString().padLeft(2, '0')}',
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Постоянное расписание занятий.
/// Одна запись = бесконечные виртуальные занятия.
class LessonSchedule {
  final String id;
  final String institutionId;
  final String roomId;
  final String teacherId;
  final String? studentId;
  final String? groupId;
  final String? subjectId;
  final String? lessonTypeId;

  /// День недели (ISO 8601: 1=Понедельник, 7=Воскресенье)
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  /// Период действия расписания
  final DateTime? validFrom;
  final DateTime? validUntil;

  /// Пауза
  final bool isPaused;
  final DateTime? pauseUntil;

  /// Временная замена кабинета
  final String? replacementRoomId;
  final DateTime? replacementUntil;

  /// Метаданные
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? archivedAt;

  /// Исключения (пропущенные даты)
  final List<LessonScheduleException>? exceptions;

  /// Связанные объекты (из join)
  final Student? student;
  final Room? room;
  final Room? replacementRoom;
  final Subject? subject;
  final LessonType? lessonType;
  final InstitutionMember? teacher;

  const LessonSchedule({
    required this.id,
    required this.institutionId,
    required this.roomId,
    required this.teacherId,
    this.studentId,
    this.groupId,
    this.subjectId,
    this.lessonTypeId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.validFrom,
    this.validUntil,
    this.isPaused = false,
    this.pauseUntil,
    this.replacementRoomId,
    this.replacementUntil,
    this.createdBy,
    required this.createdAt,
    this.archivedAt,
    this.exceptions,
    this.student,
    this.room,
    this.replacementRoom,
    this.subject,
    this.lessonType,
    this.teacher,
  });

  /// Проверяет, действует ли расписание на указанную дату
  bool isValidForDate(DateTime date) {
    // Проверяем день недели (ISO 8601: 1=Пн, 7=Вс)
    if (date.weekday != dayOfWeek) return false;

    // Проверяем паузу
    if (isPaused) {
      if (pauseUntil == null) return false; // Бессрочная пауза
      final normalizedPauseUntil = DateTime(pauseUntil!.year, pauseUntil!.month, pauseUntil!.day);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!normalizedDate.isAfter(normalizedPauseUntil)) return false;
    }

    // Проверяем период действия
    if (validFrom != null) {
      final normalizedValidFrom = DateTime(validFrom!.year, validFrom!.month, validFrom!.day);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isBefore(normalizedValidFrom)) return false;
    }
    if (validUntil != null) {
      final normalizedValidUntil = DateTime(validUntil!.year, validUntil!.month, validUntil!.day);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isAfter(normalizedValidUntil)) return false;
    }

    // Проверяем исключения
    if (exceptions != null && exceptions!.isNotEmpty) {
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

  /// Получить эффективный кабинет (с учётом временной замены)
  String getEffectiveRoomId(DateTime date) {
    if (replacementRoomId != null) {
      if (replacementUntil == null) {
        return replacementRoomId!;
      }
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final normalizedUntil = DateTime(replacementUntil!.year, replacementUntil!.month, replacementUntil!.day);
      if (!normalizedDate.isAfter(normalizedUntil)) {
        return replacementRoomId!;
      }
    }
    return roomId;
  }

  /// Получить эффективный кабинет (объект)
  Room? getEffectiveRoom(DateTime date) {
    final effectiveId = getEffectiveRoomId(date);
    if (effectiveId == replacementRoomId && replacementRoom != null) {
      return replacementRoom;
    }
    return room;
  }

  /// Есть ли активная замена кабинета
  bool get hasReplacement => replacementRoomId != null;

  /// Название дня недели
  String get dayName {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[dayOfWeek - 1];
  }

  /// Полное название дня недели
  String get dayNameFull {
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return days[dayOfWeek - 1];
  }

  /// Время в формате "HH:MM - HH:MM"
  String get timeRange {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  /// Продолжительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
  }

  /// Проверка пересечения времени
  bool hasTimeOverlap(TimeOfDay otherStart, TimeOfDay otherEnd) {
    final myStartMinutes = startTime.hour * 60 + startTime.minute;
    final myEndMinutes = endTime.hour * 60 + endTime.minute;
    final otherStartMinutes = otherStart.hour * 60 + otherStart.minute;
    final otherEndMinutes = otherEnd.hour * 60 + otherEnd.minute;

    return myStartMinutes < otherEndMinutes && myEndMinutes > otherStartMinutes;
  }

  /// Конвертирует расписание в виртуальное занятие для отображения
  /// Виртуальное занятие выглядит как обычное, но имеет isVirtual = true
  Lesson toVirtualLesson(DateTime date) {
    final effectiveRoom = getEffectiveRoom(date);
    final now = DateTime.now();

    return Lesson(
      id: 'virtual_${id}_${date.toIso8601String().split('T').first}',
      createdAt: createdAt,
      updatedAt: now,
      institutionId: institutionId,
      roomId: getEffectiveRoomId(date),
      teacherId: teacherId,
      subjectId: subjectId,
      lessonTypeId: lessonTypeId,
      studentId: studentId,
      groupId: groupId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      status: LessonStatus.scheduled,
      createdBy: createdBy ?? teacherId,
      scheduleId: id,
      isVirtual: true,
      scheduleSource: this,
      room: effectiveRoom,
      teacher: teacher?.profile,
      subject: subject,
      lessonType: lessonType,
      student: student,
    );
  }

  factory LessonSchedule.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.parse(value);
      return null;
    }

    // Парсим исключения
    List<LessonScheduleException>? exceptions;
    if (json['lesson_schedule_exceptions'] != null) {
      exceptions = (json['lesson_schedule_exceptions'] as List)
          .map((e) => LessonScheduleException.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Парсим связанные объекты
    Student? student;
    if (json['students'] != null) {
      student = Student.fromJson(json['students'] as Map<String, dynamic>);
    }

    Room? room;
    if (json['rooms'] != null) {
      room = Room.fromJson(json['rooms'] as Map<String, dynamic>);
    }

    Room? replacementRoom;
    if (json['replacement_room'] != null) {
      replacementRoom = Room.fromJson(json['replacement_room'] as Map<String, dynamic>);
    }

    Subject? subject;
    if (json['subjects'] != null) {
      subject = Subject.fromJson(json['subjects'] as Map<String, dynamic>);
    }

    LessonType? lessonType;
    if (json['lesson_types'] != null) {
      lessonType = LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>);
    }

    InstitutionMember? teacher;
    if (json['teacher'] != null) {
      teacher = InstitutionMember.fromJson(json['teacher'] as Map<String, dynamic>);
    }

    return LessonSchedule(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      roomId: json['room_id'] as String,
      teacherId: json['teacher_id'] as String,
      studentId: json['student_id'] as String?,
      groupId: json['group_id'] as String?,
      subjectId: json['subject_id'] as String?,
      lessonTypeId: json['lesson_type_id'] as String?,
      dayOfWeek: json['day_of_week'] as int,
      startTime: parseTime(json['start_time'] as String),
      endTime: parseTime(json['end_time'] as String),
      validFrom: parseDate(json['valid_from']),
      validUntil: parseDate(json['valid_until']),
      isPaused: json['is_paused'] as bool? ?? false,
      pauseUntil: parseDate(json['pause_until']),
      replacementRoomId: json['replacement_room_id'] as String?,
      replacementUntil: parseDate(json['replacement_until']),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      archivedAt: parseDate(json['archived_at']),
      exceptions: exceptions,
      student: student,
      room: room,
      replacementRoom: replacementRoom,
      subject: subject,
      lessonType: lessonType,
      teacher: teacher,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution_id': institutionId,
      'room_id': roomId,
      'teacher_id': teacherId,
      'student_id': studentId,
      'group_id': groupId,
      'subject_id': subjectId,
      'lesson_type_id': lessonTypeId,
      'day_of_week': dayOfWeek,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'valid_from': validFrom != null
          ? '${validFrom!.year}-${validFrom!.month.toString().padLeft(2, '0')}-${validFrom!.day.toString().padLeft(2, '0')}'
          : null,
      'valid_until': validUntil != null
          ? '${validUntil!.year}-${validUntil!.month.toString().padLeft(2, '0')}-${validUntil!.day.toString().padLeft(2, '0')}'
          : null,
      'is_paused': isPaused,
      'pause_until': pauseUntil != null
          ? '${pauseUntil!.year}-${pauseUntil!.month.toString().padLeft(2, '0')}-${pauseUntil!.day.toString().padLeft(2, '0')}'
          : null,
      'replacement_room_id': replacementRoomId,
      'replacement_until': replacementUntil != null
          ? '${replacementUntil!.year}-${replacementUntil!.month.toString().padLeft(2, '0')}-${replacementUntil!.day.toString().padLeft(2, '0')}'
          : null,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  LessonSchedule copyWith({
    String? id,
    String? institutionId,
    String? roomId,
    String? teacherId,
    String? studentId,
    String? groupId,
    String? subjectId,
    String? lessonTypeId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isPaused,
    DateTime? pauseUntil,
    String? replacementRoomId,
    DateTime? replacementUntil,
    String? createdBy,
    DateTime? createdAt,
    DateTime? archivedAt,
    List<LessonScheduleException>? exceptions,
    Student? student,
    Room? room,
    Room? replacementRoom,
    Subject? subject,
    LessonType? lessonType,
    InstitutionMember? teacher,
  }) {
    return LessonSchedule(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      roomId: roomId ?? this.roomId,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      groupId: groupId ?? this.groupId,
      subjectId: subjectId ?? this.subjectId,
      lessonTypeId: lessonTypeId ?? this.lessonTypeId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      isPaused: isPaused ?? this.isPaused,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      replacementRoomId: replacementRoomId ?? this.replacementRoomId,
      replacementUntil: replacementUntil ?? this.replacementUntil,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      exceptions: exceptions ?? this.exceptions,
      student: student ?? this.student,
      room: room ?? this.room,
      replacementRoom: replacementRoom ?? this.replacementRoom,
      subject: subject ?? this.subject,
      lessonType: lessonType ?? this.lessonType,
      teacher: teacher ?? this.teacher,
    );
  }
}
