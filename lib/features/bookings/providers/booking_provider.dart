import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/bookings/models/booking.dart';
import 'package:kabinet/features/bookings/repositories/booking_repository.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';

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

/// Провайдер бронирований за неделю
/// Возвращает Map<DateTime, List<Booking>> где ключ - дата (начало дня)
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
    result[dayStart] = bookings
        .where((b) =>
            b.date.year == day.year &&
            b.date.month == day.month &&
            b.date.day == day.day)
        .toList();
  }

  return result;
});

/// Провайдер брони по ID
final bookingProvider =
    FutureProvider.family<Booking, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getById(id);
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
    // Также инвалидируем недельный провайдер
    // (он перезагрузится при следующем использовании)
  }

  /// Создать бронирование
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
        final checkDate = date ?? current.date;
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
}

/// Провайдер контроллера бронирований
final bookingControllerProvider =
    StateNotifierProvider<BookingController, AsyncValue<void>>((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return BookingController(repo, ref);
});
