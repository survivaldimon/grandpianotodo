import 'package:kabinet/shared/models/lesson_type.dart';

/// Связь ученика с типом занятия (многие-ко-многим)
/// Используется для:
/// - Автозаполнения типа занятия при создании урока
/// - Отображения привязанных типов занятий в карточке ученика
class StudentLessonType {
  final String id;
  final String studentId;
  final String lessonTypeId;
  final String institutionId;
  final DateTime createdAt;

  /// Связанный тип занятия (join)
  final LessonType? lessonType;

  const StudentLessonType({
    required this.id,
    required this.studentId,
    required this.lessonTypeId,
    required this.institutionId,
    required this.createdAt,
    this.lessonType,
  });

  factory StudentLessonType.fromJson(Map<String, dynamic> json) => StudentLessonType(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        lessonTypeId: json['lesson_type_id'] as String,
        institutionId: json['institution_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        lessonType: json['lesson_types'] != null
            ? LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'lesson_type_id': lessonTypeId,
        'institution_id': institutionId,
      };
}
