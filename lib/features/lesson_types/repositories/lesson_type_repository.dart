import 'package:flutter/foundation.dart';
import 'package:kabinet/core/cache/cache_keys.dart';
import 'package:kabinet/core/cache/cache_service.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/lesson_type.dart';

/// Репозиторий для работы с типами занятий
///
/// Использует cache-first паттерн.
/// Справочники кэшируются на 60 минут.
class LessonTypeRepository {
  final _client = SupabaseConfig.client;

  /// Получить все типы занятий заведения (cache-first)
  Future<List<LessonType>> getByInstitution(String institutionId, {bool skipCache = false}) async {
    final cacheKey = CacheKeys.lessonTypes(institutionId);

    // 1. Пробуем из кэша
    if (!skipCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        debugPrint('[LessonTypeRepository] Cache hit for $institutionId (${cached.length} types)');
        _refreshInBackground(institutionId, cacheKey);
        return cached
            .map((item) => LessonType.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    // 2. Загружаем из сети
    final types = await _fetchFromNetwork(institutionId);

    // 3. Кэшируем
    final jsonList = types.map((t) => _lessonTypeToCache(t)).toList();
    await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
    debugPrint('[LessonTypeRepository] Cached ${types.length} types for $institutionId');

    return types;
  }

  /// Загрузить из сети
  Future<List<LessonType>> _fetchFromNetwork(String institutionId) async {
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

  /// Обновить кэш в фоне
  void _refreshInBackground(String institutionId, String cacheKey) {
    Future.microtask(() async {
      try {
        final fresh = await _fetchFromNetwork(institutionId);
        final jsonList = fresh.map((t) => _lessonTypeToCache(t)).toList();
        await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
      } catch (e) {
        debugPrint('[LessonTypeRepository] Background refresh failed: $e');
      }
    });
  }

  /// Конвертировать LessonType в JSON для кэша
  Map<String, dynamic> _lessonTypeToCache(LessonType t) => {
        'id': t.id,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toIso8601String(),
        'archived_at': t.archivedAt?.toIso8601String(),
        'institution_id': t.institutionId,
        'name': t.name,
        'default_duration_minutes': t.defaultDurationMinutes,
        'default_price': t.defaultPrice,
        'is_group': t.isGroup,
        'color': t.color,
      };

  /// Инвалидировать кэш
  Future<void> invalidateCache(String institutionId) async {
    await CacheService.delete(CacheKeys.lessonTypes(institutionId));
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
