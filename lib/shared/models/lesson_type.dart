import 'package:kabinet/shared/models/base_model.dart';

/// Тип занятия
class LessonType extends BaseModel {
  final String institutionId;
  final String name;
  final int defaultDurationMinutes;
  final double? defaultPrice;
  final bool isGroup;
  final String? color; // HEX цвет

  const LessonType({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.defaultDurationMinutes = 60,
    this.defaultPrice,
    this.isGroup = false,
    this.color,
  });

  factory LessonType.fromJson(Map<String, dynamic> json) => LessonType(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        defaultDurationMinutes: json['default_duration_minutes'] as int? ?? 60,
        defaultPrice: (json['default_price'] as num?)?.toDouble(),
        isGroup: json['is_group'] as bool? ?? false,
        color: json['color'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'default_duration_minutes': defaultDurationMinutes,
        'default_price': defaultPrice,
        'is_group': isGroup,
        'color': color,
      };

  LessonType copyWith({
    String? name,
    int? defaultDurationMinutes,
    double? defaultPrice,
    bool? isGroup,
    String? color,
  }) =>
      LessonType(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        defaultDurationMinutes:
            defaultDurationMinutes ?? this.defaultDurationMinutes,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        isGroup: isGroup ?? this.isGroup,
        color: color ?? this.color,
      );
}
