import 'package:kabinet/shared/models/profile.dart';

/// Связь ученика с преподавателем (многие-ко-многим)
/// Используется для:
/// - Фильтра "Мои ученики"
/// - Отображения привязанных преподавателей в карточке ученика
class StudentTeacher {
  final String id;
  final String studentId;
  final String userId;
  final String institutionId;
  final DateTime createdAt;

  /// Связанный профиль преподавателя (join)
  final Profile? teacher;

  const StudentTeacher({
    required this.id,
    required this.studentId,
    required this.userId,
    required this.institutionId,
    required this.createdAt,
    this.teacher,
  });

  factory StudentTeacher.fromJson(Map<String, dynamic> json) => StudentTeacher(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        userId: json['user_id'] as String,
        institutionId: json['institution_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        teacher: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'user_id': userId,
        'institution_id': institutionId,
      };
}
