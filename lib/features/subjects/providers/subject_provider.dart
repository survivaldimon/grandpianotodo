import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/subjects/repositories/subject_repository.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Провайдер репозитория предметов
final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository();
});

/// Провайдер списка предметов
final subjectsListProvider =
    FutureProvider.family<List<Subject>, String>((ref, institutionId) async {
  final repo = ref.watch(subjectRepositoryProvider);
  return repo.getByInstitution(institutionId);
});

/// Провайдер одного предмета
final subjectProvider =
    FutureProvider.family<Subject?, String>((ref, id) async {
  final repo = ref.watch(subjectRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер предметов
class SubjectController extends StateNotifier<AsyncValue<void>> {
  final SubjectRepository _repo;
  final Ref _ref;

  SubjectController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Создать предмет
  Future<Subject?> create({
    required String institutionId,
    required String name,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      final subject = await _repo.create(
        institutionId: institutionId,
        name: name,
        color: color,
      );
      _ref.invalidate(subjectsListProvider(institutionId));
      state = const AsyncValue.data(null);
      return subject;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Обновить предмет
  Future<bool> update({
    required String id,
    required String institutionId,
    String? name,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(
        id: id,
        name: name,
        color: color,
      );
      _ref.invalidate(subjectsListProvider(institutionId));
      _ref.invalidate(subjectProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Архивировать предмет
  Future<bool> archive(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _ref.invalidate(subjectsListProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить предмет
  Future<bool> delete(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _ref.invalidate(subjectsListProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера предметов
final subjectControllerProvider =
    StateNotifierProvider<SubjectController, AsyncValue<void>>((ref) {
  final repo = ref.watch(subjectRepositoryProvider);
  return SubjectController(repo, ref);
});
