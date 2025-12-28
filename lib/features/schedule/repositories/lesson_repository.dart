import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/lesson_history.dart';

/// Репозиторий для работы с занятиями
class LessonRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Получить занятия по кабинету и дате
  Future<List<Lesson>> getByRoomAndDate(String roomId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('room_id', roomId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .order('start_time');

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки занятий: $e');
    }
  }

  /// Получить занятия по заведению и дате
  Future<List<Lesson>> getByInstitutionAndDate(
    String institutionId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('institution_id', institutionId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .order('start_time');

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки занятий: $e');
    }
  }

  /// Получить занятия преподавателя за день
  Future<List<Lesson>> getMyLessonsForDate(DateTime date) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final dateStr = date.toIso8601String().split('T').first;

      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('teacher_id', _userId!)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .order('start_time');

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки занятий: $e');
    }
  }

  /// Получить занятие по ID
  Future<Lesson> getById(String id) async {
    try {
      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('id', id)
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки занятия: $e');
    }
  }

  /// Создать занятие
  Future<Lesson> create({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? comment,
    String? repeatGroupId,
  }) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('lessons')
          .insert({
            'institution_id': institutionId,
            'room_id': roomId,
            'teacher_id': teacherId,
            'subject_id': subjectId,
            'lesson_type_id': lessonTypeId,
            'student_id': studentId,
            'group_id': groupId,
            'date': date.toIso8601String().split('T').first,
            'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
            'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
            'comment': comment,
            'created_by': _userId,
            'repeat_group_id': repeatGroupId,
          })
          .select()
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания занятия: $e');
    }
  }

  /// Создать серию повторяющихся занятий
  /// Возвращает список созданных занятий
  Future<List<Lesson>> createSeries({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    required List<DateTime> dates,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? comment,
  }) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');
    if (dates.isEmpty) throw ValidationException('Список дат пуст');

    try {
      // Генерируем общий ID для серии
      final repeatGroupId = _generateUuid();

      final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      // Создаём записи для всех дат
      final records = dates.map((date) => {
            'institution_id': institutionId,
            'room_id': roomId,
            'teacher_id': teacherId,
            'subject_id': subjectId,
            'lesson_type_id': lessonTypeId,
            'student_id': studentId,
            'group_id': groupId,
            'date': date.toIso8601String().split('T').first,
            'start_time': startStr,
            'end_time': endStr,
            'comment': comment,
            'created_by': _userId,
            'repeat_group_id': repeatGroupId,
          }).toList();

      final data = await _client
          .from('lessons')
          .insert(records)
          .select();

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка создания серии занятий: $e');
    }
  }

  /// Генерация UUID на клиенте
  String _generateUuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (match) {
        final r = (DateTime.now().millisecondsSinceEpoch + (match.group(0) == 'x' ? 0 : 8)) % 16;
        final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
        return v.toRadixString(16);
      },
    );
  }

  /// Получить все занятия серии (по repeat_group_id)
  Future<List<Lesson>> getSeriesLessons(String repeatGroupId) async {
    try {
      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('repeat_group_id', repeatGroupId)
          .isFilter('archived_at', null)
          .order('date');

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки серии занятий: $e');
    }
  }

  /// Получить последующие занятия серии (с указанной даты)
  Future<List<Lesson>> getFollowingLessons(String repeatGroupId, DateTime fromDate) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;

      final data = await _client
          .from('lessons')
          .select('id, date')
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null)
          .order('date');

      return (data as List).map((item) => Lesson.fromJson({
        ...item,
        // Минимальные данные для операций
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'institution_id': '',
        'room_id': '',
        'teacher_id': '',
        'start_time': '00:00',
        'end_time': '00:00',
        'status': 'scheduled',
        'created_by': '',
      })).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки последующих занятий: $e');
    }
  }

  /// Удалить последующие занятия серии
  Future<void> deleteFollowingLessons(String repeatGroupId, DateTime fromDate) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;

      // Сначала удаляем историю
      final lessonIds = await _client
          .from('lessons')
          .select('id')
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null);

      for (final lesson in lessonIds as List) {
        await _client
            .from('lesson_history')
            .delete()
            .eq('lesson_id', lesson['id']);
      }

      // Затем удаляем занятия
      await _client
          .from('lessons')
          .delete()
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr);
    } catch (e) {
      throw DatabaseException('Ошибка удаления серии занятий: $e');
    }
  }

  /// Обновить время для последующих занятий серии
  Future<void> updateFollowingLessons(
    String repeatGroupId,
    DateTime fromDate, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;
      final updates = <String, dynamic>{};

      if (startTime != null) {
        updates['start_time'] = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      }
      if (endTime != null) {
        updates['end_time'] = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      }

      if (updates.isEmpty) return;

      await _client
          .from('lessons')
          .update(updates)
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null);
    } catch (e) {
      throw DatabaseException('Ошибка обновления серии занятий: $e');
    }
  }

  /// Проверить конфликты для списка дат
  /// Возвращает список дат с конфликтами
  Future<List<DateTime>> checkConflictsForDates({
    required String roomId,
    required List<DateTime> dates,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final conflictDates = <DateTime>[];

    for (final date in dates) {
      final hasConflict = await hasTimeConflict(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
      );
      if (hasConflict) {
        conflictDates.add(date);
      }
    }

    return conflictDates;
  }

  /// Обновить занятие
  Future<Lesson> update(
    String id, {
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? comment,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (roomId != null) updates['room_id'] = roomId;
      if (teacherId != null) updates['teacher_id'] = teacherId;
      if (subjectId != null) updates['subject_id'] = subjectId;
      if (lessonTypeId != null) updates['lesson_type_id'] = lessonTypeId;
      if (studentId != null) updates['student_id'] = studentId;
      if (groupId != null) updates['group_id'] = groupId;
      if (date != null) updates['date'] = date.toIso8601String().split('T').first;
      if (startTime != null) {
        updates['start_time'] = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      }
      if (endTime != null) {
        updates['end_time'] = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      }
      if (comment != null) updates['comment'] = comment;

      final data = await _client
          .from('lessons')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления занятия: $e');
    }
  }

  /// Изменить статус занятия
  Future<Lesson> updateStatus(String id, LessonStatus status) async {
    try {
      final data = await _client
          .from('lessons')
          .update({'status': status.name})
          .eq('id', id)
          .select()
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка изменения статуса: $e');
    }
  }

  /// Отменить занятие
  Future<Lesson> cancel(String id) async {
    return updateStatus(id, LessonStatus.cancelled);
  }

  /// Отметить как проведённое
  Future<Lesson> complete(String id) async {
    return updateStatus(id, LessonStatus.completed);
  }

  /// Вернуть статус "запланировано"
  Future<Lesson> uncomplete(String id) async {
    return updateStatus(id, LessonStatus.scheduled);
  }

  /// Установить ID подписки для занятия (для расчёта стоимости)
  Future<void> setSubscriptionId(String lessonId, String subscriptionId) async {
    try {
      await _client
          .from('lessons')
          .update({'subscription_id': subscriptionId})
          .eq('id', lessonId);
    } catch (e) {
      // Не критично - продолжаем без ошибки
      debugPrint('Error setting subscription_id: $e');
    }
  }

  /// Убрать привязку к подписке
  Future<void> clearSubscriptionId(String lessonId) async {
    try {
      await _client
          .from('lessons')
          .update({'subscription_id': null})
          .eq('id', lessonId);
    } catch (e) {
      debugPrint('Error clearing subscription_id: $e');
    }
  }

  /// Архивировать занятие
  Future<void> archive(String id) async {
    try {
      await _client
          .from('lessons')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации занятия: $e');
    }
  }

  /// Удалить занятие полностью
  Future<void> delete(String id) async {
    try {
      // Сначала удаляем историю занятия
      await _client
          .from('lesson_history')
          .delete()
          .eq('lesson_id', id);

      // Затем удаляем само занятие
      await _client
          .from('lessons')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления занятия: $e');
    }
  }

  /// Получить историю изменений занятия
  Future<List<LessonHistory>> getHistory(String lessonId) async {
    try {
      final data = await _client
          .from('lesson_history')
          .select('*, profiles(*)')
          .eq('lesson_id', lessonId)
          .order('changed_at', ascending: false);

      return (data as List)
          .map((item) => LessonHistory.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки истории: $e');
    }
  }

  /// Проверить конфликт времени (с занятиями и бронями)
  Future<bool> hasTimeConflict({
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeLessonId,
    String? excludeBookingId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      // 1. Проверяем конфликт с занятиями
      var lessonQuery = _client
          .from('lessons')
          .select('id')
          .eq('room_id', roomId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      if (excludeLessonId != null) {
        lessonQuery = lessonQuery.neq('id', excludeLessonId);
      }

      final lessonData = await lessonQuery;
      if ((lessonData as List).isNotEmpty) return true;

      // 2. Проверяем конфликт с бронями
      var bookingQuery = _client
          .from('booking_rooms')
          .select('booking_id, bookings!inner(id, date, start_time, end_time, archived_at)')
          .eq('room_id', roomId)
          .eq('bookings.date', dateStr)
          .isFilter('bookings.archived_at', null)
          .lt('bookings.start_time', endStr)
          .gt('bookings.end_time', startStr);

      if (excludeBookingId != null) {
        bookingQuery = bookingQuery.neq('bookings.id', excludeBookingId);
      }

      final bookingData = await bookingQuery;
      return (bookingData as List).isNotEmpty;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликта: $e');
    }
  }

  /// Получить неотмеченные занятия (прошедшие, но без статуса)
  /// Для owner/admin возвращает все, для teacher - только его занятия
  Future<List<Lesson>> getUnmarkedLessons({
    required String institutionId,
    required bool isAdminOrOwner,
    String? teacherId,
  }) async {
    try {
      final now = DateTime.now();

      // Получаем занятия со статусом scheduled
      var query = _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*)
          ''')
          .eq('institution_id', institutionId)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null);

      // Для преподавателя - только его занятия
      if (!isAdminOrOwner && teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }

      final data = await query.order('date').order('end_time');

      // Фильтруем на клиенте: занятия, время которых полностью прошло
      final today = DateTime(now.year, now.month, now.day);
      final lessons = (data as List)
          .map((item) => Lesson.fromJson(item))
          .where((lesson) {
        // Занятие в прошлом дне
        if (lesson.date.isBefore(today)) {
          return true;
        }
        // Занятие сегодня и время окончания уже прошло
        if (lesson.date.year == now.year &&
            lesson.date.month == now.month &&
            lesson.date.day == now.day) {
          final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
          final nowMinutes = now.hour * 60 + now.minute;
          return endMinutes <= nowMinutes;
        }
        return false;
      }).toList();

      return lessons;
    } catch (e) {
      throw DatabaseException('Ошибка загрузки неотмеченных занятий: $e');
    }
  }

  /// Стрим занятий кабинета (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  Stream<List<Lesson>> watchByRoom(String roomId, DateTime date) async* {
    await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
      // При любом изменении загружаем актуальные данные
      final lessons = await getByRoomAndDate(roomId, date);
      yield lessons;
    }
  }

  /// Стрим занятий заведения за дату (realtime)
  /// При любом изменении загружает полные данные с joins
  /// Примечание: слушаем ВСЕ изменения в таблице без фильтра,
  /// т.к. Supabase Realtime не отправляет DELETE события с фильтром корректно
  Stream<List<Lesson>> watchByInstitution(String institutionId, DateTime date) async* {
    // Используем стрим для отслеживания изменений (без фильтра для DELETE событий)
    await for (final _ in _client
        .from('lessons')
        .stream(primaryKey: ['id'])) {
      // При любом изменении - загружаем полные данные с joins
      // Фильтрация по institution_id происходит в getByInstitutionAndDate
      final lessons = await getByInstitutionAndDate(institutionId, date);
      yield lessons;
    }
  }

  /// Стрим неотмеченных занятий (realtime)
  /// Для owner/admin возвращает все, для teacher - только его занятия
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  Stream<List<Lesson>> watchUnmarkedLessons({
    required String institutionId,
    required bool isAdminOrOwner,
    String? teacherId,
  }) async* {
    // Используем стрим для отслеживания изменений (без фильтра для DELETE событий)
    await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
      // При любом изменении - загружаем полные данные с joins
      final lessons = await getUnmarkedLessons(
        institutionId: institutionId,
        isAdminOrOwner: isAdminOrOwner,
        teacherId: teacherId,
      );
      yield lessons;
    }
  }
}
