import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/subscriptions/repositories/subscription_repository.dart';
import 'package:kabinet/shared/models/subscription.dart';

/// Провайдер репозитория подписок
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

/// Провайдер подписок студента (только личные)
final studentSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, String>((ref, studentId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getByStudent(studentId);
});

/// Провайдер всех подписок студента (личные + семейные)
final studentAllSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, String>((ref, studentId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getByStudentIncludingFamily(studentId);
});

/// Провайдер активных подписок студента
final activeSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, String>((ref, studentId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getActiveByStudent(studentId);
});

/// Стрим подписок студента (realtime, только личные)
final subscriptionsStreamProvider =
    StreamProvider.family<List<Subscription>, String>((ref, studentId) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchByStudent(studentId);
});

/// Стрим всех подписок студента (личные + семейные, realtime)
final allSubscriptionsStreamProvider =
    StreamProvider.family<List<Subscription>, String>((ref, studentId) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchByStudentIncludingFamily(studentId);
});

/// Провайдер активного баланса студента
final studentActiveBalanceProvider =
    FutureProvider.family<int, String>((ref, studentId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getActiveBalance(studentId);
});

/// Провайдер проверки заморозки
final isStudentFrozenProvider =
    FutureProvider.family<bool, String>((ref, studentId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.isFrozen(studentId);
});

/// Параметры для истекающих подписок
class ExpiringSubscriptionsParams {
  final String institutionId;
  final int days;

  ExpiringSubscriptionsParams(this.institutionId, {this.days = 7});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpiringSubscriptionsParams &&
          other.institutionId == institutionId &&
          other.days == days;

  @override
  int get hashCode => Object.hash(institutionId, days);
}

/// Провайдер истекающих подписок заведения
final expiringSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, ExpiringSubscriptionsParams>(
        (ref, params) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getExpiringSoon(params.institutionId, days: params.days);
});

/// Провайдер замороженных подписок заведения
final frozenSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, String>((ref, institutionId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getFrozen(institutionId);
});

/// Контроллер подписок
class SubscriptionController extends StateNotifier<AsyncValue<void>> {
  final SubscriptionRepository _repo;
  final Ref _ref;

  SubscriptionController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Создать подписку
  Future<Subscription?> create({
    required String institutionId,
    required String studentId,
    String? paymentId,
    required int lessonsTotal,
    required DateTime expiresAt,
    DateTime? startsAt,
  }) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.create(
        institutionId: institutionId,
        studentId: studentId,
        paymentId: paymentId,
        lessonsTotal: lessonsTotal,
        expiresAt: expiresAt,
        startsAt: startsAt,
      );

      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Заморозить подписку
  Future<Subscription?> freeze(String subscriptionId, String studentId, int days) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.freeze(subscriptionId, days);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Разморозить подписку
  Future<Subscription?> unfreeze(String subscriptionId, String studentId) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.unfreeze(subscriptionId);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Продлить подписку
  Future<Subscription?> extend(String subscriptionId, String studentId, int days) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.extend(subscriptionId, days);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Списать занятие
  Future<Subscription?> deductLesson(String studentId) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.deductLesson(studentId);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Вернуть занятие
  Future<Subscription?> returnLesson(String studentId, {String? subscriptionId}) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.returnLesson(studentId, subscriptionId: subscriptionId);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Удалить подписку
  Future<bool> delete(String subscriptionId, String studentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(subscriptionId);
      _invalidateForStudent(studentId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Создать семейный абонемент
  Future<Subscription?> createFamily({
    required String institutionId,
    required List<String> studentIds,
    String? paymentId,
    required int lessonsTotal,
    required DateTime expiresAt,
    DateTime? startsAt,
  }) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _repo.createFamily(
        institutionId: institutionId,
        studentIds: studentIds,
        paymentId: paymentId,
        lessonsTotal: lessonsTotal,
        expiresAt: expiresAt,
        startsAt: startsAt,
      );

      // Инвалидируем провайдеры для всех участников
      _invalidateForStudents(studentIds);
      state = const AsyncValue.data(null);
      return subscription;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Добавить участника в семейный абонемент
  Future<bool> addMember(
    String subscriptionId,
    String studentId,
    List<String> allMemberIds,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addFamilyMember(subscriptionId, studentId);
      // Инвалидируем провайдеры для всех участников + нового
      _invalidateForStudents([...allMemberIds, studentId]);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить участника из семейного абонемента
  Future<bool> removeMember(
    String subscriptionId,
    String studentId,
    List<String> allMemberIds,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeFamilyMember(subscriptionId, studentId);
      // Инвалидируем провайдеры для всех участников (включая удалённого)
      _invalidateForStudents(allMemberIds);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void _invalidateForStudent(String studentId) {
    _ref.invalidate(studentSubscriptionsProvider(studentId));
    _ref.invalidate(studentAllSubscriptionsProvider(studentId));
    _ref.invalidate(activeSubscriptionsProvider(studentId));
    _ref.invalidate(studentActiveBalanceProvider(studentId));
    _ref.invalidate(isStudentFrozenProvider(studentId));
    // Также инвалидируем StreamProvider для принудительного обновления
    _ref.invalidate(subscriptionsStreamProvider(studentId));
  }

  /// Инвалидировать провайдеры для нескольких студентов (для семейных абонементов)
  void _invalidateForStudents(List<String> studentIds) {
    for (final studentId in studentIds) {
      _invalidateForStudent(studentId);
    }
  }
}

/// Провайдер контроллера подписок
final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, AsyncValue<void>>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return SubscriptionController(repo, ref);
});
