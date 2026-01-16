import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/cache/cache_keys.dart';
import 'package:kabinet/core/cache/cache_service.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/room.dart';

/// Репозиторий для работы с кабинетами
///
/// Использует cache-first паттерн для мгновенного отображения.
/// Справочники (rooms) кэшируются на 60 минут т.к. редко меняются.
class RoomRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Получить список кабинетов заведения (cache-first)
  Future<List<Room>> getByInstitution(String institutionId, {bool skipCache = false}) async {
    final cacheKey = CacheKeys.rooms(institutionId);

    // 1. Пробуем из кэша
    if (!skipCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        debugPrint('[RoomRepository] Cache hit for $institutionId (${cached.length} rooms)');
        _refreshInBackground(institutionId, cacheKey);
        return cached
            .map((item) => Room.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    // 2. Загружаем из сети
    final rooms = await _fetchFromNetwork(institutionId);

    // 3. Кэшируем (справочники на 60 минут)
    final jsonList = rooms.map((r) => _roomToCache(r)).toList();
    await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
    debugPrint('[RoomRepository] Cached ${rooms.length} rooms for $institutionId');

    return rooms;
  }

  /// Загрузить из сети
  Future<List<Room>> _fetchFromNetwork(String institutionId) async {
    try {
      final data = await _client
          .from('rooms')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      return (data as List).map((item) => Room.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки кабинетов: $e');
    }
  }

  /// Обновить кэш в фоне
  void _refreshInBackground(String institutionId, String cacheKey) {
    Future.microtask(() async {
      try {
        final fresh = await _fetchFromNetwork(institutionId);
        final jsonList = fresh.map((r) => _roomToCache(r)).toList();
        await CacheService.put(cacheKey, jsonList, ttlMinutes: 60);
      } catch (e) {
        debugPrint('[RoomRepository] Background refresh failed: $e');
      }
    });
  }

  /// Конвертировать Room в JSON для кэша
  Map<String, dynamic> _roomToCache(Room r) => {
        'id': r.id,
        'created_at': r.createdAt.toIso8601String(),
        'updated_at': r.updatedAt.toIso8601String(),
        'archived_at': r.archivedAt?.toIso8601String(),
        'institution_id': r.institutionId,
        'name': r.name,
        'number': r.number,
        'sort_order': r.sortOrder,
      };

  /// Инвалидировать кэш
  Future<void> invalidateCache(String institutionId) async {
    await CacheService.delete(CacheKeys.rooms(institutionId));
  }

  /// Получить кабинет по ID
  Future<Room> getById(String id) async {
    try {
      final data = await _client
          .from('rooms')
          .select()
          .eq('id', id)
          .single();

      return Room.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки кабинета: $e');
    }
  }

  /// Создать кабинет
  Future<Room> create({
    required String institutionId,
    required String name,
    String? number,
  }) async {
    try {
      // Получаем максимальный sort_order для заведения
      final maxSortOrder = await _client
          .from('rooms')
          .select('sort_order')
          .eq('institution_id', institutionId)
          .order('sort_order', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextSortOrder = (maxSortOrder?['sort_order'] as int? ?? -1) + 1;

      final data = await _client
          .from('rooms')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'number': number,
            'sort_order': nextSortOrder,
          })
          .select()
          .single();

      return Room.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания кабинета: $e');
    }
  }

  /// Обновить кабинет
  Future<Room> update(
    String id, {
    String? name,
    String? number,
    int? sortOrder,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (number != null) updates['number'] = number;
      if (sortOrder != null) updates['sort_order'] = sortOrder;

      final data = await _client
          .from('rooms')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Room.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления кабинета: $e');
    }
  }

  /// Удалить кабинет
  Future<void> delete(String id) async {
    try {
      await _client.from('rooms').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления кабинета: $e');
    }
  }

  /// Архивировать кабинет
  Future<void> archive(String id) async {
    try {
      await _client
          .from('rooms')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации кабинета: $e');
    }
  }

  /// Восстановить кабинет из архива
  Future<void> restore(String id) async {
    try {
      await _client
          .from('rooms')
          .update({'archived_at': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка восстановления кабинета: $e');
    }
  }

  /// Стрим кабинетов (realtime)
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Room>> watchByInstitution(String institutionId) {
    final controller = StreamController<List<Room>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final rooms = await getByInstitution(institutionId);
        if (!controller.isClosed) {
          controller.add(rooms);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Сразу загружаем начальные данные
    loadAndEmit();

    // 2. Подписываемся на изменения с обработкой ошибок
    // ВАЖНО: Пропускаем первое событие (initial snapshot), т.к. уже загрузили данные
    bool isFirstEvent = true;
    final subscription = _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .listen(
          (data) {
            if (isFirstEvent) {
              isFirstEvent = false;
              return; // Пропускаем initial snapshot
            }
            // Фильтруем архивированные, парсим и СОРТИРУЕМ
            final rooms = data
                .where((item) => item['archived_at'] == null)
                .map((item) => Room.fromJson(item))
                .toList()
              ..sort((a, b) {
                final sortCompare = a.sortOrder.compareTo(b.sortOrder);
                if (sortCompare != 0) return sortCompare;
                return a.createdAt.compareTo(b.createdAt);
              });
            if (!controller.isClosed) {
              controller.add(rooms);
            }
          },
          onError: (e) {
            debugPrint('[RoomRepository] watchByInstitution error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Изменить порядок кабинетов
  Future<void> reorder(List<Room> rooms) async {
    try {
      for (int i = 0; i < rooms.length; i++) {
        await _client
            .from('rooms')
            .update({'sort_order': i})
            .eq('id', rooms[i].id);
      }
    } catch (e) {
      throw DatabaseException('Ошибка изменения порядка: $e');
    }
  }

  /// Поменять местами два кабинета
  Future<void> swap(String roomId1, int sortOrder1, String roomId2, int sortOrder2) async {
    try {
      await _client
          .from('rooms')
          .update({'sort_order': sortOrder2})
          .eq('id', roomId1);
      await _client
          .from('rooms')
          .update({'sort_order': sortOrder1})
          .eq('id', roomId2);
    } catch (e) {
      throw DatabaseException('Ошибка изменения порядка: $e');
    }
  }
}
