import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/features/lesson_schedules/models/lesson_schedule.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Репозиторий для работы с постоянным расписанием занятий
class LessonScheduleRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Базовый SELECT с join-ами
  /// Примечание: teacher_id ссылается на auth.users, join недоступен напрямую
  /// Для загрузки данных преподавателя используем _attachTeachers
  static const _baseSelect = '''
    id,
    institution_id,
    room_id,
    teacher_id,
    student_id,
    group_id,
    subject_id,
    lesson_type_id,
    day_of_week,
    start_time,
    end_time,
    valid_from,
    valid_until,
    is_paused,
    pause_until,
    replacement_room_id,
    replacement_until,
    created_by,
    created_at,
    archived_at,
    students(*),
    rooms!lesson_schedules_room_id_fkey(*),
    replacement_room:rooms!lesson_schedules_replacement_room_id_fkey(*),
    subjects(*),
    lesson_types(*),
    lesson_schedule_exceptions(*)
  ''';

  /// Загружает данные преподавателей для списка расписаний и добавляет их
  /// Использует тот же паттерн, что и member_provider._loadMembersWithProfiles
  Future<List<LessonSchedule>> _attachTeachers(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return [];

    // Собираем уникальные teacher_id
    final teacherIds = <String>{};
    for (final item in data) {
      if (item['teacher_id'] != null) {
        teacherIds.add(item['teacher_id'] as String);
      }
    }

    // Загружаем данные из institution_members
    Map<String, Map<String, dynamic>> membersMap = {};
    if (teacherIds.isNotEmpty) {
      final members = await _client
          .from('institution_members')
          .select()
          .inFilter('user_id', teacherIds.toList());

      for (final m in members as List) {
        final userId = m['user_id'] as String;
        membersMap[userId] = Map<String, dynamic>.from(m);
      }
    }

    // Загружаем профили отдельно
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (teacherIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('id', teacherIds.toList());

      for (final p in profiles as List) {
        final id = p['id'] as String;
        profilesMap[id] = Map<String, dynamic>.from(p);
      }
    }

    // Добавляем профили к данным участников
    for (final userId in membersMap.keys) {
      if (profilesMap.containsKey(userId)) {
        membersMap[userId]!['profiles'] = profilesMap[userId];
      }
    }

    // Добавляем данные преподавателя к каждому расписанию
    return data.map((item) {
      final teacherId = item['teacher_id'] as String?;

      if (teacherId != null && membersMap.containsKey(teacherId)) {
        item['teacher'] = membersMap[teacherId];
      }

      return LessonSchedule.fromJson(item);
    }).toList();
  }

  // ============================================================================
  // ЧТЕНИЕ
  // ============================================================================

  /// Получить все расписания заведения
  Future<List<LessonSchedule>> getByInstitution(String institutionId) async {
    debugPrint('[LessonScheduleRepository] getByInstitution: $institutionId');
    try {
      final data = await _client
          .from('lesson_schedules')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('day_of_week')
          .order('start_time');

      debugPrint('[LessonScheduleRepository] Success! Got ${(data as List).length} records');
      return _attachTeachers(List<Map<String, dynamic>>.from(data));
    } catch (e, st) {
      debugPrint('[LessonScheduleRepository] ERROR: $e');
      debugPrint('[LessonScheduleRepository] Stack: $st');
      rethrow;
    }
  }

  /// Realtime поток расписаний заведения
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<LessonSchedule>> watchByInstitution(String institutionId) {
    final controller = StreamController<List<LessonSchedule>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final schedules = await getByInstitution(institutionId);
        if (!controller.isClosed) {
          controller.add(schedules);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('lesson_schedules')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[LessonScheduleRepository] watchByInstitution error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Получить расписания ученика
  Future<List<LessonSchedule>> getByStudent(String studentId) async {
    debugPrint('[LessonScheduleRepository] getByStudent: $studentId');
    try {
      final data = await _client
          .from('lesson_schedules')
          .select(_baseSelect)
          .eq('student_id', studentId)
          .isFilter('archived_at', null)
          .order('day_of_week')
          .order('start_time');

      debugPrint('[LessonScheduleRepository] Success! Got ${(data as List).length} records');
      return _attachTeachers(List<Map<String, dynamic>>.from(data));
    } catch (e, st) {
      debugPrint('[LessonScheduleRepository] ERROR: $e');
      debugPrint('[LessonScheduleRepository] Stack: $st');
      rethrow;
    }
  }

  /// Realtime поток расписаний ученика
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<LessonSchedule>> watchByStudent(String studentId) {
    final controller = StreamController<List<LessonSchedule>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final schedules = await getByStudent(studentId);
        if (!controller.isClosed) {
          controller.add(schedules);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('lesson_schedules')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[LessonScheduleRepository] watchByStudent error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Получить расписание по ID
  Future<LessonSchedule> getById(String id) async {
    final data = await _client
        .from('lesson_schedules')
        .select(_baseSelect)
        .eq('id', id)
        .single();

    final results = await _attachTeachers([data]);
    return results.first;
  }

  // ============================================================================
  // СОЗДАНИЕ
  // ============================================================================

  /// Создать новое расписание
  Future<LessonSchedule> create({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? studentId,
    String? groupId,
    String? subjectId,
    String? lessonTypeId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final data = await _client
        .from('lesson_schedules')
        .insert({
          'institution_id': institutionId,
          'room_id': roomId,
          'teacher_id': teacherId,
          'student_id': studentId,
          'group_id': groupId,
          'subject_id': subjectId,
          'lesson_type_id': lessonTypeId,
          'day_of_week': dayOfWeek,
          'start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
          'valid_from': validFrom != null
              ? '${validFrom.year}-${validFrom.month.toString().padLeft(2, '0')}-${validFrom.day.toString().padLeft(2, '0')}'
              : null,
          'valid_until': validUntil != null
              ? '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}'
              : null,
          'created_by': userId,
        })
        .select(_baseSelect)
        .single();

    final results = await _attachTeachers([data]);
    return results.first;
  }

  /// Создать несколько расписаний (batch)
  Future<List<LessonSchedule>> createBatch({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? studentId,
    String? groupId,
    String? subjectId,
    String? lessonTypeId,
    required List<DayTimeSlot> slots,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final insertData = slots.map((slot) => {
          'institution_id': institutionId,
          'room_id': slot.roomId ?? roomId, // Приоритет у индивидуального кабинета
          'teacher_id': teacherId,
          'student_id': studentId,
          'group_id': groupId,
          'subject_id': subjectId,
          'lesson_type_id': lessonTypeId,
          'day_of_week': slot.dayOfWeek,
          'start_time':
              '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
          'valid_from': validFrom != null
              ? '${validFrom.year}-${validFrom.month.toString().padLeft(2, '0')}-${validFrom.day.toString().padLeft(2, '0')}'
              : null,
          'valid_until': validUntil != null
              ? '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}'
              : null,
          'created_by': userId,
        }).toList();

    final data = await _client
        .from('lesson_schedules')
        .insert(insertData)
        .select(_baseSelect);

    return _attachTeachers(List<Map<String, dynamic>>.from(data));
  }

  // ============================================================================
  // ОБНОВЛЕНИЕ
  // ============================================================================

  /// Обновить расписание
  Future<LessonSchedule> update(
    String id, {
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final updates = <String, dynamic>{};

    if (roomId != null) updates['room_id'] = roomId;
    if (teacherId != null) updates['teacher_id'] = teacherId;
    if (subjectId != null) updates['subject_id'] = subjectId;
    if (lessonTypeId != null) updates['lesson_type_id'] = lessonTypeId;
    if (dayOfWeek != null) updates['day_of_week'] = dayOfWeek;
    if (startTime != null) {
      updates['start_time'] =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    }
    if (endTime != null) {
      updates['end_time'] =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    }
    if (validFrom != null) {
      updates['valid_from'] =
          '${validFrom.year}-${validFrom.month.toString().padLeft(2, '0')}-${validFrom.day.toString().padLeft(2, '0')}';
    }
    if (validUntil != null) {
      updates['valid_until'] =
          '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}';
    }

    final data = await _client
        .from('lesson_schedules')
        .update(updates)
        .eq('id', id)
        .select(_baseSelect)
        .single();

    final results = await _attachTeachers([data]);
    return results.first;
  }

  /// Приостановить расписание
  Future<void> pause(String id, {DateTime? until}) async {
    await _client.from('lesson_schedules').update({
      'is_paused': true,
      'pause_until': until != null
          ? '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}'
          : null,
    }).eq('id', id);
  }

  /// Возобновить расписание
  Future<void> resume(String id) async {
    await _client.from('lesson_schedules').update({
      'is_paused': false,
      'pause_until': null,
    }).eq('id', id);
  }

  /// Установить временную замену кабинета
  Future<void> setReplacementRoom(
    String id,
    String replacementRoomId, {
    DateTime? until,
  }) async {
    await _client.from('lesson_schedules').update({
      'replacement_room_id': replacementRoomId,
      'replacement_until': until != null
          ? '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}'
          : null,
    }).eq('id', id);
  }

  /// Снять замену кабинета
  Future<void> clearReplacementRoom(String id) async {
    await _client.from('lesson_schedules').update({
      'replacement_room_id': null,
      'replacement_until': null,
    }).eq('id', id);
  }

  // ============================================================================
  // ИСКЛЮЧЕНИЯ
  // ============================================================================

  /// Добавить исключение (пропустить дату)
  Future<void> addException(
    String scheduleId,
    DateTime exceptionDate, {
    String? reason,
  }) async {
    await _client.rpc('add_schedule_exception', params: {
      'p_schedule_id': scheduleId,
      'p_exception_date':
          '${exceptionDate.year}-${exceptionDate.month.toString().padLeft(2, '0')}-${exceptionDate.day.toString().padLeft(2, '0')}',
      'p_reason': reason,
    });
  }

  /// Удалить исключение
  Future<void> removeException(String scheduleId, DateTime exceptionDate) async {
    await _client
        .from('lesson_schedule_exceptions')
        .delete()
        .eq('schedule_id', scheduleId)
        .eq(
          'exception_date',
          '${exceptionDate.year}-${exceptionDate.month.toString().padLeft(2, '0')}-${exceptionDate.day.toString().padLeft(2, '0')}',
        );
  }

  // ============================================================================
  // АРХИВАЦИЯ / УДАЛЕНИЕ
  // ============================================================================

  /// Архивировать расписание (мягкое удаление)
  Future<void> archive(String id) async {
    await _client.from('lesson_schedules').update({
      'archived_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Восстановить из архива
  Future<void> restore(String id) async {
    await _client.from('lesson_schedules').update({
      'archived_at': null,
    }).eq('id', id);
  }

  /// Полное удаление (только для администраторов)
  Future<void> delete(String id) async {
    await _client.from('lesson_schedules').delete().eq('id', id);
  }

  /// Завершить расписание с указанной даты
  /// Устанавливает valid_until = date - 1 день, чтобы виртуальные занятия
  /// больше не генерировались начиная с этой даты
  Future<void> endScheduleFromDate(String scheduleId, DateTime date) async {
    final validUntil = date.subtract(const Duration(days: 1));
    await _client.from('lesson_schedules').update({
      'valid_until': validUntil.toIso8601String().split('T').first,
    }).eq('id', scheduleId);
  }

  // ============================================================================
  // СОЗДАНИЕ ЗАНЯТИЯ ИЗ РАСПИСАНИЯ
  // ============================================================================

  /// Создать реальное занятие из виртуального
  Future<String> createLessonFromSchedule(
    String scheduleId,
    DateTime date, {
    String status = 'completed',
  }) async {
    final result = await _client.rpc('create_lesson_from_schedule', params: {
      'p_schedule_id': scheduleId,
      'p_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'p_status': status,
    });

    return result as String;
  }

  // ============================================================================
  // ПРОВЕРКА КОНФЛИКТОВ
  // ============================================================================

  /// Проверить конфликт с существующими расписаниями
  Future<bool> hasConflict({
    required String roomId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeScheduleId,
  }) async {
    var query = _client
        .from('lesson_schedules')
        .select('id')
        .eq('room_id', roomId)
        .eq('day_of_week', dayOfWeek)
        .isFilter('archived_at', null)
        .eq('is_paused', false);

    if (excludeScheduleId != null) {
      query = query.neq('id', excludeScheduleId);
    }

    final data = await query;
    final schedules = data as List;

    // Проверяем пересечение времени для каждого
    for (final schedule in schedules) {
      // Нужно загрузить полные данные для проверки времени
      final fullSchedule = await getById(schedule['id'] as String);
      if (fullSchedule.hasTimeOverlap(startTime, endTime)) {
        return true;
      }
    }

    return false;
  }
}

/// Слот для batch-создания расписаний
class DayTimeSlot {
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? roomId; // Опционально: кабинет для этого конкретного дня

  const DayTimeSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.roomId,
  });
}
