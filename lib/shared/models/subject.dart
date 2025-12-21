import 'package:kabinet/shared/models/base_model.dart';

/// Предмет/направление (Фортепиано, Вокал, Гитара и т.д.)
class Subject extends BaseModel {
  final String institutionId;
  final String name;
  final String? color; // HEX цвет
  final int sortOrder;

  const Subject({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.color,
    this.sortOrder = 0,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'color': color,
        'sort_order': sortOrder,
      };

  Subject copyWith({
    String? name,
    String? color,
    int? sortOrder,
  }) =>
      Subject(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// Связь преподавателя с предметом
class TeacherSubject {
  final String id;
  final String userId;
  final String subjectId;
  final String institutionId;
  final DateTime createdAt;

  /// Связанный предмет (join)
  final Subject? subject;

  const TeacherSubject({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.institutionId,
    required this.createdAt,
    this.subject,
  });

  factory TeacherSubject.fromJson(Map<String, dynamic> json) => TeacherSubject(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        subjectId: json['subject_id'] as String,
        institutionId: json['institution_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        subject: json['subjects'] != null
            ? Subject.fromJson(json['subjects'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'subject_id': subjectId,
        'institution_id': institutionId,
      };
}
