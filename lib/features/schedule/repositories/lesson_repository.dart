import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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
            student_groups(*),
            lesson_students(*, students(*))
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
            student_groups(*),
            lesson_students(*, students(*))
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
    if (_userId == null)
      throw const AuthAppException('Пользователь не авторизован');

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
            student_groups(*),
            lesson_students(*, students(*))
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
            student_groups(*),
            lesson_students(*, students(*))
          ''')
          .eq('id', id)
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки занятия: $e');
    }
  }

  /// Создать занятие
  /// Для групповых занятий (groupId != null) автоматически создаёт
  /// записи в lesson_students для всех участников группы
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
    if (_userId == null)
      throw const AuthAppException('Пользователь не авторизован');

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
            'start_time':
                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
            'end_time':
                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
            'comment': comment,
            'created_by': _userId,
            'repeat_group_id': repeatGroupId,
          })
          .select()
          .single();

      final lesson = Lesson.fromJson(data);

      // Для групповых занятий создаём записи участников
      if (groupId != null) {
        final memberIds = await getGroupMemberIds(groupId);
        if (memberIds.isNotEmpty) {
          await createLessonStudents(lesson.id, memberIds);
        }
      }

      return lesson;
    } catch (e) {
      throw DatabaseException('Ошибка создания занятия: $e');
    }
  }

  /// Создать серию повторяющихся занятий
  /// [repeatGroupId] — можно передать для объединения нескольких серий
  /// (например, для разных дней недели в одном повторе)
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
    String? repeatGroupId,
  }) async {
    if (_userId == null)
      throw const AuthAppException('Пользователь не авторизован');
    if (dates.isEmpty) throw const ValidationException('Список дат пуст');

    try {
      // Используем переданный ID или генерируем новый
      final groupId_ = repeatGroupId ?? _generateUuid();

      final startStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      // Создаём записи для всех дат
      final records = dates
          .map(
            (date) => {
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
              'repeat_group_id': groupId_,
            },
          )
          .toList();

      final data = await _client.from('lessons').insert(records).select();

      final lessons = (data as List)
          .map((item) => Lesson.fromJson(item))
          .toList();

      // Для групповых занятий создаём записи участников для каждого занятия
      if (groupId != null) {
        final memberIds = await getGroupMemberIds(groupId);
        if (memberIds.isNotEmpty) {
          for (final lesson in lessons) {
            await createLessonStudents(lesson.id, memberIds);
          }
        }
      }

      return lessons;
    } catch (e) {
      throw DatabaseException('Ошибка создания серии занятий: $e');
    }
  }

  /// Генерация UUID на клиенте (v4 random)
  static const _uuid = Uuid();
  String _generateUuid() => _uuid.v4();

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
            student_groups(*),
            lesson_students(*, students(*))
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
  /// Дополнительно фильтрует по room_id и start_time для точности
  /// (защита от старых данных с дублирующимися repeat_group_id)
  Future<List<Lesson>> getFollowingLessons(
    String repeatGroupId,
    DateTime fromDate, {
    String? roomId,
    TimeOfDay? startTime,
  }) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;

      var query = _client
          .from('lessons')
          .select('id, date')
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null);

      // Дополнительная фильтрация для точности
      if (roomId != null) {
        query = query.eq('room_id', roomId);
      }
      if (startTime != null) {
        final timeStr =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        query = query.eq('start_time', timeStr);
      }

      final data = await query.order('date');

      return (data as List)
          .map(
            (item) => Lesson.fromJson({
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
            }),
          )
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки последующих занятий: $e');
    }
  }

  /// Удалить последующие занятия серии
  Future<void> deleteFollowingLessons(
    String repeatGroupId,
    DateTime fromDate,
  ) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;

      // Получаем ID занятий для удаления
      final lessonIds = await _client
          .from('lessons')
          .select('id')
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null);

      // Удаляем связанные данные для каждого занятия
      for (final lesson in lessonIds as List) {
        final lessonId = lesson['id'];
        // 1. Удаляем участников
        await _client
            .from('lesson_students')
            .delete()
            .eq('lesson_id', lessonId);
        // 2. Удаляем историю
        await _client.from('lesson_history').delete().eq('lesson_id', lessonId);
      }

      // Удаляем сами занятия
      await _client
          .from('lessons')
          .delete()
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr);
    } catch (e) {
      throw DatabaseException('Ошибка удаления серии занятий: $e');
    }
  }

  /// Обновить поля для последующих занятий серии
  /// Поддерживает: время, кабинет, ученик, предмет, тип занятия
  Future<void> updateFollowingLessons(
    String repeatGroupId,
    DateTime fromDate, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? roomId,
    String? studentId,
    String? subjectId,
    String? lessonTypeId,
  }) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;
      final updates = <String, dynamic>{};

      if (startTime != null) {
        updates['start_time'] =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      }
      if (endTime != null) {
        updates['end_time'] =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      }
      if (roomId != null) {
        updates['room_id'] = roomId;
      }
      if (studentId != null) {
        updates['student_id'] = studentId;
      }
      if (subjectId != null) {
        updates['subject_id'] = subjectId;
      }
      if (lessonTypeId != null) {
        updates['lesson_type_id'] = lessonTypeId;
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

  /// Обновить выбранные занятия по списку ID
  /// Поддерживает: время, кабинет, ученик, предмет, тип занятия
  Future<void> updateSelectedLessons(
    List<String> lessonIds, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? roomId,
    String? studentId,
    String? subjectId,
    String? lessonTypeId,
  }) async {
    if (lessonIds.isEmpty) return;

    try {
      final updates = <String, dynamic>{};

      if (startTime != null) {
        updates['start_time'] =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      }
      if (endTime != null) {
        updates['end_time'] =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      }
      if (roomId != null) {
        updates['room_id'] = roomId;
      }
      if (studentId != null) {
        updates['student_id'] = studentId;
      }
      if (subjectId != null) {
        updates['subject_id'] = subjectId;
      }
      if (lessonTypeId != null) {
        updates['lesson_type_id'] = lessonTypeId;
      }

      if (updates.isEmpty) return;

      await _client.from('lessons').update(updates).inFilter('id', lessonIds);
    } catch (e) {
      throw DatabaseException('Ошибка обновления занятий: $e');
    }
  }

  /// Проверить конфликты для списка дат
  /// Возвращает список дат с конфликтами
  /// [studentId] - если передан, разрешает занятие поверх своего постоянного слота
  Future<List<DateTime>> checkConflictsForDates({
    required String roomId,
    required List<DateTime> dates,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? studentId,
  }) async {
    final conflictDates = <DateTime>[];

    for (final date in dates) {
      final hasConflict = await hasTimeConflict(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId,
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
      if (date != null)
        updates['date'] = date.toIso8601String().split('T').first;
      if (startTime != null) {
        updates['start_time'] =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      }
      if (endTime != null) {
        updates['end_time'] =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
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

  /// Архивировать все последующие занятия серии
  /// Возвращает количество архивированных занятий
  /// [roomId] и [startTime] — дополнительная фильтрация для точности
  Future<int> archiveFollowingLessons(
    String repeatGroupId,
    DateTime fromDate, {
    String? roomId,
    TimeOfDay? startTime,
  }) async {
    try {
      final dateStr = fromDate.toIso8601String().split('T').first;

      // Получаем ID занятий для архивации
      var query = _client
          .from('lessons')
          .select('id')
          .eq('repeat_group_id', repeatGroupId)
          .gte('date', dateStr)
          .isFilter('archived_at', null);

      // Дополнительная фильтрация для точности
      if (roomId != null) {
        query = query.eq('room_id', roomId);
      }
      if (startTime != null) {
        final timeStr =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        query = query.eq('start_time', timeStr);
      }

      final lessonIds = await query;

      final ids = (lessonIds as List).map((e) => e['id'] as String).toList();
      if (ids.isEmpty) return 0;

      // Архивируем все занятия
      await _client
          .from('lessons')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);

      return ids.length;
    } catch (e) {
      throw DatabaseException('Ошибка архивации серии занятий: $e');
    }
  }

  /// Удалить занятие полностью
  Future<void> delete(String id) async {
    try {
      // 1. Удаляем участников группового занятия
      await _client.from('lesson_students').delete().eq('lesson_id', id);

      // 2. Удаляем историю занятия
      await _client.from('lesson_history').delete().eq('lesson_id', id);

      // 3. Удаляем само занятие
      await _client.from('lessons').delete().eq('id', id);
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

  /// Проверить конфликт времени (с занятиями, бронями и постоянными слотами)
  /// [studentId] - если передан, разрешает занятие поверх своего постоянного слота
  Future<bool> hasTimeConflict({
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeLessonId,
    String? excludeBookingId,
    String? studentId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

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
          .select(
            'booking_id, bookings!inner(id, date, start_time, end_time, archived_at)',
          )
          .eq('room_id', roomId)
          .eq('bookings.date', dateStr)
          .isFilter('bookings.archived_at', null)
          .lt('bookings.start_time', endStr)
          .gt('bookings.end_time', startStr);

      if (excludeBookingId != null) {
        bookingQuery = bookingQuery.neq('bookings.id', excludeBookingId);
      }

      final bookingData = await bookingQuery;
      if ((bookingData as List).isNotEmpty) return true;

      // 3. Проверяем конфликт с постоянными слотами (student_schedules)
      final hasScheduleConflict = await _checkScheduleSlotConflict(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        allowStudentId: studentId,
      );
      if (hasScheduleConflict) return true;

      return false;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликта: $e');
    }
  }

  /// Проверить конфликт с постоянными слотами расписания
  /// Возвращает true если есть конфликт
  Future<bool> _checkScheduleSlotConflict({
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? allowStudentId,
  }) async {
    final dayOfWeek = date.weekday;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Получаем активные слоты для этого дня недели
    // Фильтрацию по кабинету и времени делаем на клиенте из-за replacement_room_id
    final slotsData = await _client
        .from('student_schedules')
        .select('''
          id, student_id, room_id, day_of_week, start_time, end_time,
          is_active, is_paused, pause_until,
          replacement_room_id, replacement_until,
          valid_from, valid_until,
          schedule_exceptions(exception_date)
        ''')
        .eq('day_of_week', dayOfWeek)
        .eq('is_active', true);

    for (final slot in slotsData as List) {
      // Пропускаем слот своего ученика (можно создать занятие поверх своего слота)
      if (allowStudentId != null && slot['student_id'] == allowStudentId) {
        continue;
      }

      // Определяем актуальный кабинет слота на эту дату
      String effectiveRoomId = slot['room_id'];
      if (slot['replacement_room_id'] != null &&
          slot['replacement_until'] != null) {
        final replacementUntil = DateTime.parse(slot['replacement_until']);
        if (!normalizedDate.isAfter(replacementUntil)) {
          effectiveRoomId = slot['replacement_room_id'];
        }
      }

      // Пропускаем если кабинет не совпадает
      if (effectiveRoomId != roomId) continue;

      // Проверяем паузу
      if (slot['is_paused'] == true) {
        if (slot['pause_until'] == null) continue; // Бессрочная пауза
        final pauseUntil = DateTime.parse(slot['pause_until']);
        if (!normalizedDate.isAfter(pauseUntil)) continue; // Ещё на паузе
      }

      // Проверяем период действия
      if (slot['valid_from'] != null) {
        final validFrom = DateTime.parse(slot['valid_from']);
        if (normalizedDate.isBefore(validFrom)) continue;
      }
      if (slot['valid_until'] != null) {
        final validUntil = DateTime.parse(slot['valid_until']);
        if (normalizedDate.isAfter(validUntil)) continue;
      }

      // Проверяем исключения
      final exceptions = slot['schedule_exceptions'] as List?;
      if (exceptions != null) {
        bool hasException = false;
        for (final exc in exceptions) {
          final excDate = DateTime.parse(exc['exception_date']);
          if (excDate.year == normalizedDate.year &&
              excDate.month == normalizedDate.month &&
              excDate.day == normalizedDate.day) {
            hasException = true;
            break;
          }
        }
        if (hasException) continue;
      }

      // Проверяем пересечение времени
      final slotStartParts = (slot['start_time'] as String).split(':');
      final slotEndParts = (slot['end_time'] as String).split(':');
      final slotStartMinutes =
          int.parse(slotStartParts[0]) * 60 + int.parse(slotStartParts[1]);
      final slotEndMinutes =
          int.parse(slotEndParts[0]) * 60 + int.parse(slotEndParts[1]);

      // Пересечение: start < other_end AND end > other_start
      if (startMinutes < slotEndMinutes && endMinutes > slotStartMinutes) {
        return true; // Есть конфликт
      }
    }

    return false;
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
            student_groups(*),
            lesson_students(*, students(*))
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
      final lessons = (data as List).map((item) => Lesson.fromJson(item)).where(
        (lesson) {
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
        },
      ).toList();

      return lessons;
    } catch (e) {
      throw DatabaseException('Ошибка загрузки неотмеченных занятий: $e');
    }
  }

  /// Стрим занятий кабинета (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  /// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
  Stream<List<Lesson>> watchByRoom(String roomId, DateTime date) async* {
    // 1. Сразу выдаём текущие данные
    yield await getByRoomAndDate(roomId, date);

    // 2. Подписываемся на изменения
    await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
      final lessons = await getByRoomAndDate(roomId, date);
      yield lessons;
    }
  }

  /// Стрим занятий заведения за дату (realtime)
  /// При любом изменении загружает полные данные с joins
  /// Примечание: слушаем ВСЕ изменения в таблице без фильтра,
  /// т.к. Supabase Realtime не отправляет DELETE события с фильтром корректно
  /// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
  Stream<List<Lesson>> watchByInstitution(
    String institutionId,
    DateTime date,
  ) async* {
    // 1. Сразу выдаём текущие данные
    yield await getByInstitutionAndDate(institutionId, date);

    // 2. Подписываемся на изменения
    await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
      final lessons = await getByInstitutionAndDate(institutionId, date);
      yield lessons;
    }
  }

  /// Стрим неотмеченных занятий (realtime)
  /// Для owner/admin возвращает все, для teacher - только его занятия
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  /// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
  Stream<List<Lesson>> watchUnmarkedLessons({
    required String institutionId,
    required bool isAdminOrOwner,
    String? teacherId,
  }) async* {
    // 1. Сразу выдаём текущие данные
    yield await getUnmarkedLessons(
      institutionId: institutionId,
      isAdminOrOwner: isAdminOrOwner,
      teacherId: teacherId,
    );

    // 2. Подписываемся на изменения
    await for (final _ in _client.from('lessons').stream(primaryKey: ['id'])) {
      final lessons = await getUnmarkedLessons(
        institutionId: institutionId,
        isAdminOrOwner: isAdminOrOwner,
        teacherId: teacherId,
      );
      yield lessons;
    }
  }

  // ============================================================
  // МЕТОДЫ ДЛЯ РАБОТЫ С УЧАСТНИКАМИ ГРУППОВОГО ЗАНЯТИЯ
  // ============================================================

  /// Получить участников группового занятия
  Future<List<LessonStudent>> getLessonStudents(String lessonId) async {
    try {
      final data = await _client
          .from('lesson_students')
          .select('*, students(*)')
          .eq('lesson_id', lessonId)
          .order('id');

      return (data as List)
          .map((item) => LessonStudent.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки участников занятия: $e');
    }
  }

  /// Создать записи участников для группового занятия
  /// Используется при создании занятия с groupId
  Future<void> createLessonStudents(
    String lessonId,
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return;

    try {
      final records = studentIds
          .map(
            (sid) => {
              'lesson_id': lessonId,
              'student_id': sid,
              'attended': true, // По умолчанию все присутствуют
            },
          )
          .toList();

      await _client.from('lesson_students').insert(records);
    } catch (e) {
      throw DatabaseException('Ошибка создания участников занятия: $e');
    }
  }

  /// Добавить гостя (ученика не из группы) в занятие
  Future<LessonStudent> addGuestToLesson(
    String lessonId,
    String studentId,
  ) async {
    try {
      final data = await _client
          .from('lesson_students')
          .insert({
            'lesson_id': lessonId,
            'student_id': studentId,
            'attended': true,
          })
          .select('*, students(*)')
          .single();

      return LessonStudent.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка добавления участника: $e');
    }
  }

  /// Удалить участника из занятия
  Future<void> removeLessonStudent(String lessonId, String studentId) async {
    try {
      await _client
          .from('lesson_students')
          .delete()
          .eq('lesson_id', lessonId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления участника: $e');
    }
  }

  /// Обновить статус присутствия участника
  Future<void> updateAttendance(
    String lessonId,
    String studentId,
    bool attended,
  ) async {
    try {
      await _client
          .from('lesson_students')
          .update({'attended': attended})
          .eq('lesson_id', lessonId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления присутствия: $e');
    }
  }

  /// Установить ID подписки для участника группового занятия
  /// Вызывается при complete() для сохранения информации о списании
  Future<void> setLessonStudentSubscriptionId(
    String lessonId,
    String studentId,
    String subscriptionId,
  ) async {
    try {
      await _client
          .from('lesson_students')
          .update({'subscription_id': subscriptionId})
          .eq('lesson_id', lessonId)
          .eq('student_id', studentId);
    } catch (e) {
      // Не критично - продолжаем без ошибки
      debugPrint('Error setting lesson_student subscription_id: $e');
    }
  }

  /// Очистить привязку к подписке для участника группового занятия
  /// Вызывается при uncomplete() для корректного возврата занятия
  Future<void> clearLessonStudentSubscriptionId(
    String lessonId,
    String studentId,
  ) async {
    try {
      await _client
          .from('lesson_students')
          .update({'subscription_id': null})
          .eq('lesson_id', lessonId)
          .eq('student_id', studentId);
    } catch (e) {
      debugPrint('Error clearing lesson_student subscription_id: $e');
    }
  }

  /// Получить ID участников группы (для создания lesson_students)
  Future<List<String>> getGroupMemberIds(String groupId) async {
    try {
      final data = await _client
          .from('student_group_members')
          .select('student_id')
          .eq('group_id', groupId);

      return (data as List)
          .map((item) => item['student_id'] as String)
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки участников группы: $e');
    }
  }

  // ============================================================
  // BULK-ОПЕРАЦИИ для массового управления занятиями
  // ============================================================

  /// Получить все будущие занятия преподавателя
  /// Возвращает занятия с датой >= сегодня и статусом scheduled
  Future<List<Lesson>> getFutureLessonsForTeacher(
    String teacherId,
    String institutionId,
  ) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*),
            lesson_students(*, students(*))
          ''')
          .eq('teacher_id', teacherId)
          .eq('institution_id', institutionId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null)
          .order('date')
          .order('start_time');

      // Безопасный парсинг — пропускаем занятия с null в обязательных полях
      final lessons = <Lesson>[];

      // Защита от неожиданного типа данных
      if (data == null) {
        debugPrint('getFutureLessonsForTeacher: data is null');
        return lessons;
      }
      if (data is! List) {
        debugPrint(
          'getFutureLessonsForTeacher: data is not List, type: ${data.runtimeType}',
        );
        return lessons;
      }

      for (final item in data) {
        try {
          if (item == null) continue;
          if (item is! Map<String, dynamic>) {
            debugPrint('Пропущен элемент неверного типа: ${item.runtimeType}');
            continue;
          }
          final map = item;
          // Проверяем все обязательные String поля
          if (map['id'] == null ||
              map['institution_id'] == null ||
              map['room_id'] == null ||
              map['teacher_id'] == null ||
              map['date'] == null ||
              map['start_time'] == null ||
              map['end_time'] == null ||
              map['status'] == null ||
              map['created_by'] == null ||
              map['created_at'] == null ||
              map['updated_at'] == null) {
            debugPrint(
              'Пропущено занятие с null в обязательных полях: ${map['id']}',
            );
            continue;
          }
          lessons.add(Lesson.fromJson(map));
        } catch (e, stack) {
          debugPrint('Пропущено занятие с ошибкой парсинга: $e\n$stack');
        }
      }
      return lessons;
    } catch (e) {
      throw DatabaseException(
        'Ошибка загрузки будущих занятий преподавателя: $e',
      );
    }
  }

  /// Получить все будущие занятия ученика
  /// Возвращает занятия с датой >= сегодня и статусом scheduled
  Future<List<Lesson>> getFutureLessonsForStudent(String studentId) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // Получаем индивидуальные занятия
      final individualData = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*),
            lesson_students(*, students(*))
          ''')
          .eq('student_id', studentId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null)
          .order('date')
          .order('start_time');

      // Получаем групповые занятия (через lesson_students)
      final groupLessonsIds = await _client
          .from('lesson_students')
          .select('lesson_id')
          .eq('student_id', studentId);

      final groupIds = (groupLessonsIds as List)
          .map((item) => item['lesson_id'] as String)
          .toList();

      List<Lesson> groupLessons = [];
      if (groupIds.isNotEmpty) {
        final groupData = await _client
            .from('lessons')
            .select('''
              *,
              rooms(*),
              subjects(*),
              lesson_types(*),
              students(*),
              student_groups(*),
              lesson_students(*, students(*))
            ''')
            .inFilter('id', groupIds)
            .gte('date', todayStr)
            .eq('status', 'scheduled')
            .isFilter('archived_at', null)
            .order('date')
            .order('start_time');

        groupLessons = (groupData as List)
            .map((item) => Lesson.fromJson(item))
            .toList();
      }

      // Объединяем и сортируем
      final allLessons = [
        ...(individualData as List).map((item) => Lesson.fromJson(item)),
        ...groupLessons,
      ];

      // Убираем дубликаты (если есть)
      final uniqueIds = <String>{};
      return allLessons.where((l) => uniqueIds.add(l.id)).toList()
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
          final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
          return aMinutes.compareTo(bMinutes);
        });
    } catch (e) {
      throw DatabaseException('Ошибка загрузки будущих занятий ученика: $e');
    }
  }

  /// Получить историю занятий ученика (проведённые и отменённые)
  /// [limit] - количество записей, [offset] - смещение для пагинации
  Future<List<Lesson>> getLessonHistoryForStudent(
    String studentId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Индивидуальные занятия
      final individualData = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*)
          ''')
          .eq('student_id', studentId)
          .inFilter('status', ['completed', 'cancelled'])
          .isFilter('archived_at', null)
          .order('date', ascending: false)
          .order('start_time', ascending: false)
          .range(offset, offset + limit - 1);

      // Групповые занятия через lesson_students
      final groupLessonIds = await _client
          .from('lesson_students')
          .select('lesson_id')
          .eq('student_id', studentId);

      final groupIds = (groupLessonIds as List)
          .map((item) => item['lesson_id'] as String)
          .toList();

      List<Lesson> groupLessons = [];
      if (groupIds.isNotEmpty) {
        final groupData = await _client
            .from('lessons')
            .select('''
              *,
              rooms(*),
              subjects(*),
              lesson_types(*)
            ''')
            .inFilter('id', groupIds)
            .inFilter('status', ['completed', 'cancelled'])
            .isFilter('archived_at', null)
            .order('date', ascending: false)
            .order('start_time', ascending: false)
            .range(offset, offset + limit - 1);

        groupLessons = (groupData as List)
            .map((item) => Lesson.fromJson(item))
            .toList();
      }

      // Объединяем и сортируем
      final allLessons = [
        ...(individualData as List).map((item) => Lesson.fromJson(item)),
        ...groupLessons,
      ];

      // Убираем дубликаты и сортируем по дате (убывание)
      final uniqueIds = <String>{};
      final uniqueLessons = allLessons.where((l) => uniqueIds.add(l.id)).toList();
      uniqueLessons.sort((a, b) => b.date.compareTo(a.date));

      return uniqueLessons.take(limit).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки истории занятий ученика: $e');
    }
  }

  /// Удалить все будущие занятия преподавателя
  /// Возвращает количество удалённых занятий
  Future<int> deleteFutureLessonsForTeacher(
    String teacherId,
    String institutionId,
  ) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // Получаем ID занятий для удаления
      final lessonIds = await _client
          .from('lessons')
          .select('id')
          .eq('teacher_id', teacherId)
          .eq('institution_id', institutionId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null);

      final ids = (lessonIds as List)
          .map((item) => item['id'] as String)
          .toList();
      if (ids.isEmpty) return 0;

      // Удаляем связанные данные
      for (final id in ids) {
        await _client.from('lesson_students').delete().eq('lesson_id', id);
        await _client.from('lesson_history').delete().eq('lesson_id', id);
      }

      // Удаляем сами занятия
      await _client.from('lessons').delete().inFilter('id', ids);

      return ids.length;
    } catch (e) {
      throw DatabaseException(
        'Ошибка удаления будущих занятий преподавателя: $e',
      );
    }
  }

  /// Удалить все будущие занятия ученика
  /// Возвращает количество удалённых занятий
  Future<int> deleteFutureLessonsForStudent(String studentId) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // Получаем ID индивидуальных занятий
      final individualIds = await _client
          .from('lessons')
          .select('id')
          .eq('student_id', studentId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null);

      final ids = (individualIds as List)
          .map((item) => item['id'] as String)
          .toList();
      if (ids.isEmpty) return 0;

      // Удаляем связанные данные
      for (final id in ids) {
        await _client.from('lesson_students').delete().eq('lesson_id', id);
        await _client.from('lesson_history').delete().eq('lesson_id', id);
      }

      // Удаляем сами занятия
      await _client.from('lessons').delete().inFilter('id', ids);

      return ids.length;
    } catch (e) {
      throw DatabaseException('Ошибка удаления будущих занятий ученика: $e');
    }
  }

  /// Проверить конфликты для переназначения занятий другому преподавателю
  /// Возвращает список занятий с конфликтами и описанием проблемы
  /// ОПТИМИЗИРОВАНО: 2 запроса вместо 2*N
  Future<List<LessonConflict>> checkReassignmentConflicts(
    List<Lesson> lessons,
    String newTeacherId,
  ) async {
    if (lessons.isEmpty) return [];

    final conflicts = <LessonConflict>[];

    // Собираем диапазон дат
    final dates = lessons.map((l) => l.date).toList();
    final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final minDateStr = minDate.toIso8601String().split('T').first;
    final maxDateStr = maxDate.toIso8601String().split('T').first;

    try {
      // ОДИН запрос: все занятия нового преподавателя в диапазоне дат
      final teacherLessonsData = await _client
          .from('lessons')
          .select('id, date, start_time, end_time')
          .eq('teacher_id', newTeacherId)
          .gte('date', minDateStr)
          .lte('date', maxDateStr)
          .isFilter('archived_at', null);

      // Парсим занятия преподавателя
      final teacherLessons = (teacherLessonsData as List).map((row) {
        final startParts = (row['start_time'] as String).split(':');
        final endParts = (row['end_time'] as String).split(':');
        return (
          id: row['id'] as String,
          date: DateTime.parse(row['date'] as String),
          startMinutes:
              int.parse(startParts[0]) * 60 + int.parse(startParts[1]),
          endMinutes: int.parse(endParts[0]) * 60 + int.parse(endParts[1]),
        );
      }).toList();

      // Проверяем конфликты в памяти
      for (final lesson in lessons) {
        final lessonStartMinutes =
            lesson.startTime.hour * 60 + lesson.startTime.minute;
        final lessonEndMinutes =
            lesson.endTime.hour * 60 + lesson.endTime.minute;

        // Ищем пересечение с занятиями преподавателя
        final hasTeacherConflict = teacherLessons.any((tl) {
          if (tl.id == lesson.id) return false; // Исключаем само занятие
          if (!_isSameDay(tl.date, lesson.date)) return false;
          // Проверка пересечения времени
          return tl.startMinutes < lessonEndMinutes &&
              tl.endMinutes > lessonStartMinutes;
        });

        if (hasTeacherConflict) {
          conflicts.add(
            LessonConflict(
              lesson: lesson,
              type: ConflictType.teacherBusy,
              description: 'Преподаватель занят в это время',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка проверки конфликтов: $e');
      // При ошибке возвращаем пустой список — позволяем переназначить
    }

    return conflicts;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Переназначить занятия другому преподавателю
  /// Возвращает список переназначенных занятий
  Future<List<Lesson>> reassignLessons(
    List<String> lessonIds,
    String newTeacherId,
  ) async {
    if (lessonIds.isEmpty) return [];
    if (_userId == null)
      throw const AuthAppException('Пользователь не авторизован');

    try {
      // Обновляем teacher_id для всех занятий
      await _client
          .from('lessons')
          .update({
            'teacher_id': newTeacherId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', lessonIds);

      // Создаём записи в истории для каждого занятия (необязательно)
      for (final lessonId in lessonIds) {
        try {
          await _client.from('lesson_history').insert({
            'lesson_id': lessonId,
            'changed_by': _userId,
            'action': 'reassigned',
            'changes': {
              'teacher_id': {'old': null, 'new': newTeacherId},
            },
          });
        } catch (e) {
          // Игнорируем ошибки записи истории — переназначение важнее
          debugPrint('Не удалось записать историю для занятия $lessonId: $e');
        }
      }

      // Возвращаем обновлённые занятия
      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            students(*),
            student_groups(*),
            lesson_students(*, students(*))
          ''')
          .inFilter('id', lessonIds);

      return (data as List).map((item) => Lesson.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка переназначения занятий: $e');
    }
  }

  /// Получить количество будущих занятий преподавателя
  Future<int> countFutureLessonsForTeacher(
    String teacherId,
    String institutionId,
  ) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      final result = await _client
          .from('lessons')
          .select('id')
          .eq('teacher_id', teacherId)
          .eq('institution_id', institutionId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null);

      return (result as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Получить количество будущих занятий ученика
  Future<int> countFutureLessonsForStudent(String studentId) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      final result = await _client
          .from('lessons')
          .select('id')
          .eq('student_id', studentId)
          .gte('date', todayStr)
          .eq('status', 'scheduled')
          .isFilter('archived_at', null);

      return (result as List).length;
    } catch (e) {
      return 0;
    }
  }
}

/// Тип конфликта при переназначении
enum ConflictType {
  teacherBusy, // Преподаватель занят
  roomBusy, // Кабинет занят другим занятием
  bookingConflict, // Кабинет забронирован
  unknown, // Неизвестная ошибка
}

/// Конфликт при переназначении занятия
class LessonConflict {
  final Lesson lesson;
  final ConflictType type;
  final String description;

  const LessonConflict({
    required this.lesson,
    required this.type,
    required this.description,
  });
}
