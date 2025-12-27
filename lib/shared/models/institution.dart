import 'package:kabinet/shared/models/base_model.dart';

/// Учебное заведение
class Institution extends BaseModel {
  final String name;
  final String ownerId;
  final String inviteCode;

  /// Начало рабочего времени (час, 0-23). По умолчанию 8.
  final int workStartHour;

  /// Конец рабочего времени (час, 0-23). По умолчанию 22.
  final int workEndHour;

  const Institution({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    this.workStartHour = 8,
    this.workEndHour = 22,
  });

  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String,
        inviteCode: json['invite_code'] as String,
        workStartHour: (json['work_start_hour'] as int?) ?? 8,
        workEndHour: (json['work_end_hour'] as int?) ?? 22,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'owner_id': ownerId,
      };

  Institution copyWith({
    String? name,
    int? workStartHour,
    int? workEndHour,
  }) =>
      Institution(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        name: name ?? this.name,
        ownerId: ownerId,
        inviteCode: inviteCode,
        workStartHour: workStartHour ?? this.workStartHour,
        workEndHour: workEndHour ?? this.workEndHour,
      );
}
