import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/bookings/models/booking.dart';
import 'package:kabinet/features/bookings/repositories/booking_repository.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart'
    show InstitutionDateParams, InstitutionWeekParams;

/// Провайдер репозитория бронирований
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

/// Провайдер бронирований по заведению и дате (realtime)
final bookingsByInstitutionDateProvider =
    StreamProvider.family<List<Booking>, InstitutionDateParams>((ref, params) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchByInstitutionAndDate(params.institutionId, params.date);
});

/// Провайдер еженедельных бронирований заведения (realtime)
final weeklyBookingsByInstitutionProvider =
    StreamProvider.family<List<Booking>, String>((ref, institutionId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchWeeklyByInstitution(institutionId);
});

/// Провайдер бронирований ученика (realtime)
final bookingsByStudentProvider =
    StreamProvider.family<List<Booking>, String>((ref, studentId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchByStudent(studentId);
});

/// Провайдер бронирований за неделю (FutureProvider - без realtime)
/// Используется как fallback
final bookingsByInstitutionWeekProvider =
    FutureProvider.family<Map<DateTime, List<Booking>>, InstitutionWeekParams>(
        (ref, params) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final weekEnd = params.weekStart.add(const Duration(days: 6));

  final bookings = await repo.getByInstitutionAndDateRange(
    params.institutionId,
    params.weekStart,
    weekEnd,
  );

  // Группируем по дате
  final result = <DateTime, List<Booking>>{};
  for (final day in params.weekDays) {
    final dayStart = DateTime(day.year, day.month, day.day);
    result[dayStart] = bookings.where((b) {
      // Разовые брони — по дате
      if (!b.isRecurring && b.date != null) {
        return b.date!.year == day.year &&
            b.date!.month == day.month &&
            b.date!.day == day.day;
      }
      // Еженедельные брони — по дню недели и isValidForDate
      if (b.isRecurring && b.dayOfWeek == day.weekday) {
        return b.isValidForDate(day);
      }
      return false;
    }).toList();
  }

  return result;
});

/// Провайдер бронирований за неделю (с realtime!)
/// Комбинирует 7 StreamProvider (по одному на день)
/// При изменении бронирований любого дня — весь map автоматически обновляется
/// ВАЖНО: Используем valueOrNull для сохранения данных при перезагрузке
final bookingsByInstitutionWeekStreamProvider =
    Provider.family<AsyncValue<Map<DateTime, List<Booking>>>, InstitutionWeekParams>((ref, params) {
  final result = <DateTime, List<Booking>>{};
  var isLoading = false;
  Object? error;
  StackTrace? stackTrace;

  // Собираем данные из StreamProvider для каждого дня недели
  for (final day in params.weekDays) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dayParams = InstitutionDateParams(params.institutionId, day);
    final dayAsync = ref.watch(bookingsByInstitutionDateProvider(dayParams));

    // Используем valueOrNull чтобы сохранить предыдущее значение при перезагрузке
    // Это предотвращает "мигание" данных когда Realtime триггерит обновление
    final bookings = dayAsync.valueOrNull;
    if (bookings != null) {
      result[normalizedDay] = bookings;
    }

    // Отслеживаем состояние только для ПЕРВОЙ загрузки (когда нет кеша)
    if (dayAsync.isLoading && bookings == null) {
      isLoading = true;
    }
    if (dayAsync.hasError && bookings == null) {
      error = dayAsync.error;
      stackTrace = dayAsync.stackTrace;
    }
  }

  // Если хоть один день грузится и нет данных — loading
  if (isLoading && result.isEmpty) {
    return const AsyncValue.loading();
  }

  // Если есть ошибка и нет данных — error
  if (error != null && result.isEmpty) {
    return AsyncValue.error(error!, stackTrace ?? StackTrace.current);
  }

  // Возвращаем данные (даже если какие-то дни ещё грузятся)
  return AsyncValue.data(result);
});

/// Провайдер брони по ID
final bookingProvider =
    FutureProvider.family<Booking, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getById(id);
});

/// Провайдер еженедельных бронирований для конкретной даты
/// Аналог schedulesForDateProvider — возвращает weekly bookings, валидные для даты
final weeklyBookingsForDateProvider =
    Provider.family<List<Booking>, InstitutionDateParams>((ref, params) {
  final weeklyAsync = ref.watch(weeklyBookingsByInstitutionProvider(params.institutionId));

  // Получаем данные из async состояния
  final weeklyBookings = weeklyAsync.valueOrNull ?? [];

  // Фильтруем только те, что валидны для этой даты
  return weeklyBookings.where((b) => b.isValidForDate(params.date)).toList();
});

/// Контроллер бронирований
class BookingController extends StateNotifier<AsyncValue<void>> {
  final BookingRepository _repo;
  final Ref _ref;

  BookingController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Инвалидация провайдеров после операций
  void _invalidateForDate(String institutionId, DateTime date) {
    _ref.invalidate(
        bookingsByInstitutionDateProvider(InstitutionDateParams(institutionId, date)));
  }

  void _invalidateForStudent(String studentId) {
    _ref.invalidate(bookingsByStudentProvider(studentId));
  }

  void _invalidateWeekly(String institutionId) {
    _ref.invalidate(weeklyBookingsByInstitutionProvider(institutionId));
  }

  // ============================================
  // Разовые бронирования
  // ============================================

  /// Создать разовое бронирование
  Future<Booking?> create({
    required String institutionId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Проверяем оба типа конфликтов параллельно
      final results = await Future.wait([
        _repo.checkBookingConflicts(
          roomIds: roomIds,
          date: date,
          startTime: startTime,
          endTime: endTime,
        ),
        _repo.checkLessonConflicts(
          roomIds: roomIds,
          date: date,
          startTime: startTime,
          endTime: endTime,
        ),
      ]);

      final bookingConflicts = results[0];
      final lessonConflicts = results[1];

      if (bookingConflicts.isNotEmpty) {
        throw Exception(
            'Кабинеты уже забронированы в это время: ${bookingConflicts.length} конфликтов');
      }

      if (lessonConflicts.isNotEmpty) {
        throw Exception(
            'В кабинетах запланированы занятия: ${lessonConflicts.length} конфликтов');
      }

      final booking = await _repo.create(
        institutionId: institutionId,
        roomIds: roomIds,
        date: date,
        startTime: startTime,
        endTime: endTime,
        description: description,
      );

      _invalidateForDate(institutionId, date);
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Обновить бронирование
  Future<Booking?> update(
    String id, {
    required String institutionId,
    required DateTime originalDate,
    List<String>? roomIds,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Если меняется время или кабинеты — проверяем конфликты
      if (roomIds != null || startTime != null || endTime != null || date != null) {
        // Получаем текущую бронь для заполнения пропущенных параметров
        final current = await _repo.getById(id);
        final checkRoomIds = roomIds ?? current.rooms.map((r) => r.id).toList();
        final checkDate = date ?? current.date ?? originalDate;
        final checkStart = startTime ?? current.startTime;
        final checkEnd = endTime ?? current.endTime;

        // Проверяем конфликты с другими бронями
        final bookingConflicts = await _repo.checkBookingConflicts(
          roomIds: checkRoomIds,
          date: checkDate,
          startTime: checkStart,
          endTime: checkEnd,
          excludeBookingId: id,
        );

        if (bookingConflicts.isNotEmpty) {
          throw Exception(
              'Кабинеты уже забронированы в это время: ${bookingConflicts.length} конфликтов');
        }

        // Проверяем конфликты с занятиями
        final lessonConflicts = await _repo.checkLessonConflicts(
          roomIds: checkRoomIds,
          date: checkDate,
          startTime: checkStart,
          endTime: checkEnd,
        );

        if (lessonConflicts.isNotEmpty) {
          throw Exception(
              'В кабинетах запланированы занятия: ${lessonConflicts.length} конфликтов');
        }
      }

      final booking = await _repo.update(
        id,
        roomIds: roomIds,
        date: date,
        startTime: startTime,
        endTime: endTime,
        description: description,
      );

      // Инвалидируем оба дня если дата изменилась
      _invalidateForDate(institutionId, originalDate);
      if (date != null && date != originalDate) {
        _invalidateForDate(institutionId, date);
      }
      _ref.invalidate(bookingProvider(id));

      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Удалить бронирование
  Future<bool> delete(String id, String institutionId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidateForDate(institutionId, date);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // ============================================
  // Еженедельные бронирования (постоянное расписание)
  // ============================================

  /// Создать еженедельное бронирование
  Future<Booking?> createRecurring({
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
  }) async {
    state = const AsyncValue.loading();
    try {
      // Проверяем конфликт с другими weekly бронями
      final hasConflict = await _repo.hasWeeklyConflict(
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasConflict) {
        throw Exception('Кабинет уже забронирован в это время');
      }

      // Проверяем конфликт с занятиями (если есть ученик — пропускаем его занятия)
      final hasLessonConflict = await _repo.hasLessonConflictForDayOfWeek(
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId,
      );

      if (hasLessonConflict) {
        throw Exception('В кабинете запланированы занятия в это время');
      }

      final booking = await _repo.createRecurring(
        institutionId: institutionId,
        roomId: roomId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        validFrom: validFrom,
        validUntil: validUntil,
        description: description,
      );

      _invalidateWeekly(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }

      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Пробрасываем ошибку для обработки в UI
    }
  }

  /// Создать несколько еженедельных бронирований (для нескольких дней)
  Future<List<Booking>?> createRecurringBatch({
    required String institutionId,
    required String roomId,
    required List<DayTimeSlot> slots,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Проверяем конфликты для каждого слота
      for (final slot in slots) {
        final hasConflict = await _repo.hasWeeklyConflict(
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
        );

        if (hasConflict) {
          throw Exception('Кабинет уже забронирован в ${_dayName(slot.dayOfWeek)}');
        }

        final hasLessonConflict = await _repo.hasLessonConflictForDayOfWeek(
          roomId: roomId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
          studentId: studentId,
        );

        if (hasLessonConflict) {
          throw Exception('В кабинете запланированы занятия в ${_dayName(slot.dayOfWeek)}');
        }
      }

      final bookings = await _repo.createRecurringBatch(
        institutionId: institutionId,
        roomId: roomId,
        slots: slots,
        studentId: studentId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        validFrom: validFrom,
        validUntil: validUntil,
      );

      _invalidateWeekly(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }

      state = const AsyncValue.data(null);
      return bookings;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Пробрасываем ошибку для обработки в UI
    }
  }

  String _dayName(int day) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[day];
  }

  /// Обновить еженедельное бронирование
  Future<Booking?> updateRecurring(
    String id, {
    required String institutionId,
    String? roomId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    DateTime? validFrom,
    DateTime? validUntil,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final current = await _repo.getById(id);

      // Проверяем конфликты если меняются время/день/кабинет
      if (roomId != null || dayOfWeek != null || startTime != null || endTime != null) {
        final checkRoom = roomId ?? current.rooms.firstOrNull?.id;
        final checkDay = dayOfWeek ?? current.dayOfWeek ?? 1;
        final checkStart = startTime ?? current.startTime;
        final checkEnd = endTime ?? current.endTime;

        if (checkRoom != null) {
          final hasConflict = await _repo.hasWeeklyConflict(
            roomId: checkRoom,
            dayOfWeek: checkDay,
            startTime: checkStart,
            endTime: checkEnd,
            excludeBookingId: id,
          );

          if (hasConflict) {
            throw Exception('Кабинет уже забронирован в это время');
          }
        }
      }

      final booking = await _repo.update(
        id,
        roomIds: roomId != null ? [roomId] : null,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        validFrom: validFrom,
        validUntil: validUntil,
        description: description,
      );

      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (current.studentId != null) {
        _invalidateForStudent(current.studentId!);
      }
      if (studentId != null && studentId != current.studentId) {
        _invalidateForStudent(studentId);
      }

      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Удалить еженедельное бронирование
  Future<bool> deleteRecurring(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidateWeekly(institutionId);
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // ============================================
  // Архивация
  // ============================================

  /// Архивировать бронирование
  Future<bool> archive(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Разархивировать бронирование
  Future<bool> unarchive(String id, String institutionId, String? studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.unarchive(id);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // ============================================
  // Пауза/Возобновление
  // ============================================

  /// Приостановить бронирование
  Future<Booking?> pause(String id, String institutionId, DateTime? untilDate) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repo.pause(id, untilDate);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (booking.studentId != null) {
        _invalidateForStudent(booking.studentId!);
      }
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Возобновить бронирование
  Future<Booking?> resume(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repo.resume(id);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (booking.studentId != null) {
        _invalidateForStudent(booking.studentId!);
      }
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // ============================================
  // Замена кабинета
  // ============================================

  /// Установить временную замену кабинета
  Future<Booking?> setReplacement(
    String id,
    String institutionId,
    String replacementRoomId,
    DateTime replacementUntil,
  ) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repo.setReplacement(id, replacementRoomId, replacementUntil);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (booking.studentId != null) {
        _invalidateForStudent(booking.studentId!);
      }
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Снять временную замену кабинета
  Future<Booking?> clearReplacement(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repo.clearReplacement(id);
      _invalidateWeekly(institutionId);
      _ref.invalidate(bookingProvider(id));
      if (booking.studentId != null) {
        _invalidateForStudent(booking.studentId!);
      }
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // ============================================
  // Исключения
  // ============================================

  /// Добавить исключение (дату когда бронь не действует)
  Future<BookingException?> addException({
    required String bookingId,
    required String institutionId,
    required DateTime exceptionDate,
    String? reason,
    String? studentId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final exception = await _repo.addException(
        bookingId: bookingId,
        exceptionDate: exceptionDate,
        reason: reason,
      );
      _invalidateWeekly(institutionId);
      _invalidateForDate(institutionId, exceptionDate);
      _ref.invalidate(bookingProvider(bookingId));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
      return exception;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Удалить исключение
  Future<bool> removeException({
    required String exceptionId,
    required String bookingId,
    required String institutionId,
    required DateTime exceptionDate,
    String? studentId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeException(exceptionId);
      _invalidateWeekly(institutionId);
      _invalidateForDate(institutionId, exceptionDate);
      _ref.invalidate(bookingProvider(bookingId));
      if (studentId != null) {
        _invalidateForStudent(studentId);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера бронирований
final bookingControllerProvider =
    StateNotifierProvider<BookingController, AsyncValue<void>>((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return BookingController(repo, ref);
});
