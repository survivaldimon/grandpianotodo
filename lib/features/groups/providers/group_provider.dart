import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/groups/repositories/group_repository.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Провайдер репозитория групп
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// Провайдер списка групп заведения
final groupsProvider =
    FutureProvider.family<List<StudentGroup>, String>((ref, institutionId) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getByInstitution(institutionId);
});

/// Провайдер группы по ID
final groupProvider =
    FutureProvider.family<StudentGroup, String>((ref, id) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер групп
class GroupController extends StateNotifier<AsyncValue<void>> {
  final GroupRepository _repo;
  final Ref _ref;

  GroupController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<StudentGroup?> create({
    required String institutionId,
    required String name,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final group = await _repo.create(
        institutionId: institutionId,
        name: name,
        comment: comment,
      );
      _ref.invalidate(groupsProvider(institutionId));
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> update(
    String id, {
    required String institutionId,
    String? name,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(id, name: name, comment: comment);
      _ref.invalidate(groupsProvider(institutionId));
      _ref.invalidate(groupProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archive(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _ref.invalidate(groupsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> addMember(String groupId, String studentId, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addMember(groupId, studentId);
      _ref.invalidate(groupProvider(groupId));
      _ref.invalidate(groupsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeMember(String groupId, String studentId, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeMember(groupId, studentId);
      _ref.invalidate(groupProvider(groupId));
      _ref.invalidate(groupsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера групп
final groupControllerProvider =
    StateNotifierProvider<GroupController, AsyncValue<void>>((ref) {
  final repo = ref.watch(groupRepositoryProvider);
  return GroupController(repo, ref);
});
