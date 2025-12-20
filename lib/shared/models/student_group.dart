import 'package:kabinet/shared/models/base_model.dart';
import 'package:kabinet/shared/models/student.dart';

/// Группа учеников
class StudentGroup extends BaseModel {
  final String institutionId;
  final String name;
  final String? comment;

  /// Список участников группы (join)
  final List<Student>? members;

  const StudentGroup({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.comment,
    this.members,
  });

  int get membersCount => members?.length ?? 0;

  factory StudentGroup.fromJson(Map<String, dynamic> json) => StudentGroup(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        comment: json['comment'] as String?,
        members: json['student_group_members'] != null
            ? (json['student_group_members'] as List)
                .map((m) =>
                    Student.fromJson(m['students'] as Map<String, dynamic>))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'comment': comment,
      };

  StudentGroup copyWith({
    String? name,
    String? comment,
    List<Student>? members,
  }) =>
      StudentGroup(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        comment: comment ?? this.comment,
        members: members ?? this.members,
      );
}

/// Связь ученика с группой
class StudentGroupMember {
  final String id;
  final String groupId;
  final String studentId;
  final DateTime joinedAt;

  const StudentGroupMember({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.joinedAt,
  });

  factory StudentGroupMember.fromJson(Map<String, dynamic> json) =>
      StudentGroupMember(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        studentId: json['student_id'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'student_id': studentId,
      };
}
