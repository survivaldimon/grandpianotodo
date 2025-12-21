import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/payment_plans/repositories/payment_plan_repository.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

/// Провайдер репозитория тарифов
final paymentPlanRepositoryProvider = Provider<PaymentPlanRepository>((ref) {
  return PaymentPlanRepository();
});

/// Провайдер списка тарифов
final paymentPlansProvider =
    FutureProvider.family<List<PaymentPlan>, String>((ref, institutionId) async {
  final repo = ref.watch(paymentPlanRepositoryProvider);
  return repo.getByInstitution(institutionId);
});

/// Провайдер одного тарифа
final paymentPlanProvider =
    FutureProvider.family<PaymentPlan?, String>((ref, id) async {
  final repo = ref.watch(paymentPlanRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер тарифов
class PaymentPlanController extends StateNotifier<AsyncValue<void>> {
  final PaymentPlanRepository _repo;
  final Ref _ref;

  PaymentPlanController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Создать тариф
  Future<PaymentPlan?> create({
    required String institutionId,
    required String name,
    required double price,
    required int lessonsCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final plan = await _repo.create(
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

  /// Обновить тариф
  Future<bool> update({
    required String id,
    required String institutionId,
    String? name,
    double? price,
    int? lessonsCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(
        id: id,
        name: name,
        price: price,
        lessonsCount: lessonsCount,
      );
      _ref.invalidate(paymentPlansProvider(institutionId));
      _ref.invalidate(paymentPlanProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Архивировать тариф
  Future<bool> archive(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _ref.invalidate(paymentPlansProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить тариф
  Future<bool> delete(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _ref.invalidate(paymentPlansProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера тарифов
final paymentPlanControllerProvider =
    StateNotifierProvider<PaymentPlanController, AsyncValue<void>>((ref) {
  final repo = ref.watch(paymentPlanRepositoryProvider);
  return PaymentPlanController(repo, ref);
});
