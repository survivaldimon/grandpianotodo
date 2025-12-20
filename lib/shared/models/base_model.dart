/// Базовый класс для всех моделей с общими полями
abstract class BaseModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const BaseModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Архивирована ли запись
  bool get isArchived => archivedAt != null;
}
