import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/lesson_type.dart';

/// Репозиторий для работы с типами занятий
class LessonTypeRepository {
  final _client = SupabaseConfig.client;

  /// Получить все типы занятий заведения
  Future<List<LessonType>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('lesson_types')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('name');

      return (data as List).map((item) => LessonType.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки типов занятий: $e');
    }
  }

  /// Получить тип занятия по ID
  Future<LessonType?> getById(String id) async {
    try {
      final data = await _client
          .from('lesson_types')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return LessonType.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки типа занятия: $e');
    }
  }

  /// Создать новый тип занятия
  Future<LessonType> create({
    required String institutionId,
    required String name,
    int defaultDurationMinutes = 60,
    double? defaultPrice,
    bool isGroup = false,
    String? color,
  }) async {
    try {
      final data = await _client
          .from('lesson_types')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'default_duration_minutes': defaultDurationMinutes,
            'default_price': defaultPrice,
            'is_group': isGroup,
            'color': color,
          })
          .select()
          .single();

      return LessonType.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания типа занятия: $e');
    }
  }

  /// Обновить тип занятия
  Future<LessonType> update({
    required String id,
    String? name,
    int? defaultDurationMinutes,
    double? defaultPrice,
    bool? isGroup,
    String? color,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (defaultDurationMinutes != null) {
        updates['default_duration_minutes'] = defaultDurationMinutes;
      }
      if (defaultPrice != null) updates['default_price'] = defaultPrice;
      if (isGroup != null) updates['is_group'] = isGroup;
      if (color != null) updates['color'] = color;

      final data = await _client
          .from('lesson_types')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return LessonType.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления типа занятия: $e');
    }
  }

  /// Архивировать тип занятия
  Future<void> archive(String id) async {
    try {
      await _client
          .from('lesson_types')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивирования типа занятия: $e');
    }
  }

  /// Восстановить тип занятия
  Future<void> restore(String id) async {
    try {
      await _client
          .from('lesson_types')
          .update({'archived_at': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка восстановления типа занятия: $e');
    }
  }

  /// Удалить тип занятия навсегда
  Future<void> delete(String id) async {
    try {
      await _client.from('lesson_types').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления типа занятия: $e');
    }
  }
}
