import 'package:kabinet/shared/models/profile.dart';

/// Запись истории изменений занятия
class LessonHistory {
  final String id;
  final String lessonId;
  final String changedBy;
  final DateTime changedAt;
  final String action;
  final Map<String, dynamic> changes;

  /// Профиль того, кто изменил (join)
  final Profile? changedByProfile;

  const LessonHistory({
    required this.id,
    required this.lessonId,
    required this.changedBy,
    required this.changedAt,
    required this.action,
    required this.changes,
    this.changedByProfile,
  });

  String get actionDisplayName {
    switch (action) {
      case 'created':
        return 'Создано';
      case 'updated':
        return 'Изменено';
      case 'status_changed':
        return 'Изменён статус';
      case 'archived':
        return 'Архивировано';
      default:
        return action;
    }
  }

  factory LessonHistory.fromJson(Map<String, dynamic> json) => LessonHistory(
        id: json['id'] as String,
        lessonId: json['lesson_id'] as String,
        changedBy: json['changed_by'] as String,
        changedAt: DateTime.parse(json['changed_at'] as String),
        action: json['action'] as String,
        changes: json['changes'] as Map<String, dynamic>,
        changedByProfile: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}
