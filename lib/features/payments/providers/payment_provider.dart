import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/payments/repositories/payment_repository.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

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
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getTotalForPeriod(params.institutionId, from: params.from, to: params.to);
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

/// Провайдер суммы оплат за сегодня
final todayPaymentsTotalProvider =
    FutureProvider.family<double, String>((ref, institutionId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return repo.getTotalForPeriod(institutionId, from: startOfDay, to: endOfDay);
});

/// Контроллер оплат
class PaymentController extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repo;
  final Ref _ref;

  PaymentController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<Payment?> create({
    required String institutionId,
    required String studentId,
    String? paymentPlanId,
    required double amount,
    required int lessonsCount,
    DateTime? paidAt,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payment = await _repo.create(
        institutionId: institutionId,
        studentId: studentId,
        paymentPlanId: paymentPlanId,
        amount: amount,
        lessonsCount: lessonsCount,
        paidAt: paidAt,
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

  Future<Payment?> createCorrection({
    required String institutionId,
    required String studentId,
    required double amount,
    required int lessonsCount,
    required String reason,
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

  Future<PaymentPlan?> createPlan({
    required String institutionId,
    required String name,
    required double price,
    required int lessonsCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final plan = await _repo.createPlan(
        institutionId: institutionId,
        name: name,
        price: price,
        lessonsCount: lessonsCount,
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
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updatePlan(id, name: name, price: price, lessonsCount: lessonsCount);
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
}

/// Провайдер контроллера оплат
final paymentControllerProvider =
    StateNotifierProvider<PaymentController, AsyncValue<void>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  return PaymentController(repo, ref);
});
