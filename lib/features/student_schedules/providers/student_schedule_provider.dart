import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/student_schedules/repositories/student_schedule_repository.dart';
import 'package:kabinet/shared/models/student_schedule.dart';

/// Провайдер репозитория
final studentScheduleRepositoryProvider =
    Provider<StudentScheduleRepository>((ref) {
  return StudentScheduleRepository();
});

/// Провайдер слотов заведения (realtime)
final institutionSchedulesStreamProvider =
    StreamProvider.family<List<StudentSchedule>, String>(
        (ref, institutionId) {
  final repo = ref.watch(studentScheduleRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Параметры для слотов по дате
class ScheduleDateParams {
  final String institutionId;
  final DateTime date;

  const ScheduleDateParams(this.institutionId, this.date);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleDateParams &&
        other.institutionId == institutionId &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode =>
      Object.hash(institutionId, date.year, date.month, date.day);
}

/// Провайдер слотов для конкретной даты
/// Фильтрует по дню недели и исключениям
final schedulesForDateProvider =
    Provider.family<List<StudentSchedule>, ScheduleDateParams>((ref, params) {
  final allSchedulesAsync =
      ref.watch(institutionSchedulesStreamProvider(params.institutionId));

  return allSchedulesAsync.maybeWhen(
    data: (schedules) {
      return schedules
          .where((s) => s.isValidForDate(params.date))
          .toList()
        ..sort((a, b) {
          // Сортируем по времени начала
          final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
          final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
          return aMinutes.compareTo(bMinutes);
        });
    },
    orElse: () => [],
  );
});

/// Параметры для слотов ученика (нужен institutionId для realtime через общий канал)
class StudentScheduleParams {
  final String studentId;
  final String institutionId;

  const StudentScheduleParams(this.studentId, this.institutionId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentScheduleParams &&
          other.studentId == studentId &&
          other.institutionId == institutionId;

  @override
  int get hashCode => Object.hash(studentId, institutionId);
}

/// Провайдер слотов ученика (использует общий канал заведения для экономии)
/// Realtime работает через institutionSchedulesStreamProvider + фильтрация
final studentSchedulesProvider =
    Provider.family<List<StudentSchedule>, StudentScheduleParams>((ref, params) {
  final allSchedulesAsync = ref.watch(institutionSchedulesStreamProvider(params.institutionId));

  return allSchedulesAsync.maybeWhen(
    data: (schedules) => schedules
        .where((s) => s.studentId == params.studentId)
        .toList()
      ..sort((a, b) {
        final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCompare != 0) return dayCompare;
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      }),
    orElse: () => [],
  );
});

/// Провайдер слотов ученика по ID (fallback без realtime, для совместимости)
final studentSchedulesByIdProvider =
    FutureProvider.family<List<StudentSchedule>, String>((ref, studentId) async {
  final repo = ref.watch(studentScheduleRepositoryProvider);
  return repo.getByStudent(studentId);
});

/// Провайдер активных слотов ученика
final activeStudentSchedulesProvider =
    Provider.family<List<StudentSchedule>, StudentScheduleParams>((ref, params) {
  final schedules = ref.watch(studentSchedulesProvider(params));

  return schedules
      .where((s) => s.isActive)
      .toList()
    ..sort((a, b) {
      // Сначала по дню недели, потом по времени
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
      final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });
});

/// Провайдер неактивных (архивных) слотов ученика
final inactiveStudentSchedulesProvider =
    Provider.family<List<StudentSchedule>, StudentScheduleParams>((ref, params) {
  final schedules = ref.watch(studentSchedulesProvider(params));

  return schedules.where((s) => !s.isActive).toList();
});

/// Провайдер слотов преподавателя
final teacherSchedulesProvider =
    FutureProvider.family<List<StudentSchedule>, String>(
        (ref, teacherId) async {
  final repo = ref.watch(studentScheduleRepositoryProvider);
  return repo.getByTeacher(teacherId);
});

/// Провайдер слота по ID
final scheduleProvider =
    FutureProvider.family<StudentSchedule, String>((ref, id) async {
  final repo = ref.watch(studentScheduleRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер слотов расписания
class StudentScheduleController extends StateNotifier<AsyncValue<void>> {
  final StudentScheduleRepository _repo;
  final Ref _ref;

  StudentScheduleController(this._repo, this._ref)
      : super(const AsyncValue.data(null));

  /// Инвалидация провайдеров после операций
  void _invalidate(String institutionId, String studentId) {
    // Инвалидируем общий канал заведения — это обновит все зависимые провайдеры
    _ref.invalidate(institutionSchedulesStreamProvider(institutionId));
    // Также инвалидируем конкретный провайдер ученика
    _ref.invalidate(studentSchedulesProvider(StudentScheduleParams(studentId, institutionId)));
  }

  /// Создать слот
  Future<StudentSchedule?> create({
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
    state = const AsyncValue.loading();
    try {
      // 1. Проверка конфликта с другими постоянными слотами
      final hasScheduleConflict = await _repo.hasScheduleConflict(
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasScheduleConflict) {
        throw Exception('Кабинет уже занят постоянным слотом в это время');
      }

      // 2. Проверка конфликта с ВСЕМИ будущими занятиями для этого дня недели
      final hasLessonConflict = await _repo.hasLessonConflictForDayOfWeek(
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId, // Исключаем занятия этого ученика
      );

      if (hasLessonConflict) {
        throw Exception('Кабинет занят другими занятиями в это время');
      }

      final schedule = await _repo.create(
        institutionId: institutionId,
        studentId: studentId,
        teacherId: teacherId,
        roomId: roomId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Пробрасываем ошибку для обработки в UI
    }
  }

  /// Создать несколько слотов (для таблицы дней)
  Future<List<StudentSchedule>?> createBatch({
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
    state = const AsyncValue.loading();
    try {
      final dayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

      // Проверка конфликтов для каждого слота
      for (final slot in slots) {
        // 1. Проверка конфликта с другими постоянными слотами
        final hasScheduleConflict = await _repo.hasScheduleConflict(
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
        );

        if (hasScheduleConflict) {
          throw Exception(
              'Кабинет уже занят постоянным слотом в ${dayNames[slot.dayOfWeek]}');
        }

        // 2. Проверка конфликта с ВСЕМИ будущими занятиями для этого дня недели
        final hasLessonConflict = await _repo.hasLessonConflictForDayOfWeek(
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
          studentId: studentId, // Исключаем занятия этого ученика
        );

        if (hasLessonConflict) {
          throw Exception(
              'Кабинет занят другими занятиями в ${dayNames[slot.dayOfWeek]}');
        }
      }

      final schedules = await _repo.createBatch(
        institutionId: institutionId,
        studentId: studentId,
        teacherId: teacherId,
        roomId: roomId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        slots: slots,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return schedules;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Пробрасываем ошибку для обработки в UI
    }
  }

  /// Обновить слот
  Future<StudentSchedule?> update(
    String id, {
    required String institutionId,
    required String studentId,
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
    state = const AsyncValue.loading();
    try {
      // Если меняется время/кабинет/день — проверяем конфликты
      if (roomId != null ||
          dayOfWeek != null ||
          startTime != null ||
          endTime != null) {
        final current = await _repo.getById(id);
        final checkRoomId = roomId ?? current.roomId;
        final checkDay = dayOfWeek ?? current.dayOfWeek;
        final checkStart = startTime ?? current.startTime;
        final checkEnd = endTime ?? current.endTime;

        final hasConflict = await _repo.hasScheduleConflict(
          roomId: checkRoomId,
          dayOfWeek: checkDay,
          startTime: checkStart,
          endTime: checkEnd,
          excludeScheduleId: id,
        );

        if (hasConflict) {
          throw Exception('Кабинет уже занят постоянным слотом в это время');
        }
      }

      final schedule = await _repo.update(
        id,
        roomId: roomId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        isActive: isActive,
        isPaused: isPaused,
        pauseUntil: pauseUntil,
        replacementRoomId: replacementRoomId,
        replacementUntil: replacementUntil,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidate(institutionId, studentId);
      _ref.invalidate(scheduleProvider(id));
      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Деактивировать слот
  Future<bool> deactivate(
    String id,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deactivate(id);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Реактивировать слот
  Future<bool> reactivate(
    String id,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reactivate(id);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Приостановить слот
  Future<bool> pause(
    String id,
    DateTime untilDate,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.pause(id, untilDate);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Возобновить слот
  Future<bool> resume(
    String id,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.resume(id);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Установить временную замену кабинета
  Future<bool> setReplacement(
    String id,
    String roomId,
    DateTime untilDate,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.setReplacement(id, roomId, untilDate);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Снять временную замену кабинета
  Future<bool> clearReplacement(
    String id,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.clearReplacement(id);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Переназначить преподавателя для слотов
  Future<bool> reassignTeacher(
    List<String> scheduleIds,
    String newTeacherId,
    String institutionId,
    List<String> studentIds,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reassignTeacher(scheduleIds, newTeacherId);
      // Инвалидируем общий канал — это обновит все зависимые провайдеры
      _ref.invalidate(institutionSchedulesStreamProvider(institutionId));
      // Также инвалидируем конкретных учеников
      for (final studentId in studentIds) {
        _ref.invalidate(studentSchedulesProvider(StudentScheduleParams(studentId, institutionId)));
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить слот
  Future<bool> delete(
    String id,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidate(institutionId, studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Добавить исключение
  Future<ScheduleException?> addException({
    required String scheduleId,
    required DateTime exceptionDate,
    required String institutionId,
    required String studentId,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final exception = await _repo.addException(
        scheduleId: scheduleId,
        exceptionDate: exceptionDate,
        reason: reason,
      );
      _invalidate(institutionId, studentId);
      _ref.invalidate(scheduleProvider(scheduleId));
      state = const AsyncValue.data(null);
      return exception;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Удалить исключение
  Future<bool> removeException(
    String exceptionId,
    String scheduleId,
    String institutionId,
    String studentId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeException(exceptionId);
      _invalidate(institutionId, studentId);
      _ref.invalidate(scheduleProvider(scheduleId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера слотов
final studentScheduleControllerProvider =
    StateNotifierProvider<StudentScheduleController, AsyncValue<void>>((ref) {
  final repo = ref.watch(studentScheduleRepositoryProvider);
  return StudentScheduleController(repo, ref);
});
