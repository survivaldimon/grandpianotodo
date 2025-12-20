import 'package:kabinet/shared/models/base_model.dart';

/// Ученик
class Student extends BaseModel {
  final String institutionId;
  final String name;
  final String? phone;
  final String? comment;
  final int prepaidLessonsCount;

  const Student({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.phone,
    this.comment,
    this.prepaidLessonsCount = 0,
  });

  /// Баланс занятий (алиас для prepaidLessonsCount)
  int get balance => prepaidLessonsCount;

  /// Есть ли долг (отрицательный баланс)
  bool get hasDebt => prepaidLessonsCount < 0;

  /// Количество занятий для отображения (с учётом знака)
  String get prepaidDisplay => prepaidLessonsCount >= 0
      ? '$prepaidLessonsCount'
      : '$prepaidLessonsCount';

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        comment: json['comment'] as String?,
        prepaidLessonsCount: json['prepaid_lessons_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'phone': phone,
        'comment': comment,
      };

  Student copyWith({
    String? name,
    String? phone,
    String? comment,
    int? prepaidLessonsCount,
  }) =>
      Student(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        comment: comment ?? this.comment,
        prepaidLessonsCount: prepaidLessonsCount ?? this.prepaidLessonsCount,
      );
}
