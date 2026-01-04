import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/payments/repositories/payment_repository.dart';
import 'package:kabinet/features/subscriptions/repositories/subscription_repository.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

// Re-export types from statistics for use in payments screen
export 'package:kabinet/features/statistics/providers/statistics_provider.dart'
    show StatsPeriod, CustomDateRange, getPeriodDates;

/// Провайдер выбранного типа периода для экрана оплат
final paymentsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.month);

/// Провайдер кастомного диапазона дат для экрана оплат
final paymentsDateRangeProvider = StateProvider<CustomDateRange?>((ref) => null);

/// Провайдер репозитория оплат
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

/// Параметры периода
class PeriodParams {
  final String institutionId;
  final DateTime from;
  final DateTime to;

  PeriodParams(this.institutionId, this.from, this.to);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PeriodParams &&
        other.institutionId == institutionId &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(institutionId, from, to);
}

/// Провайдер выбранного периода
final selectedPeriodProvider = StateProvider<PeriodParams>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  return PeriodParams('', startOfMonth, endOfMonth);
});

/// Провайдер оплат за период
final paymentsProvider =
    FutureProvider.family<List<Payment>, PeriodParams>((ref, params) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getByPeriod(params.institutionId, from: params.from, to: params.to);
});

/// Провайдер оплат ученика
final studentPaymentsProvider =
    FutureProvider.family<List<Payment>, String>((ref, studentId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getByStudent(studentId);
});

/// Провайдер суммы за период
final periodTotalProvider =
    FutureProvider.family<double, PeriodParams>((ref, params) async {
  final payments = await ref.watch(paymentsProvider(params).future);
  double total = 0.0;
  for (final p in payments) {
    total += p.amount;
  }
  return total;
});

/// Провайдер тарифов заведения
final paymentPlansProvider =
    FutureProvider.family<List<PaymentPlan>, String>((ref, institutionId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPlans(institutionId);
});

/// Стрим оплат (realtime)
final paymentsStreamProvider =
    StreamProvider.family<List<Payment>, String>((ref, institutionId) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Стрим оплат за период (realtime) — для экрана оплат
final paymentsStreamByPeriodProvider =
    StreamProvider.family<List<Payment>, PeriodParams>((ref, params) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.watchByInstitution(params.institutionId).map((payments) {
    // Фильтруем по периоду на клиенте
    return payments.where((p) {
      return p.paidAt.isAfter(params.from.subtract(const Duration(seconds: 1))) &&
          p.paidAt.isBefore(params.to.add(const Duration(seconds: 1)));
    }).toList();
  });
});

/// Провайдер суммы оплат за сегодня (realtime)
final todayPaymentsTotalProvider =
    StreamProvider.family<double, String>((ref, institutionId) {
  final repo = ref.watch(paymentRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

  return repo.watchByInstitution(institutionId).map((payments) => payments
      .where((p) =>
          p.paidAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          p.paidAt.isBefore(endOfDay.add(const Duration(seconds: 1))))
      .fold(0.0, (sum, p) => sum + p.amount));
});

/// Контроллер оплат
class PaymentController extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repo;
  final SubscriptionRepository _subscriptionRepo;
  final Ref _ref;

  PaymentController(this._repo, this._subscriptionRepo, this._ref) : super(const AsyncValue.data(null));

  /// Создать оплату и подписку
  Future<Payment?> create({
    required String institutionId,
    required String studentId,
    String? paymentPlanId,
    required double amount,
    required int lessonsCount,
    String paymentMethod = 'cash',
    int validityDays = 30, // Срок действия подписки
    DateTime? paidAt,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Создаём платёж
      final payment = await _repo.create(
        institutionId: institutionId,
        studentId: studentId,
        paymentPlanId: paymentPlanId,
        amount: amount,
        lessonsCount: lessonsCount,
        paymentMethod: paymentMethod,
        paidAt: paidAt,
        comment: comment,
      );

      // Создаём подписку ТОЛЬКО для абонементов (пакет > 1 занятия)
      // Разовая оплата (1 занятие) НЕ создаёт подписку
      if (lessonsCount > 1) {
        final expiresAt = DateTime.now().add(Duration(days: validityDays));
        await _subscriptionRepo.create(
          institutionId: institutionId,
          studentId: studentId,
          paymentId: payment.id,
          lessonsTotal: lessonsCount,
          expiresAt: expiresAt,
        );
        _ref.invalidate(studentSubscriptionsProvider(studentId));
        _ref.invalidate(activeSubscriptionsProvider(studentId));
      }

      _ref.invalidate(studentPaymentsProvider(studentId));
      // Гибридный Realtime: инвалидируем stream для немедленного обновления
      _ref.invalidate(paymentsStreamProvider(institutionId));
      state = const AsyncValue.data(null);
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Payment?> createCorrection({
    required String institutionId,
    required String studentId,
    required double amount,
    required int lessonsCount,
    required String reason,
    String paymentMethod = 'cash',
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payment = await _repo.createCorrection(
        institutionId: institutionId,
        studentId: studentId,
        amount: amount,
        lessonsCount: lessonsCount,
        reason: reason,
        paymentMethod: paymentMethod,
        comment: comment,
      );

      _ref.invalidate(studentPaymentsProvider(studentId));
      // Гибридный Realtime: инвалидируем stream для немедленного обновления
      _ref.invalidate(paymentsStreamProvider(institutionId));
      state = const AsyncValue.data(null);
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<PaymentPlan?> createPlan({
    required String institutionId,
    required String name,
    required double price,
    required int lessonsCount,
    int validityDays = 30,
  }) async {
    state = const AsyncValue.loading();
    try {
      final plan = await _repo.createPlan(
        institutionId: institutionId,
        name: name,
        price: price,
        lessonsCount: lessonsCount,
        validityDays: validityDays,
      );

      _ref.invalidate(paymentPlansProvider(institutionId));
      state = const AsyncValue.data(null);
      return plan;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updatePlan(
    String id, {
    required String institutionId,
    String? name,
    double? price,
    int? lessonsCount,
    int? validityDays,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updatePlan(id, name: name, price: price, lessonsCount: lessonsCount, validityDays: validityDays);
      _ref.invalidate(paymentPlansProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archivePlan(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archivePlan(id);
      _ref.invalidate(paymentPlansProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<Payment?> updatePayment(
    String paymentId, {
    required String studentId,
    required int oldLessonsCount,
    double? amount,
    int? lessonsCount,
    String? paymentMethod,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payment = await _repo.update(
        paymentId,
        studentId: studentId,
        oldLessonsCount: oldLessonsCount,
        amount: amount,
        lessonsCount: lessonsCount,
        paymentMethod: paymentMethod,
        comment: comment,
      );
      _ref.invalidate(studentPaymentsProvider(studentId));
      state = const AsyncValue.data(null);
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deletePayment(String paymentId, {String? studentId}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(paymentId);
      if (studentId != null) {
        _ref.invalidate(studentPaymentsProvider(studentId));
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Найти оплату по ID занятия
  Future<Payment?> findByLessonId(String lessonId) async {
    return _repo.findByLessonId(lessonId);
  }

  /// Удалить оплату по ID занятия
  Future<bool> deleteByLessonId(String lessonId, {String? studentId}) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.deleteByLessonId(lessonId);
      if (success && studentId != null) {
        _ref.invalidate(studentPaymentsProvider(studentId));
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Создать семейную оплату и подписку
  Future<Payment?> createFamilyPayment({
    required String institutionId,
    required List<String> studentIds,
    String? paymentPlanId,
    required double amount,
    required int lessonsCount,
    String paymentMethod = 'cash',
    int validityDays = 30,
    DateTime? paidAt,
    String? comment,
  }) async {
    if (studentIds.isEmpty) return null;

    state = const AsyncValue.loading();
    try {
      // Создаём платёж, привязываем к первому ученику
      final payment = await _repo.create(
        institutionId: institutionId,
        studentId: studentIds.first,
        paymentPlanId: paymentPlanId,
        amount: amount,
        lessonsCount: lessonsCount,
        paymentMethod: paymentMethod,
        paidAt: paidAt,
        comment: comment,
      );

      // Создаём семейную подписку
      final expiresAt = DateTime.now().add(Duration(days: validityDays));
      await _subscriptionRepo.createFamily(
        institutionId: institutionId,
        studentIds: studentIds,
        paymentId: payment.id,
        lessonsTotal: lessonsCount,
        expiresAt: expiresAt,
      );

      // Инвалидируем провайдеры для всех участников
      for (final studentId in studentIds) {
        _ref.invalidate(studentPaymentsProvider(studentId));
        _ref.invalidate(studentSubscriptionsProvider(studentId));
        _ref.invalidate(studentAllSubscriptionsProvider(studentId));
        _ref.invalidate(activeSubscriptionsProvider(studentId));
      }

      // Гибридный Realtime: инвалидируем stream для немедленного обновления
      _ref.invalidate(paymentsStreamProvider(institutionId));
      state = const AsyncValue.data(null);
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

/// Провайдер контроллера оплат
final paymentControllerProvider =
    StateNotifierProvider<PaymentController, AsyncValue<void>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  final subscriptionRepo = ref.watch(subscriptionRepositoryProvider);
  return PaymentController(repo, subscriptionRepo, ref);
});
