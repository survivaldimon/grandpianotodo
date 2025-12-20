import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/institution/repositories/institution_repository.dart';
import 'package:kabinet/shared/models/institution.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Провайдер репозитория заведений
final institutionRepositoryProvider = Provider<InstitutionRepository>((ref) {
  return InstitutionRepository();
});

/// Провайдер списка заведений пользователя
final myInstitutionsProvider = FutureProvider<List<Institution>>((ref) async {
  final repo = ref.watch(institutionRepositoryProvider);
  return repo.getMyInstitutions();
});

/// Провайдер архивированных заведений пользователя
final archivedInstitutionsProvider = FutureProvider<List<Institution>>((ref) async {
  final repo = ref.watch(institutionRepositoryProvider);
  return repo.getArchivedInstitutions();
});

/// Провайдер текущего заведения
final currentInstitutionProvider =
    FutureProvider.family<Institution, String>((ref, id) async {
  final repo = ref.watch(institutionRepositoryProvider);
  return repo.getById(id);
});

/// Провайдер участников заведения
final institutionMembersProvider =
    FutureProvider.family<List<InstitutionMember>, String>((ref, institutionId) async {
  final repo = ref.watch(institutionRepositoryProvider);
  return repo.getMembers(institutionId);
});

/// Провайдер текущего членства пользователя
final myMembershipProvider =
    FutureProvider.family<InstitutionMember?, String>((ref, institutionId) async {
  final repo = ref.watch(institutionRepositoryProvider);
  return repo.getMyMembership(institutionId);
});

/// Провайдер прав пользователя в заведении
final myPermissionsProvider =
    FutureProvider.family<MemberPermissions?, String>((ref, institutionId) async {
  final membership = await ref.watch(myMembershipProvider(institutionId).future);
  return membership?.permissions;
});

/// Контроллер заведений
class InstitutionController extends StateNotifier<AsyncValue<void>> {
  final InstitutionRepository _repo;
  final Ref _ref;

  InstitutionController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<Institution?> create(String name) async {
    state = const AsyncValue.loading();
    try {
      final institution = await _repo.create(name);
      _ref.invalidate(myInstitutionsProvider);
      state = const AsyncValue.data(null);
      return institution;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Institution?> joinByCode(String code) async {
    state = const AsyncValue.loading();
    try {
      final institution = await _repo.joinByCode(code);
      _ref.invalidate(myInstitutionsProvider);
      state = const AsyncValue.data(null);
      return institution;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> update(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(id, name: name);
      _ref.invalidate(myInstitutionsProvider);
      _ref.invalidate(currentInstitutionProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archive(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _ref.invalidate(myInstitutionsProvider);
      _ref.invalidate(archivedInstitutionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> leave(String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.leave(institutionId);
      _ref.invalidate(myInstitutionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> restore(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.restore(id);
      _ref.invalidate(myInstitutionsProvider);
      _ref.invalidate(archivedInstitutionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера заведений
final institutionControllerProvider =
    StateNotifierProvider<InstitutionController, AsyncValue<void>>((ref) {
  final repo = ref.watch(institutionRepositoryProvider);
  return InstitutionController(repo, ref);
});
