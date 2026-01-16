import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/lesson_schedules/models/lesson_schedule.dart';
import 'package:kabinet/features/lesson_schedules/repositories/lesson_schedule_repository.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart'
    show InstitutionDateParams, lessonsByInstitutionStreamProvider;
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/features/payments/repositories/payment_repository.dart';
import 'package:kabinet/features/subscriptions/repositories/subscription_repository.dart';
import 'package:kabinet/features/students/repositories/student_repository.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';

/// Провайдер репозитория lesson schedules
final lessonScheduleRepositoryProvider = Provider<LessonScheduleRepository>((ref) {
  return LessonScheduleRepository();
});

/// Провайдер lesson schedules по заведению (realtime)
final lessonSchedulesByInstitutionProvider =
    StreamProvider.family<List<LessonSchedule>, String>((ref, institutionId) {
  final repo = ref.watch(lessonScheduleRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Провайдер lesson schedules ученика (realtime)
final lessonSchedulesByStudentProvider =
    StreamProvider.family<List<LessonSchedule>, String>((ref, studentId) {
  final repo = ref.watch(lessonScheduleRepositoryProvider);
  return repo.watchByStudent(studentId);
});

/// Провайдер lesson schedules валидных для конкретной даты
/// Фильтрует по дню недели, паузе, периоду действия и исключениям
final lessonSchedulesForDateProvider =
    Provider.family<List<LessonSchedule>, InstitutionDateParams>((ref, params) {
  final schedulesAsync = ref.watch(lessonSchedulesByInstitutionProvider(params.institutionId));

  // Получаем данные из async состояния
  final schedules = schedulesAsync.valueOrNull ?? [];

  // Фильтруем только те, что валидны для этой даты
  return schedules.where((s) => s.isValidForDate(params.date)).toList();
});

/// Провайдер lesson schedule по ID
final lessonScheduleProvider =
    FutureProvider.family<LessonSchedule, String>((ref, id) async {
  final repo = ref.watch(lessonScheduleRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер lesson schedules
class LessonScheduleController extends StateNotifier<AsyncValue<void>> {
  final LessonScheduleRepository _repo;
  final Ref _ref;

  LessonScheduleController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Инвалидация провайдеров после операций
  void _invalidateForInstitution(String institutionId) {
    _ref.invalidate(lessonSchedulesByInstitutionProvider(institutionId));
  }

  void _invalidateForStudent(String studentId) {
    _ref.invalidate(lessonSchedulesByStudentProvider(studentId));
  }

  /// Инвалидация lessonSchedulesForDateProvider для обновления UI расписания
  void _invalidateScheduleForDates(String institutionId) {
    final now = DateTime.now();
    for (int i = -7; i <= 30; i++) {
      final date = now.add(Duration(days: i));
      _ref.invalidate(lessonSchedulesForDateProvider(
        InstitutionDateParams(institutionId, date),
      ));
    }
  }

  // ============================================
  // Создание
  // ============================================

  /// Создать lesson schedule
  Future<LessonSchedule?> create({
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
    state = const AsyncValue.loading();
    try {
      // Проверяем конфликт
      final hasConflict = await _repo.hasConflict(
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasConflict) {
        throw Exception('Кабинет уже занят в это время');
      }

      final schedule = await _repo.create(
        institutionId: institutionId,
        roomId: roomId,
        teacherId: teacherId,
        studentId: studentId,
        groupId: groupId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidateForInstitution(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);

      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Создать несколько lesson schedules (для нескольких дней)
  Future<List<LessonSchedule>?> createBatch({
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
    state = const AsyncValue.loading();
    try {
      // Проверяем конфликты для каждого слота
      for (final slot in slots) {
        final hasConflict = await _repo.hasConflict(
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
        );

        if (hasConflict) {
          throw Exception('Кабинет уже занят в ${_dayName(slot.dayOfWeek)}');
        }
      }

      final schedules = await _repo.createBatch(
        institutionId: institutionId,
        roomId: roomId,
        teacherId: teacherId,
        studentId: studentId,
        groupId: groupId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        slots: slots,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidateForInstitution(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);

      state = const AsyncValue.data(null);
      return schedules;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  String _dayName(int day) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[day];
  }

  // ============================================
  // Обновление
  // ============================================

  /// Обновить lesson schedule
  Future<LessonSchedule?> update(
    String id, {
    required String institutionId,
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
    state = const AsyncValue.loading();
    try {
      // Если меняется время/день/кабинет — проверяем конфликты
      if (roomId != null || dayOfWeek != null || startTime != null || endTime != null) {
        final current = await _repo.getById(id);
        final checkRoom = roomId ?? current.roomId;
        final checkDay = dayOfWeek ?? current.dayOfWeek;
        final checkStart = startTime ?? current.startTime;
        final checkEnd = endTime ?? current.endTime;

        final hasConflict = await _repo.hasConflict(
          roomId: checkRoom,
          dayOfWeek: checkDay,
          startTime: checkStart,
          endTime: checkEnd,
          excludeScheduleId: id,
        );

        if (hasConflict) {
          throw Exception('Кабинет уже занят в это время');
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
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (schedule.studentId != null) {
        _invalidateForStudent(schedule.studentId!);
      }
      _invalidateScheduleForDates(institutionId);

      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // ============================================
  // Пауза/Возобновление
  // ============================================

  /// Приостановить lesson schedule
  Future<void> pause(String id, String institutionId, String? studentId, {DateTime? until}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.pause(id, until: until);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Возобновить lesson schedule
  Future<void> resume(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.resume(id);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ============================================
  // Замена кабинета
  // ============================================

  /// Установить временную замену кабинета
  Future<void> setReplacementRoom(
    String id,
    String institutionId,
    String? studentId,
    String replacementRoomId, {
    DateTime? until,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.setReplacementRoom(id, replacementRoomId, until: until);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Снять замену кабинета
  Future<void> clearReplacementRoom(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.clearReplacementRoom(id);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ============================================
  // Исключения
  // ============================================

  /// Добавить исключение (пропустить дату)
  Future<void> addException(
    String scheduleId,
    String institutionId,
    String? studentId,
    DateTime exceptionDate, {
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addException(scheduleId, exceptionDate, reason: reason);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(scheduleId));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Удалить исключение
  Future<void> removeException(
    String scheduleId,
    String institutionId,
    String? studentId,
    DateTime exceptionDate,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeException(scheduleId, exceptionDate);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(scheduleId));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ============================================
  // Архивация / Удаление
  // ============================================

  /// Архивировать lesson schedule
  Future<void> archive(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Восстановить из архива
  Future<void> restore(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.restore(id);
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Полное удаление
  Future<void> delete(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidateForInstitution(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      _invalidateScheduleForDates(institutionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Отменить расписание начиная с указанной даты
  /// Создаёт отменённое занятие на эту дату и завершает расписание
  Future<void> cancelScheduleFromDate(
    String scheduleId,
    DateTime date,
    String institutionId,
    String? studentId, {
    bool deductFromBalance = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      // 1. Создаём отменённое занятие на эту дату
      final lessonId = await _repo.createLessonFromSchedule(
        scheduleId,
        date,
        status: 'cancelled',
      );

      // 2. Если нужно списать с баланса
      if (deductFromBalance && studentId != null) {
        await _deductForCancelledLesson(lessonId, studentId, institutionId);
      }

      // 3. Полностью удаляем расписание из БД
      await _repo.delete(scheduleId);

      // 4. Инвалидируем провайдеры
      _invalidateForInstitution(institutionId);
      _ref.invalidate(lessonScheduleProvider(scheduleId));
      if (studentId != null) {
        _invalidateForStudent(studentId);
        _ref.invalidate(studentsProvider(institutionId));
      }
      // Обновляем занятия на этот день
      _ref.invalidate(lessonsByInstitutionStreamProvider(
        InstitutionDateParams(institutionId, date),
      ));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Списать занятие для отменённого занятия
  Future<void> _deductForCancelledLesson(
    String lessonId,
    String studentId,
    String institutionId,
  ) async {
    final paymentRepo = PaymentRepository();
    final subscriptionRepo = SubscriptionRepository();
    final studentRepo = StudentRepository();
    final lessonRepo = LessonRepository();

    try {
      // 1. Сначала пробуем списать с balance_transfer (остаток занятий)
      final transferId = await paymentRepo.deductBalanceTransfer(studentId);
      if (transferId != null) {
        await lessonRepo.setTransferPaymentId(lessonId, transferId);
      } else {
        // 2. Пробуем списать с подписки
        final subscriptionId = await subscriptionRepo.deductLessonAndGetId(studentId);

        if (subscriptionId == null) {
          // 3. Нет активной подписки — списываем напрямую (уход в долг)
          await studentRepo.decrementPrepaidCount(studentId);
        }
      }

      // Устанавливаем флаг списания
      await lessonRepo.setIsDeducted(lessonId, true);

      // Инвалидируем данные
      _ref.invalidate(studentProvider(studentId));
      _ref.invalidate(studentsProvider(institutionId));
    } catch (e) {
      debugPrint('Error deducting for cancelled lesson: $e');
      // Не критичная ошибка — продолжаем
    }
  }

  // ============================================
  // Создание занятия из расписания
  // ============================================

  /// Создать реальное занятие из виртуального
  /// Если status='completed' — автоматически списывает оплату с баланса ученика
  Future<String> createLessonFromSchedule(
    String scheduleId,
    DateTime date,
    String institutionId,
    String? studentId, {
    String status = 'completed',
  }) async {
    state = const AsyncValue.loading();
    try {
      final lessonId = await _repo.createLessonFromSchedule(scheduleId, date, status: status);

      // Если статус 'completed' и есть ученик — списываем оплату
      if (status == 'completed' && studentId != null) {
        await _deductPaymentForLesson(lessonId, studentId);
      }

      _invalidateForInstitution(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
        // Обновляем список учеников для актуального баланса
        _ref.invalidate(studentsProvider(institutionId));
      }
      // Обновляем занятия на этот день
      _ref.invalidate(lessonsByInstitutionStreamProvider(
        InstitutionDateParams(institutionId, date),
      ));

      state = const AsyncValue.data(null);
      return lessonId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Re-throw so UI can handle the error
    }
  }

  /// Списать оплату за занятие с баланса ученика
  /// Приоритет: 1) balance_transfer, 2) subscription, 3) prepaid (долг)
  Future<void> _deductPaymentForLesson(String lessonId, String studentId) async {
    final paymentRepo = PaymentRepository();
    final subscriptionRepo = SubscriptionRepository();
    final studentRepo = StudentRepository();
    final lessonRepo = LessonRepository();

    try {
      // 1. Сначала пробуем списать с balance_transfer (остаток занятий)
      final transferId = await paymentRepo.deductBalanceTransfer(studentId);
      if (transferId != null) {
        // Сохраняем transfer_payment_id для корректного возврата
        await lessonRepo.setTransferPaymentId(lessonId, transferId);
      } else {
        // 2. Пробуем списать с подписки
        final subscriptionId = await subscriptionRepo.deductLessonAndGetId(studentId);

        if (subscriptionId != null) {
          // Привязываем занятие к подписке для расчёта стоимости
          await lessonRepo.setSubscriptionId(lessonId, subscriptionId);
        } else {
          // 3. Нет активной подписки и остатка — списываем напрямую (уход в долг)
          await studentRepo.decrementPrepaidCount(studentId);
        }
      }
    } catch (e) {
      // Не критичная ошибка — занятие проведено, но подписка/долг не списаны
      // Логируем но не прерываем выполнение
    }
  }
}

/// Провайдер контроллера lesson schedules
final lessonScheduleControllerProvider =
    StateNotifierProvider<LessonScheduleController, AsyncValue<void>>((ref) {
  final repo = ref.watch(lessonScheduleRepositoryProvider);
  return LessonScheduleController(repo, ref);
});
