import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/student_schedule.dart';

/// Репозиторий для работы с постоянным расписанием учеников
class StudentScheduleRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Форматирование времени для запросов
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// Базовый select с joins
  /// Примечание: profiles не подключаем напрямую - teacher_id ссылается на auth.users, не на profiles
  static const _baseSelect = '''
    *,
    students(*),
    rooms!room_id(*),
    replacement_rooms:rooms!replacement_room_id(*),
    subjects(*),
    lesson_types(*),
    schedule_exceptions(*)
  ''';

  // ============================================
  // Получение данных
  // ============================================

  /// Получить все активные слоты заведения
  Future<List<StudentSchedule>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('student_schedules')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('is_active', true)
          .order('day_of_week')
          .order('start_time');

      return (data as List)
          .map((item) => StudentSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки расписания: $e');
    }
  }

  /// Получить слоты заведения по дню недели
  Future<List<StudentSchedule>> getByInstitutionAndDay(
    String institutionId,
    int dayOfWeek,
  ) async {
    try {
      final data = await _client
          .from('student_schedules')
          .select(_baseSelect)
          .eq('institution_id', institutionId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true)
          .order('start_time');

      return (data as List)
          .map((item) => StudentSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки расписания: $e');
    }
  }

  /// Получить слоты ученика
  Future<List<StudentSchedule>> getByStudent(String studentId) async {
    try {
      final data = await _client
          .from('student_schedules')
          .select(_baseSelect)
          .eq('student_id', studentId)
          .order('day_of_week')
          .order('start_time');

      return (data as List)
          .map((item) => StudentSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки расписания ученика: $e');
    }
  }

  /// Получить слоты преподавателя
  Future<List<StudentSchedule>> getByTeacher(String teacherId) async {
    try {
      final data = await _client
          .from('student_schedules')
          .select(_baseSelect)
          .eq('teacher_id', teacherId)
          .eq('is_active', true)
          .order('day_of_week')
          .order('start_time');

      return (data as List)
          .map((item) => StudentSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки расписания преподавателя: $e');
    }
  }

  /// Получить слот по ID
  Future<StudentSchedule> getById(String id) async {
    try {
      final data = await _client
          .from('student_schedules')
          .select(_baseSelect)
          .eq('id', id)
          .single();

      return StudentSchedule.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки слота: $e');
    }
  }

  // ============================================
  // Создание
  // ============================================

  /// Создать слот
  Future<StudentSchedule> create({
    required String institutionId,
    required String studentId,
    required String teacherId,
    required String roomId,
    String? subjectId,
    String? lessonTypeId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    if (_userId == null) {
      throw const AuthAppException('Пользователь не авторизован');
    }

    try {
      final data = await _client
          .from('student_schedules')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'teacher_id': teacherId,
            'room_id': roomId,
            'subject_id': subjectId,
            'lesson_type_id': lessonTypeId,
            'day_of_week': dayOfWeek,
            'start_time': _formatTime(startTime),
            'end_time': _formatTime(endTime),
            'valid_from': validFrom?.toIso8601String().split('T').first,
            'valid_until': validUntil?.toIso8601String().split('T').first,
            'created_by': _userId,
          })
          .select(_baseSelect)
          .single();

      return StudentSchedule.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания слота: $e');
    }
  }

  /// Создать несколько слотов (для таблицы дней)
  Future<List<StudentSchedule>> createBatch({
    required String institutionId,
    required String studentId,
    required String teacherId,
    required String roomId,
    String? subjectId,
    String? lessonTypeId,
    required List<DayTimeSlot> slots,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    if (_userId == null) {
      throw const AuthAppException('Пользователь не авторизован');
    }

    try {
      final records = slots
          .map((slot) => {
                'institution_id': institutionId,
                'student_id': studentId,
                'teacher_id': teacherId,
                'room_id': roomId,
                'subject_id': subjectId,
                'lesson_type_id': lessonTypeId,
                'day_of_week': slot.dayOfWeek,
                'start_time': _formatTime(slot.startTime),
                'end_time': _formatTime(slot.endTime),
                'valid_from': validFrom?.toIso8601String().split('T').first,
                'valid_until': validUntil?.toIso8601String().split('T').first,
                'created_by': _userId,
              })
          .toList();

      final data = await _client
          .from('student_schedules')
          .insert(records)
          .select(_baseSelect);

      return (data as List)
          .map((item) => StudentSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка создания слотов: $e');
    }
  }

  // ============================================
  // Обновление
  // ============================================

  /// Обновить слот
  Future<StudentSchedule> update(
    String id, {
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isActive,
    bool? isPaused,
    DateTime? pauseUntil,
    String? replacementRoomId,
    DateTime? replacementUntil,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (roomId != null) updates['room_id'] = roomId;
      if (teacherId != null) updates['teacher_id'] = teacherId;
      if (subjectId != null) updates['subject_id'] = subjectId;
      if (lessonTypeId != null) updates['lesson_type_id'] = lessonTypeId;
      if (dayOfWeek != null) updates['day_of_week'] = dayOfWeek;
      if (startTime != null) updates['start_time'] = _formatTime(startTime);
      if (endTime != null) updates['end_time'] = _formatTime(endTime);
      if (isActive != null) updates['is_active'] = isActive;
      if (isPaused != null) updates['is_paused'] = isPaused;
      if (pauseUntil != null) {
        updates['pause_until'] = pauseUntil.toIso8601String().split('T').first;
      }
      if (replacementRoomId != null) {
        updates['replacement_room_id'] = replacementRoomId;
      }
      if (replacementUntil != null) {
        updates['replacement_until'] =
            replacementUntil.toIso8601String().split('T').first;
      }
      if (validFrom != null) {
        updates['valid_from'] = validFrom.toIso8601String().split('T').first;
      }
      if (validUntil != null) {
        updates['valid_until'] = validUntil.toIso8601String().split('T').first;
      }

      if (updates.isEmpty) {
        return getById(id);
      }

      final data = await _client
          .from('student_schedules')
          .update(updates)
          .eq('id', id)
          .select(_baseSelect)
          .single();

      return StudentSchedule.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления слота: $e');
    }
  }

  /// Деактивировать слот
  Future<void> deactivate(String id) async {
    try {
      await _client
          .from('student_schedules')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка деактивации слота: $e');
    }
  }

  /// Реактивировать слот
  Future<void> reactivate(String id) async {
    try {
      await _client
          .from('student_schedules')
          .update({'is_active': true, 'is_paused': false, 'pause_until': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка реактивации слота: $e');
    }
  }

  /// Приостановить слот до указанной даты
  Future<void> pause(String id, DateTime untilDate) async {
    try {
      await _client.from('student_schedules').update({
        'is_paused': true,
        'pause_until': untilDate.toIso8601String().split('T').first,
      }).eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка приостановки слота: $e');
    }
  }

  /// Возобновить слот (снять паузу)
  Future<void> resume(String id) async {
    try {
      await _client.from('student_schedules').update({
        'is_paused': false,
        'pause_until': null,
      }).eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка возобновления слота: $e');
    }
  }

  /// Установить временную замену кабинета
  Future<void> setReplacement(
    String id,
    String roomId,
    DateTime untilDate,
  ) async {
    try {
      await _client.from('student_schedules').update({
        'replacement_room_id': roomId,
        'replacement_until': untilDate.toIso8601String().split('T').first,
      }).eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка установки замены кабинета: $e');
    }
  }

  /// Снять временную замену кабинета
  Future<void> clearReplacement(String id) async {
    try {
      await _client.from('student_schedules').update({
        'replacement_room_id': null,
        'replacement_until': null,
      }).eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка снятия замены кабинета: $e');
    }
  }

  /// Переназначить преподавателя для списка слотов
  Future<void> reassignTeacher(
    List<String> scheduleIds,
    String newTeacherId,
  ) async {
    try {
      await _client
          .from('student_schedules')
          .update({'teacher_id': newTeacherId})
          .inFilter('id', scheduleIds);
    } catch (e) {
      throw DatabaseException('Ошибка переназначения преподавателя: $e');
    }
  }

  // ============================================
  // Удаление
  // ============================================

  /// Удалить слот
  Future<void> delete(String id) async {
    try {
      // schedule_exceptions удалятся каскадно
      await _client.from('student_schedules').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления слота: $e');
    }
  }

  // ============================================
  // Исключения
  // ============================================

  /// Добавить исключение
  Future<ScheduleException> addException({
    required String scheduleId,
    required DateTime exceptionDate,
    String? reason,
  }) async {
    if (_userId == null) {
      throw const AuthAppException('Пользователь не авторизован');
    }

    try {
      final data = await _client
          .from('schedule_exceptions')
          .insert({
            'schedule_id': scheduleId,
            'exception_date': exceptionDate.toIso8601String().split('T').first,
            'reason': reason,
            'created_by': _userId,
          })
          .select()
          .single();

      return ScheduleException.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка добавления исключения: $e');
    }
  }

  /// Удалить исключение
  Future<void> removeException(String exceptionId) async {
    try {
      await _client.from('schedule_exceptions').delete().eq('id', exceptionId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления исключения: $e');
    }
  }

  /// Получить исключения для слота
  Future<List<ScheduleException>> getExceptions(String scheduleId) async {
    try {
      final data = await _client
          .from('schedule_exceptions')
          .select()
          .eq('schedule_id', scheduleId)
          .order('exception_date');

      return (data as List)
          .map((item) =>
              ScheduleException.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки исключений: $e');
    }
  }

  // ============================================
  // Проверка конфликтов
  // ============================================

  /// Проверить конфликт с существующими слотами
  Future<bool> hasScheduleConflict({
    required String roomId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? excludeScheduleId,
  }) async {
    try {
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      var query = _client
          .from('student_schedules')
          .select('id')
          .eq('room_id', roomId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      if (excludeScheduleId != null) {
        query = query.neq('id', excludeScheduleId);
      }

      final data = await query;
      return (data as List).isNotEmpty;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов: $e');
    }
  }

  /// Проверить конфликт слота с занятиями на конкретную дату
  Future<bool> hasLessonConflictForDate({
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? studentId,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final startStr = _formatTime(startTime);
      final endStr = _formatTime(endTime);

      var query = _client
          .from('lessons')
          .select('id, student_id')
          .eq('room_id', roomId)
          .eq('date', dateStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      final data = await query;

      // Если передан studentId, исключаем занятия этого ученика
      if (studentId != null) {
        final conflicts = (data as List).where((lesson) {
          return lesson['student_id'] != studentId;
        }).toList();
        return conflicts.isNotEmpty;
      }

      return (data as List).isNotEmpty;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов с занятиями: $e');
    }
  }

  /// Проверить конфликт с ВСЕМИ будущими занятиями для конкретного дня недели
  /// Проверяет занятия от сегодня и на год вперёд
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

      // Загружаем все будущие занятия в этом кабинете в указанное время
      final data = await _client
          .from('lessons')
          .select('id, student_id, date')
          .eq('room_id', roomId)
          .gte('date', todayStr)
          .isFilter('archived_at', null)
          .lt('start_time', endStr)
          .gt('end_time', startStr);

      // Фильтруем по дню недели на клиенте
      final conflicts = (data as List).where((lesson) {
        final lessonDate = DateTime.parse(lesson['date'] as String);
        // weekday: 1 = Monday, 7 = Sunday
        if (lessonDate.weekday != dayOfWeek) return false;

        // Исключаем занятия указанного ученика
        if (studentId != null && lesson['student_id'] == studentId) {
          return false;
        }
        return true;
      }).toList();

      return conflicts.isNotEmpty;
    } catch (e) {
      throw DatabaseException('Ошибка проверки конфликтов с занятиями: $e');
    }
  }

  // ============================================
  // Realtime
  // ============================================

  /// Стрим слотов заведения (realtime)
  Stream<List<StudentSchedule>> watchByInstitution(
      String institutionId) async* {
    // 1. Сразу выдаём текущие данные
    yield await getByInstitution(institutionId);

    // 2. Подписываемся на изменения
    await for (final _ in _client
        .from('student_schedules')
        .stream(primaryKey: ['id']).eq('institution_id', institutionId)) {
      final schedules = await getByInstitution(institutionId);
      yield schedules;
    }
  }

  /// Стрим слотов ученика (realtime)
  Stream<List<StudentSchedule>> watchByStudent(String studentId) async* {
    // 1. Сразу выдаём текущие данные
    yield await getByStudent(studentId);

    // 2. Подписываемся на изменения
    await for (final _ in _client
        .from('student_schedules')
        .stream(primaryKey: ['id']).eq('student_id', studentId)) {
      final schedules = await getByStudent(studentId);
      yield schedules;
    }
  }
}

/// Вспомогательный класс для создания слотов пачкой
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
