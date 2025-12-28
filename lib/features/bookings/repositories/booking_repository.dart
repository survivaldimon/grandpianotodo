import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/features/bookings/models/booking.dart';

/// Репозиторий для работы с бронированиями кабинетов
class BookingRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Форматирование времени для запросов
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// Базовый select для бронирований (без profiles — загружаем отдельно)
  static const _baseSelect = '''
    *,
    booking_rooms(
      id,
      room_id,
      rooms(id, institution_id, name, number, sort_order, created_at, updated_at, archived_at)
    )
  ''';

  /// Загружает профили для списка бронирований и добавляет их
  Future<List<Booking>> _attachProfiles(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return [];

    // Собираем уникальные user IDs
    final userIds = data
        .map((b) => b['created_by'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    // Загружаем профили
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url, created_at, updated_at')
          .inFilter('id', userIds);

      for (final p in profiles as List) {
        profilesMap[p['id'] as String] = p;
      }
    }

    // Добавляем профили к данным
    return data.map((item) {
      final createdBy = item['created_by'] as String?;
      if (createdBy != null && profilesMap.containsKey(createdBy)) {
        item['profiles'] = profilesMap[createdBy];
      }
      return Booking.fromJson(item);
    }).toList();
  }

  /// Получить брони по заведению и дате
  Future<List<Booking>> getByInstitutionAndDate(
    String institutionId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .order('start_time');

      return _attachProfiles(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирований: $e');
    }
  }

  /// Получить брони по заведению за диапазон дат (для недельного режима)
  Future<List<Booking>> getByInstitutionAndDateRange(
    String institutionId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null)
          .order('date')
          .order('start_time');

      return _attachProfiles(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирований: $e');
    }
  }

  /// Получить бронь по ID
  Future<Booking> getById(String id) async {
    try {
      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('id', id)
          .single();

      final bookings = await _attachProfiles([Map<String, dynamic>.from(data)]);
      return bookings.first;
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирования: $e');
    }
  }

  /// Создать бронирование
  Future<Booking> create({
    required String institutionId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? description,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final dateStr = date.toIso8601String().split('T').first;

      // Создаём бронь
      final bookingData = await _client
          .from('bookings')
          .insert({
            'institution_id': institutionId,
            'created_by': userId,
            'date': dateStr,
            'start_time': _formatTime(startTime),
            'end_time': _formatTime(endTime),
            'description': description,
          })
          .select()
          .single();

      final bookingId = bookingData['id'] as String;

      // Создаём связи с кабинетами
      final roomLinks = roomIds
          .map((roomId) => {
                'booking_id': bookingId,
                'room_id': roomId,
              })
          .toList();

      await _client.from('booking_rooms').insert(roomLinks);

      // Возвращаем полную бронь с joins
      return getById(bookingId);
    } catch (e) {
      throw DatabaseException('Ошибка создания бронирования: $e');
    }
  }

  /// Обновить бронирование
  Future<Booking> update(
    String id, {
    List<String>? roomIds,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (date != null) {
        updates['date'] = date.toIso8601String().split('T').first;
      }
      if (startTime != null) updates['start_time'] = _formatTime(startTime);
      if (endTime != null) updates['end_time'] = _formatTime(endTime);
      if (description != null) updates['description'] = description;

      if (updates.isNotEmpty) {
        await _client.from('bookings').update(updates).eq('id', id);
      }

      // Обновляем связи с кабинетами если переданы
      if (roomIds != null) {
        // Удаляем старые связи
        await _client.from('booking_rooms').delete().eq('booking_id', id);

        // Создаём новые
        final roomLinks = roomIds
            .map((roomId) => {
                  'booking_id': id,
                  'room_id': roomId,
                })
            .toList();

        await _client.from('booking_rooms').insert(roomLinks);
      }

      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка обновления бронирования: $e');
    }
  }

  /// Удалить бронирование
  Future<void> delete(String id) async {
    try {
      // booking_rooms удалятся каскадно
      await _client.from('bookings').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления бронирования: $e');
    }
  }

  /// Архивировать бронирование
  Future<void> archive(String id) async {
    try {
      await _client
          .from('bookings')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации бронирования: $e');
    }
  }

  /// Проверить конфликт брони с существующими бронями
  /// Возвращает список room_id с конфликтами
  Future<List<String>> checkBookingConflicts({
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeBookingId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      final conflictRoomIds = <String>[];

      for (final roomId in roomIds) {
        var query = _client
            .from('booking_rooms')
            .select('booking_id, bookings!inner(id, date, start_time, end_time, archived_at)')
            .eq('room_id', roomId)
            .eq('bookings.date', dateStr)
            .isFilter('bookings.archived_at', null)
            .lt('bookings.start_time', endStr)
            .gt('bookings.end_time', startStr);

        if (excludeBookingId != null) {
          query = query.neq('bookings.id', excludeBookingId);
        }

        final data = await query;
        if ((data as List).isNotEmpty) {
          conflictRoomIds.add(roomId);
        }
      }

      return conflictRoomIds;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов: $e');
    }
  }

  /// Проверить конфликт с занятиями
  /// Возвращает список room_id с конфликтами
  Future<List<String>> checkLessonConflicts({
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      final conflictRoomIds = <String>[];

      for (final roomId in roomIds) {
        final data = await _client
            .from('lessons')
            .select('id')
            .eq('room_id', roomId)
            .eq('date', dateStr)
            .isFilter('archived_at', null)
            .lt('start_time', endStr)
            .gt('end_time', startStr);

        if ((data as List).isNotEmpty) {
          conflictRoomIds.add(roomId);
        }
      }

      return conflictRoomIds;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов с занятиями: $e');
    }
  }

  /// Стрим бронирований по заведению и дате (realtime)
  Stream<List<Booking>> watchByInstitutionAndDate(
    String institutionId,
    DateTime date,
  ) {
    final dateStr = date.toIso8601String().split('T').first;

    // Realtime stream для bookings
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .asyncMap((data) async {
      // Фильтруем по дате и archived_at на клиенте
      final filtered = data.where((item) =>
          item['date'] == dateStr && item['archived_at'] == null);

      if (filtered.isEmpty) return <Booking>[];

      // Загружаем полные данные с joins
      return getByInstitutionAndDate(institutionId, date);
    });
  }
}
