import 'package:flutter/material.dart';
import 'package:kabinet/shared/models/base_model.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Статус занятия
enum LessonStatus {
  scheduled,
  completed,
  cancelled,
  rescheduled;

  String get displayName {
    switch (this) {
      case LessonStatus.scheduled:
        return 'Запланировано';
      case LessonStatus.completed:
        return 'Проведено';
      case LessonStatus.cancelled:
        return 'Отменено';
      case LessonStatus.rescheduled:
        return 'Перенесено';
    }
  }

  static LessonStatus fromString(String value) {
    return LessonStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LessonStatus.scheduled,
    );
  }
}

/// Занятие
class Lesson extends BaseModel {
  final String institutionId;
  final String roomId;
  final String teacherId;
  final String? subjectId;
  final String? lessonTypeId;
  final String? studentId; // Для индивидуальных
  final String? groupId; // Для групповых
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final LessonStatus status;
  final String? comment;
  final String createdBy;
  final String? repeatGroupId; // ID группы повторяющихся занятий
  final String? subscriptionId; // ID подписки для расчёта стоимости

  /// Связанные объекты (join)
  final Room? room;
  final Profile? teacher;
  final Subject? subject;
  final LessonType? lessonType;
  final Student? student;
  final StudentGroup? group;

  /// Участники группового занятия (join)
  final List<LessonStudent>? lessonStudents;

  const Lesson({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.roomId,
    required this.teacherId,
    this.subjectId,
    this.lessonTypeId,
    this.studentId,
    this.groupId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = LessonStatus.scheduled,
    this.comment,
    required this.createdBy,
    this.repeatGroupId,
    this.subscriptionId,
    this.room,
    this.teacher,
    this.subject,
    this.lessonType,
    this.student,
    this.group,
    this.lessonStudents,
  });

  /// Является ли занятие частью повторяющейся серии
  bool get isRepeating => repeatGroupId != null;

  /// Индивидуальное ли занятие
  bool get isIndividual => studentId != null;

  /// Групповое ли занятие
  bool get isGroupLesson => groupId != null;

  /// Количество присутствующих участников группового занятия
  int get attendedCount =>
      lessonStudents?.where((ls) => ls.attended).length ?? 0;

  /// Общее количество участников группового занятия
  int get totalStudentsCount => lessonStudents?.length ?? 0;

  /// Длительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
  }

  /// Название участника (ученик или группа)
  String get participantName {
    if (student != null) return student!.name;
    if (group != null) return group!.name;
    return 'Не указан';
  }

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        roomId: json['room_id'] as String,
        teacherId: json['teacher_id'] as String,
        subjectId: json['subject_id'] as String?,
        lessonTypeId: json['lesson_type_id'] as String?,
        studentId: json['student_id'] as String?,
        groupId: json['group_id'] as String?,
        date: DateTime.parse(json['date'] as String),
        startTime: _parseTime(json['start_time'] as String),
        endTime: _parseTime(json['end_time'] as String),
        status: LessonStatus.fromString(json['status'] as String),
        comment: json['comment'] as String?,
        createdBy: json['created_by'] as String,
        repeatGroupId: json['repeat_group_id'] as String?,
        subscriptionId: json['subscription_id'] as String?,
        room: json['rooms'] != null
            ? Room.fromJson(json['rooms'] as Map<String, dynamic>)
            : null,
        teacher: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
        subject: json['subjects'] != null
            ? Subject.fromJson(json['subjects'] as Map<String, dynamic>)
            : null,
        lessonType: json['lesson_types'] != null
            ? LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>)
            : null,
        student: json['students'] != null
            ? Student.fromJson(json['students'] as Map<String, dynamic>)
            : null,
        group: json['student_groups'] != null
            ? StudentGroup.fromJson(
                json['student_groups'] as Map<String, dynamic>)
            : null,
        lessonStudents: json['lesson_students'] != null
            ? (json['lesson_students'] as List)
                .map((ls) => LessonStudent.fromJson(ls as Map<String, dynamic>))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'room_id': roomId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'lesson_type_id': lessonTypeId,
        'student_id': studentId,
        'group_id': groupId,
        'date': date.toIso8601String().split('T').first,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'status': status.name,
        'comment': comment,
        'created_by': createdBy,
        'repeat_group_id': repeatGroupId,
        'subscription_id': subscriptionId,
      };

  Lesson copyWith({
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    LessonStatus? status,
    String? comment,
    String? repeatGroupId,
    String? subscriptionId,
  }) =>
      Lesson(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        roomId: roomId ?? this.roomId,
        teacherId: teacherId ?? this.teacherId,
        subjectId: subjectId ?? this.subjectId,
        lessonTypeId: lessonTypeId ?? this.lessonTypeId,
        studentId: studentId ?? this.studentId,
        groupId: groupId ?? this.groupId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        status: status ?? this.status,
        comment: comment ?? this.comment,
        createdBy: createdBy,
        repeatGroupId: repeatGroupId ?? this.repeatGroupId,
        subscriptionId: subscriptionId ?? this.subscriptionId,
        room: room,
        teacher: teacher,
        subject: subject,
        lessonType: lessonType,
        student: student,
        group: group,
        lessonStudents: lessonStudents,
      );

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}

/// Участник группового занятия
class LessonStudent {
  final String id;
  final String lessonId;
  final String studentId;
  final bool attended;
  final String? subscriptionId; // ID подписки, с которой списано занятие

  /// Связанный студент (join)
  final Student? student;

  const LessonStudent({
    required this.id,
    required this.lessonId,
    required this.studentId,
    this.attended = true,
    this.subscriptionId,
    this.student,
  });

  factory LessonStudent.fromJson(Map<String, dynamic> json) => LessonStudent(
        id: json['id'] as String,
        lessonId: json['lesson_id'] as String,
        studentId: json['student_id'] as String,
        attended: json['attended'] as bool? ?? true,
        subscriptionId: json['subscription_id'] as String?,
        student: json['students'] != null
            ? Student.fromJson(json['students'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'lesson_id': lessonId,
        'student_id': studentId,
        'attended': attended,
      };
}
