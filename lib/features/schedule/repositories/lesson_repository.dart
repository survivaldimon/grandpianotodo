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
          })
          .select()
          .single();

      return Lesson.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания занятия: $e');
    }
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

  /// Проверить конфликт времени
  Future<bool> hasTimeConflict({
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeLessonId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      var query = _client
          .from('lessons')
          .select('id')
          .eq('room_id', roomId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      if (excludeLessonId != null) {
        query = query.neq('id', excludeLessonId);
      }

      final data = await query;
      return (data as List).isNotEmpty;
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
  Stream<List<Lesson>> watchByRoom(String roomId, DateTime date) {
    final dateStr = date.toIso8601String().split('T').first;

    return _client
        .from('lessons')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('start_time')
        .map((data) => data
            .where((item) =>
                item['date'] == dateStr && item['archived_at'] == null)
            .map((item) => Lesson.fromJson(item))
            .toList());
  }

  /// Стрим занятий заведения за дату (realtime)
  Stream<List<Lesson>> watchByInstitution(String institutionId, DateTime date) {
    final dateStr = date.toIso8601String().split('T').first;

    return _client
        .from('lessons')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .order('start_time')
        .map((data) => data
            .where((item) =>
                item['date'] == dateStr && item['archived_at'] == null)
            .map((item) => Lesson.fromJson(item))
            .toList());
  }

  /// Стрим неотмеченных занятий (realtime)
  /// Для owner/admin возвращает все, для teacher - только его занятия
  Stream<List<Lesson>> watchUnmarkedLessons({
    required String institutionId,
    required bool isAdminOrOwner,
    String? teacherId,
  }) {
    return _client
        .from('lessons')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .order('date')
        .map((data) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return data
          .where((item) =>
              item['status'] == 'scheduled' &&
              item['archived_at'] == null &&
              (isAdminOrOwner || item['teacher_id'] == teacherId))
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
    });
  }
}
