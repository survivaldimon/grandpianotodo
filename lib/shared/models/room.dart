import 'package:kabinet/shared/models/base_model.dart';

/// Кабинет заведения
class Room extends BaseModel {
  final String institutionId;
  final String name;
  final String? number;
  final int sortOrder;

  const Room({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.number,
    this.sortOrder = 0,
  });

  /// Отображаемое название (номер + название или просто название)
  String get displayName => number != null ? '$number — $name' : name;

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        number: json['number'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'number': number,
        'sort_order': sortOrder,
      };

  Room copyWith({
    String? name,
    String? number,
    int? sortOrder,
  }) =>
      Room(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        number: number ?? this.number,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
