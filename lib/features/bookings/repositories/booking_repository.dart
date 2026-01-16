import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/features/bookings/models/booking.dart';

/// Репозиторий для работы с бронированиями кабинетов
/// Поддерживает как разовые брони, так и повторяющееся расписание
class BookingRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Форматирование времени для запросов
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// Базовый select для бронирований со всеми связями
  static const _baseSelect = '''
    *,
    booking_rooms(
      id,
      room_id,
      rooms(id, institution_id, name, number, sort_order, created_at, updated_at, archived_at)
    ),
    students(id, institution_id, name, phone, comment, prepaid_lessons_count, legacy_balance, archived_at, created_at, updated_at),
    subjects(id, institution_id, name, color, archived_at, created_at, updated_at),
    lesson_types(id, institution_id, name, color, archived_at, created_at, updated_at),
    booking_exceptions(id, booking_id, exception_date, reason, created_at, created_by)
  ''';

  /// Загружает профили для списка бронирований и добавляет их
  Future<List<Booking>> _attachProfiles(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return [];

    // Собираем уникальные user IDs (created_by и teacher_id)
    final userIds = <String>{};
    for (final b in data) {
      if (b['created_by'] != null) userIds.add(b['created_by'] as String);
      if (b['teacher_id'] != null) userIds.add(b['teacher_id'] as String);
    }

    // Загружаем профили
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url, created_at, updated_at')
          .inFilter('id', userIds.toList());

      for (final p in profiles as List) {
        profilesMap[p['id'] as String] = p;
      }
    }

    // Добавляем профили к данным
    return data.map((item) {
      final createdBy = item['created_by'] as String?;
      final teacherId = item['teacher_id'] as String?;

      if (createdBy != null && profilesMap.containsKey(createdBy)) {
        item['profiles'] = profilesMap[createdBy];
      }
      if (teacherId != null && profilesMap.containsKey(teacherId)) {
        item['teachers'] = profilesMap[teacherId];
      }

      return Booking.fromJson(item);
    }).toList();
  }

  // ============================================
  // Получение данных
  // ============================================

  /// Получить разовые брони по заведению и дате
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
          .eq('recurrence_type', 'once')
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .order('start_time');

      return _attachProfiles(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирований: $e');
    }
  }

  /// Получить все брони (разовые и повторяющиеся) для даты
  /// Фильтрует weekly по дню недели и учитывает исключения/паузы
  Future<List<Booking>> getAllForDate(
    String institutionId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final dayOfWeek = date.weekday; // 1-7 (ISO)

      // Получаем разовые брони на эту дату
      final onceBookings = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'once')
          .eq('date', dateStr)
          .isFilter('archived_at', null);

      // Получаем еженедельные брони для этого дня недели
      final weeklyBookings = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'weekly')
          .eq('day_of_week', dayOfWeek)
          .isFilter('archived_at', null);

      final allData = [
        ...List<Map<String, dynamic>>.from(onceBookings),
        ...List<Map<String, dynamic>>.from(weeklyBookings),
      ];

      final bookings = await _attachProfiles(allData);

      // Фильтруем weekly брони по validForDate (паузы, исключения, период)
      return bookings.where((b) => b.isValidForDate(date)).toList()
        ..sort((a, b) {
          final aMin = a.startTime.hour * 60 + a.startTime.minute;
          final bMin = b.startTime.hour * 60 + b.startTime.minute;
          return aMin.compareTo(bMin);
        });
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирований: $e');
    }
  }

  /// Получить все еженедельные брони с привязкой к ученику для дня недели
  /// Используется для автоматической генерации занятий
  Future<List<Booking>> getRecurringStudentBookings({
    required String institutionId,
    required int dayOfWeek,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'weekly')
          .eq('day_of_week', dayOfWeek)
          .not('student_id', 'is', null) // Только с учеником
          .eq('is_paused', false)
          .isFilter('archived_at', null)
          // Фильтрация по valid_from/valid_until в WHERE
          .or('valid_from.is.null,valid_from.lte.$dateStr')
          .or('valid_until.is.null,valid_until.gte.$dateStr');

      final bookings = await _attachProfiles(List<Map<String, dynamic>>.from(data));

      // Дополнительная фильтрация по исключениям на клиенте
      return bookings.where((b) => b.isValidForDate(date)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки повторяющихся бронирований: $e');
    }
  }

  /// Получить еженедельные брони ученика
  Future<List<Booking>> getByStudent(String studentId) async {
    try {
      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('student_id', studentId)
          .eq('recurrence_type', 'weekly')
          .isFilter('archived_at', null)
          .order('day_of_week')
          .order('start_time');

      return _attachProfiles(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки расписания ученика: $e');
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

      // Разовые брони
      final onceData = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'once')
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null);

      // Еженедельные брони (все)
      final weeklyData = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'weekly')
          .isFilter('archived_at', null);

      final allData = [
        ...List<Map<String, dynamic>>.from(onceData),
        ...List<Map<String, dynamic>>.from(weeklyData),
      ];

      final bookings = await _attachProfiles(allData);

      return bookings
        ..sort((a, b) {
          // Сначала по дате/дню недели, потом по времени
          final aDay = a.date?.weekday ?? a.dayOfWeek ?? 0;
          final bDay = b.date?.weekday ?? b.dayOfWeek ?? 0;
          if (aDay != bDay) return aDay.compareTo(bDay);

          final aMin = a.startTime.hour * 60 + a.startTime.minute;
          final bMin = b.startTime.hour * 60 + b.startTime.minute;
          return aMin.compareTo(bMin);
        });
    } catch (e) {
      throw DatabaseException('Ошибка загрузки бронирований: $e');
    }
  }

  /// Получить все активные еженедельные брони заведения
  Future<List<Booking>> getWeeklyByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('bookings')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('recurrence_type', 'weekly')
          .isFilter('archived_at', null)
          .order('day_of_week')
          .order('start_time');

      debugPrint('BookingRepository: getWeeklyByInstitution found ${(data as List).length} weekly bookings');

      final bookings = await _attachProfiles(List<Map<String, dynamic>>.from(data));

      // Логируем информацию о каждом слоте
      for (final b in bookings) {
        debugPrint('BookingRepository: Weekly booking id=${b.id}, dayOfWeek=${b.dayOfWeek}, rooms=${b.rooms.length}, primaryRoomId=${b.primaryRoomId}');
      }

      return bookings;
    } catch (e) {
      throw DatabaseException('Ошибка загрузки еженедельных бронирований: $e');
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

  // ============================================
  // Создание
  // ============================================

  /// Создать разовое бронирование
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
            'recurrence_type': 'once',
            'date': dateStr,
            'start_time': _formatTime(startTime),
            'end_time': _formatTime(endTime),
            'description': description,
          })
          .select()
          .single();

      final bookingId = bookingData['id'] as String;

      // Создаём связи с кабинетами
      await _insertBookingRooms(bookingId, roomIds);

      // Возвращаем полную бронь с joins
      return getById(bookingId);
    } catch (e) {
      throw DatabaseException('Ошибка создания бронирования: $e');
    }
  }

  /// Создать еженедельное бронирование (постоянное расписание)
  /// Если isLessonTemplate = true, создаёт шаблон занятия (отображается как занятие)
  Future<Booking> createRecurring({
    required String institutionId,
    required String roomId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    DateTime? validFrom,
    DateTime? validUntil,
    String? description,
    bool isLessonTemplate = false,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;

      // Создаём бронь
      final bookingData = await _client
          .from('bookings')
          .insert({
            'institution_id': institutionId,
            'created_by': userId,
            'recurrence_type': 'weekly',
            'day_of_week': dayOfWeek,
            'start_time': _formatTime(startTime),
            'end_time': _formatTime(endTime),
            'student_id': studentId,
            'teacher_id': teacherId ?? userId,
            'subject_id': subjectId,
            'lesson_type_id': lessonTypeId,
            'valid_from': validFrom?.toIso8601String().split('T').first,
            'valid_until': validUntil?.toIso8601String().split('T').first,
            'description': description,
            'is_lesson_template': isLessonTemplate,
          })
          .select()
          .single();

      final bookingId = bookingData['id'] as String;

      // Создаём связь с кабинетом
      await _insertBookingRooms(bookingId, [roomId]);

      // Пытаемся получить полные данные, но если не получится — возвращаем базовые
      try {
        return await getById(bookingId);
      } catch (_) {
        // Если не удалось загрузить полные данные, возвращаем минимальный объект
        // Это может произойти из-за задержки репликации
        debugPrint('BookingRepository: getById failed after create, returning basic booking');
        return Booking.fromJson({
          ...bookingData,
          'booking_rooms': [], // Будет загружено при следующем запросе
        });
      }
    } catch (e) {
      throw DatabaseException('Ошибка создания постоянного расписания: $e');
    }
  }

  /// Создать несколько еженедельных бронирований (для нескольких дней сразу)
  Future<List<Booking>> createRecurringBatch({
    required String institutionId,
    required String roomId,
    required List<DayTimeSlot> slots,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    DateTime? validFrom,
    DateTime? validUntil,
    bool isLessonTemplate = false,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final createdBookings = <Booking>[];

      for (final slot in slots) {
        final booking = await createRecurring(
          institutionId: institutionId,
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
          studentId: studentId,
          teacherId: teacherId ?? userId,
          subjectId: subjectId,
          lessonTypeId: lessonTypeId,
          validFrom: validFrom,
          validUntil: validUntil,
          isLessonTemplate: isLessonTemplate,
        );
        createdBookings.add(booking);
      }

      return createdBookings;
    } catch (e) {
      throw DatabaseException('Ошибка создания постоянного расписания: $e');
    }
  }

  Future<void> _insertBookingRooms(String bookingId, List<String> roomIds) async {
    if (roomIds.isEmpty) {
      debugPrint('BookingRepository: _insertBookingRooms called with empty roomIds!');
      return;
    }

    final roomLinks = roomIds
        .map((roomId) => {
              'booking_id': bookingId,
              'room_id': roomId,
            })
        .toList();

    debugPrint('BookingRepository: Inserting booking_rooms: $roomLinks');

    try {
      await _client.from('booking_rooms').insert(roomLinks);
      debugPrint('BookingRepository: booking_rooms inserted successfully');

      // Проверяем что записи создались
      final check = await _client
          .from('booking_rooms')
          .select('id, room_id')
          .eq('booking_id', bookingId);
      debugPrint('BookingRepository: Verification - found ${(check as List).length} booking_rooms');
    } catch (e) {
      debugPrint('BookingRepository: ERROR inserting booking_rooms: $e');
      rethrow;
    }
  }

  // ============================================
  // Обновление
  // ============================================

  /// Обновить бронирование
  Future<Booking> update(
    String id, {
    List<String>? roomIds,
    DateTime? date,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    bool? isPaused,
    DateTime? pauseUntil,
    String? replacementRoomId,
    DateTime? replacementUntil,
    DateTime? validFrom,
    DateTime? validUntil,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (date != null) updates['date'] = date.toIso8601String().split('T').first;
      if (dayOfWeek != null) updates['day_of_week'] = dayOfWeek;
      if (startTime != null) updates['start_time'] = _formatTime(startTime);
      if (endTime != null) updates['end_time'] = _formatTime(endTime);
      if (studentId != null) updates['student_id'] = studentId;
      if (teacherId != null) updates['teacher_id'] = teacherId;
      if (subjectId != null) updates['subject_id'] = subjectId;
      if (lessonTypeId != null) updates['lesson_type_id'] = lessonTypeId;
      if (isPaused != null) updates['is_paused'] = isPaused;
      if (pauseUntil != null) {
        updates['pause_until'] = pauseUntil.toIso8601String().split('T').first;
      }
      if (replacementRoomId != null) updates['replacement_room_id'] = replacementRoomId;
      if (replacementUntil != null) {
        updates['replacement_until'] = replacementUntil.toIso8601String().split('T').first;
      }
      if (validFrom != null) updates['valid_from'] = validFrom.toIso8601String().split('T').first;
      if (validUntil != null) updates['valid_until'] = validUntil.toIso8601String().split('T').first;
      if (description != null) updates['description'] = description;

      if (updates.isNotEmpty) {
        await _client.from('bookings').update(updates).eq('id', id);
      }

      // Обновляем связи с кабинетами если переданы
      if (roomIds != null) {
        await _client.from('booking_rooms').delete().eq('booking_id', id);
        await _insertBookingRooms(id, roomIds);
      }

      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка обновления бронирования: $e');
    }
  }

  /// Обновить last_generated_date после создания занятия
  Future<void> updateLastGenerated(String bookingId, DateTime date) async {
    try {
      await _client
          .from('bookings')
          .update({'last_generated_date': date.toIso8601String().split('T').first})
          .eq('id', bookingId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления last_generated_date: $e');
    }
  }

  /// Приостановить бронирование
  Future<Booking> pause(String id, DateTime? untilDate) async {
    return update(id, isPaused: true, pauseUntil: untilDate);
  }

  /// Возобновить бронирование
  Future<Booking> resume(String id) async {
    try {
      await _client
          .from('bookings')
          .update({'is_paused': false, 'pause_until': null})
          .eq('id', id);
      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка возобновления бронирования: $e');
    }
  }

  /// Установить временную замену кабинета
  Future<Booking> setReplacement(
    String id,
    String replacementRoomId,
    DateTime replacementUntil,
  ) async {
    return update(
      id,
      replacementRoomId: replacementRoomId,
      replacementUntil: replacementUntil,
    );
  }

  /// Снять временную замену кабинета
  Future<Booking> clearReplacement(String id) async {
    try {
      await _client
          .from('bookings')
          .update({'replacement_room_id': null, 'replacement_until': null})
          .eq('id', id);
      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка снятия замены кабинета: $e');
    }
  }

  // ============================================
  // Исключения
  // ============================================

  /// Добавить исключение (дату когда бронь не действует)
  Future<BookingException> addException({
    required String bookingId,
    required DateTime exceptionDate,
    String? reason,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;

      final data = await _client
          .from('booking_exceptions')
          .insert({
            'booking_id': bookingId,
            'exception_date': exceptionDate.toIso8601String().split('T').first,
            'reason': reason,
            'created_by': userId,
          })
          .select()
          .single();

      return BookingException.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка добавления исключения: $e');
    }
  }

  /// Удалить исключение
  Future<void> removeException(String exceptionId) async {
    try {
      await _client.from('booking_exceptions').delete().eq('id', exceptionId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления исключения: $e');
    }
  }

  /// Получить исключения для бронирования
  Future<List<BookingException>> getExceptions(String bookingId) async {
    try {
      final data = await _client
          .from('booking_exceptions')
          .select('*')
          .eq('booking_id', bookingId)
          .order('exception_date');

      return (data as List)
          .map((e) => BookingException.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки исключений: $e');
    }
  }

  // ============================================
  // Удаление
  // ============================================

  /// Удалить бронирование
  Future<void> delete(String id) async {
    try {
      // booking_rooms и booking_exceptions удалятся каскадно
      await _client.from('bookings').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления бронирования: $e');
    }
  }

  /// Архивировать бронирование
  Future<Booking> archive(String id) async {
    try {
      await _client
          .from('bookings')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации бронирования: $e');
    }
  }

  /// Разархивировать бронирование
  Future<Booking> unarchive(String id) async {
    try {
      await _client
          .from('bookings')
          .update({'archived_at': null})
          .eq('id', id);
      return getById(id);
    } catch (e) {
      throw DatabaseException('Ошибка разархивации бронирования: $e');
    }
  }

  // ============================================
  // Проверка конфликтов
  // ============================================

  /// Проверить конфликт брони с существующими бронями
  Future<List<String>> checkBookingConflicts({
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeBookingId,
  }) async {
    try {
      if (roomIds.isEmpty) return [];

      final dateStr = date.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      var query = _client
          .from('booking_rooms')
          .select('room_id, bookings!inner(id, date, start_time, end_time, archived_at)')
          .inFilter('room_id', roomIds)
          .eq('bookings.date', dateStr)
          .isFilter('bookings.archived_at', null)
          .lt('bookings.start_time', endStr)
          .gt('bookings.end_time', startStr);

      if (excludeBookingId != null) {
        query = query.neq('bookings.id', excludeBookingId);
      }

      final data = await query;

      final conflictRoomIds = (data as List)
          .map((item) => item['room_id'] as String)
          .toSet()
          .toList();

      return conflictRoomIds;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов: $e');
    }
  }

  /// Проверить конфликт с еженедельными бронями для дня недели
  Future<bool> hasWeeklyConflict({
    required String roomId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeBookingId,
  }) async {
    try {
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      var query = _client
          .from('booking_rooms')
          .select('room_id, bookings!inner(id, day_of_week, start_time, end_time, recurrence_type, archived_at)')
          .eq('room_id', roomId)
          .eq('bookings.recurrence_type', 'weekly')
          .eq('bookings.day_of_week', dayOfWeek)
          .isFilter('bookings.archived_at', null)
          .lt('bookings.start_time', endStr)
          .gt('bookings.end_time', startStr);

      if (excludeBookingId != null) {
        query = query.neq('bookings.id', excludeBookingId);
      }

      final data = await query;
      return (data as List).isNotEmpty;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов: $e');
    }
  }

  /// Проверить конфликт с занятиями
  Future<List<String>> checkLessonConflicts({
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      if (roomIds.isEmpty) return [];

      final dateStr = date.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      final data = await _client
          .from('lessons')
          .select('room_id')
          .inFilter('room_id', roomIds)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      final conflictRoomIds = (data as List)
          .map((item) => item['room_id'] as String)
          .toSet()
          .toList();

      return conflictRoomIds;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов с занятиями: $e');
    }
  }

  /// Проверить конфликт с будущими занятиями для дня недели
  Future<bool> hasLessonConflictForDayOfWeek({
    required String roomId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? studentId,
  }) async {
    try {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      // Загружаем все будущие занятия в этом кабинете
      var query = _client
          .from('lessons')
          .select('id, room_id, date, start_time, end_time, student_id')
          .eq('room_id', roomId)
          .gte('date', todayStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      final data = await query;

      // Фильтруем по дню недели и исключаем занятия этого ученика
      for (final lesson in data as List) {
        final lessonDate = DateTime.parse(lesson['date'] as String);
        if (lessonDate.weekday != dayOfWeek) continue;

        // Пропускаем занятия этого ученика
        if (studentId != null && lesson['student_id'] == studentId) continue;

        return true; // Есть конфликт
      }

      return false;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов с занятиями: $e');
    }
  }

  // ============================================
  // Связь с занятиями (booking_lessons)
  // ============================================

  /// Проверить, было ли уже создано занятие для брони на дату
  Future<bool> hasGeneratedLesson(String bookingId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('booking_lessons')
          .select('id')
          .eq('booking_id', bookingId)
          .eq('generated_date', dateStr)
          .maybeSingle();

      return data != null;
    } catch (e) {
      throw DatabaseException('Ошибка проверки сгенерированного занятия: $e');
    }
  }

  /// Записать связь брони с занятием
  Future<void> recordGeneratedLesson({
    required String bookingId,
    required String lessonId,
    required DateTime generatedDate,
  }) async {
    try {
      await _client.from('booking_lessons').insert({
        'booking_id': bookingId,
        'lesson_id': lessonId,
        'generated_date': generatedDate.toIso8601String().split('T').first,
      });
    } catch (e) {
      throw DatabaseException('Ошибка записи связи бронь-занятие: $e');
    }
  }

  // ============================================
  // Realtime
  // ============================================

  /// Стрим бронирований по заведению и дате (realtime)
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Booking>> watchByInstitutionAndDate(
    String institutionId,
    DateTime date,
  ) {
    final controller = StreamController<List<Booking>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final bookings = await getAllForDate(institutionId, date);
        if (!controller.isClosed) {
          controller.add(bookings);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[BookingRepository] watchByInstitutionAndDate error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Стрим еженедельных бронирований заведения
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Booking>> watchWeeklyByInstitution(String institutionId) {
    final controller = StreamController<List<Booking>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final bookings = await getWeeklyByInstitution(institutionId);
        if (!controller.isClosed) {
          controller.add(bookings);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[BookingRepository] watchWeeklyByInstitution error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Стрим бронирований ученика
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Booking>> watchByStudent(String studentId) {
    final controller = StreamController<List<Booking>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final bookings = await getByStudent(studentId);
        if (!controller.isClosed) {
          controller.add(bookings);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[BookingRepository] watchByStudent error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  // ============================================
  // Массовое создание занятий из расписания
  // ============================================

  /// Проверить конфликты расписания ученика на указанный период
  /// Возвращает список дат с конфликтами
  Future<List<ScheduleConflict>> checkScheduleConflicts({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      final data = await _client.rpc('check_schedule_conflicts', params: {
        'p_student_id': studentId,
        'p_start_date': startStr,
        'p_end_date': endStr,
      });

      return (data as List).map((item) => ScheduleConflict(
        conflictDate: DateTime.parse(item['conflict_date'] as String),
        bookingId: item['booking_id'] as String,
        roomId: item['room_id'] as String,
        startTime: _parseTime(item['start_time'] as String),
        endTime: _parseTime(item['end_time'] as String),
      )).toList();
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов расписания: $e');
    }
  }

  /// Массово создать занятия из расписания ученика на указанный период
  /// Пропускает даты с конфликтами
  Future<CreateLessonsResult> createLessonsFromSchedule({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
    bool skipConflicts = true,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      final data = await _client.rpc('create_lessons_from_schedule', params: {
        'p_student_id': studentId,
        'p_start_date': startStr,
        'p_end_date': endStr,
        'p_skip_conflicts': skipConflicts,
      });

      // RPC возвращает одну строку с результатами
      final result = (data as List).first;
      return CreateLessonsResult(
        successCount: (result['success_count'] as num?)?.toInt() ?? 0,
        skippedCount: (result['skipped_count'] as num?)?.toInt() ?? 0,
        conflictDates: (result['conflict_dates'] as List?)
            ?.map((d) => DateTime.parse(d as String))
            .toList() ?? [],
      );
    } catch (e) {
      throw DatabaseException('Ошибка создания занятий из расписания: $e');
    }
  }

  /// Парсинг времени из строки "HH:MM:SS"
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}

/// Конфликт в расписании
class ScheduleConflict {
  final DateTime conflictDate;
  final String bookingId;
  final String roomId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const ScheduleConflict({
    required this.conflictDate,
    required this.bookingId,
    required this.roomId,
    required this.startTime,
    required this.endTime,
  });
}

/// Результат массового создания занятий
class CreateLessonsResult {
  final int successCount;
  final int skippedCount;
  final List<DateTime> conflictDates;

  const CreateLessonsResult({
    required this.successCount,
    required this.skippedCount,
    required this.conflictDates,
  });
}

/// Слот для batch-создания бронирований
class DayTimeSlot {
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const DayTimeSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}
