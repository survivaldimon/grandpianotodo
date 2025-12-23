import 'package:kabinet/shared/models/subject.dart';

/// Связь ученика с предметом/направлением (многие-ко-многим)
/// Используется для:
/// - Отображения изучаемых предметов в карточке ученика
/// - Статистики по направлениям
class StudentSubject {
  final String id;
  final String studentId;
  final String subjectId;
  final String institutionId;
  final DateTime createdAt;

  /// Связанный предмет (join)
  final Subject? subject;

  const StudentSubject({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.institutionId,
    required this.createdAt,
    this.subject,
  });

  factory StudentSubject.fromJson(Map<String, dynamic> json) => StudentSubject(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        subjectId: json['subject_id'] as String,
        institutionId: json['institution_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        subject: json['subjects'] != null
            ? Subject.fromJson(json['subjects'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'subject_id': subjectId,
        'institution_id': institutionId,
      };
}
