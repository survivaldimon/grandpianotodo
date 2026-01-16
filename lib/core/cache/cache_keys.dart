/// Типобезопасные ключи для кэша
///
/// Структура: {entity}_{institutionId} или {entity}_{institutionId}_{date}
class CacheKeys {
  CacheKeys._();

  // === Справочники (редко меняются) ===

  /// Кабинеты заведения
  static String rooms(String institutionId) => 'rooms_$institutionId';

  /// Предметы заведения
  static String subjects(String institutionId) => 'subjects_$institutionId';

  /// Типы занятий заведения
  static String lessonTypes(String institutionId) => 'lesson_types_$institutionId';

  // === Часто обновляемые данные ===

  /// Ученики заведения
  static String students(String institutionId) => 'students_$institutionId';

  /// Занятия заведения на конкретную дату
  static String lessons(String institutionId, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'lessons_${institutionId}_$dateStr';
  }

  /// Занятия кабинета на конкретную дату
  static String lessonsByRoom(String roomId, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'lessons_room_${roomId}_$dateStr';
  }

  /// Бронирования на конкретную дату
  static String bookings(String institutionId, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'bookings_${institutionId}_$dateStr';
  }

  // === Метаданные ===

  /// Время последнего обновления для конкретного ключа
  static String lastUpdated(String key) => '${key}_updated';

  /// ID текущего пользователя
  static const String currentUserId = 'current_user_id';

  /// Последний открытый institutionId
  static const String lastInstitutionId = 'last_institution_id';
}
