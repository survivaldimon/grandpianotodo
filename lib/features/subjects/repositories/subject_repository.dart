import 'package:flutter/foundation.dart';
import 'package:kabinet/core/cache/cache_keys.dart';
import 'package:kabinet/core/cache/cache_service.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Репозиторий для работы с предметами
///
/// Использует cache-first паттерн.
/// Справочники кэшируются на 60 минут.
class SubjectRepository {
  final _client = SupabaseConfig.client;

  /// Получить все предметы заведения (cache-first)
  Future<List<Subject>> getByInstitution(String institutionId, {bool skipCache = false}) async {
    final cacheKey = CacheKeys.subjects(institutionId);

    // 1. Пробуем из кэша
    if (!skipCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        debugPrint('[SubjectRepository] Cache hit for $institutionId (${cached.length} subjects)');
        _refreshInBackground(institutionId, cacheKey);
        return cached
            .map((item) => Subject.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    // 2. Загружаем из сети
    final subjects = await _fetchFromNetwork(institutionId);

    // 3. Кэшируем
    final jsonList = subjects.map((s) => _subjectToCache(s)).toList();
    await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
    debugPrint('[SubjectRepository] Cached ${subjects.length} subjects for $institutionId');

    return subjects;
  }

  /// Загрузить из сети
  Future<List<Subject>> _fetchFromNetwork(String institutionId) async {
    try {
      final data = await _client
          .from('subjects')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('sort_order')
          .order('name');

      return (data as List).map((item) => Subject.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки предметов: $e');
    }
  }

  /// Обновить кэш в фоне
  void _refreshInBackground(String institutionId, String cacheKey) {
    Future.microtask(() async {
      try {
        final fresh = await _fetchFromNetwork(institutionId);
        final jsonList = fresh.map((s) => _subjectToCache(s)).toList();
        await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
      } catch (e) {
        debugPrint('[SubjectRepository] Background refresh failed: $e');
      }
    });
  }

  /// Конвертировать Subject в JSON для кэша
  Map<String, dynamic> _subjectToCache(Subject s) => {
        'id': s.id,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': s.updatedAt.toIso8601String(),
        'archived_at': s.archivedAt?.toIso8601String(),
        'institution_id': s.institutionId,
        'name': s.name,
        'color': s.color,
        'sort_order': s.sortOrder,
      };

  /// Инвалидировать кэш
  Future<void> invalidateCache(String institutionId) async {
    await CacheService.delete(CacheKeys.subjects(institutionId));
  }

  /// Получить предмет по ID
  Future<Subject?> getById(String id) async {
    try {
      final data = await _client
          .from('subjects')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки предмета: $e');
    }
  }

  /// Создать новый предмет
  Future<Subject> create({
    required String institutionId,
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    try {
      final data = await _client
          .from('subjects')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'color': color,
            'sort_order': sortOrder,
          })
          .select()
          .single();

      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания предмета: $e');
    }
  }

  /// Обновить предмет
  Future<Subject> update({
    required String id,
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (color != null) updates['color'] = color;
      if (sortOrder != null) updates['sort_order'] = sortOrder;

      final data = await _client
          .from('subjects')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления предмета: $e');
    }
  }

  /// Архивировать предмет
  Future<void> archive(String id) async {
    try {
      await _client
          .from('subjects')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивирования предмета: $e');
    }
  }

  /// Удалить предмет навсегда
  Future<void> delete(String id) async {
    try {
      await _client.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления предмета: $e');
    }
  }
}
