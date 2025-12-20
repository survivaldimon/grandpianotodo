import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/room.dart';

/// Репозиторий для работы с кабинетами
class RoomRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Получить список кабинетов заведения
  Future<List<Room>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('rooms')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('sort_order')
          .order('name');

      return (data as List).map((item) => Room.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки кабинетов: $e');
    }
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
    int sortOrder = 0,
  }) async {
    try {
      final data = await _client
          .from('rooms')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'number': number,
            'sort_order': sortOrder,
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
  Stream<List<Room>> watchByInstitution(String institutionId) {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .order('sort_order')
        .map((data) => data
            .where((item) => item['archived_at'] == null)
            .map((item) => Room.fromJson(item))
            .toList());
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
