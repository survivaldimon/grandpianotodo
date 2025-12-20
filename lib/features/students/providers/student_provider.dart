import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/students/repositories/student_repository.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Провайдер репозитория учеников
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

/// Провайдер списка учеников заведения
final studentsProvider =
    FutureProvider.family<List<Student>, String>((ref, institutionId) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getByInstitution(institutionId);
});

/// Провайдер учеников с долгом
final studentsWithDebtProvider =
    FutureProvider.family<List<Student>, String>((ref, institutionId) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getByInstitution(institutionId, onlyWithDebt: true);
});

/// Провайдер ученика по ID
final studentProvider = FutureProvider.family<Student, String>((ref, id) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getById(id);
});

/// Стрим учеников (realtime)
final studentsStreamProvider =
    StreamProvider.family<List<Student>, String>((ref, institutionId) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Провайдер групп заведения
final studentGroupsProvider =
    FutureProvider.family<List<StudentGroup>, String>((ref, institutionId) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getGroups(institutionId);
});

/// Фильтр учеников
enum StudentFilter { all, withDebt, archived }

/// Состояние фильтра учеников
final studentFilterProvider = StateProvider<StudentFilter>((ref) {
  return StudentFilter.all;
});

/// Провайдер отфильтрованных учеников
final filteredStudentsProvider =
    FutureProvider.family<List<Student>, String>((ref, institutionId) async {
  final repo = ref.watch(studentRepositoryProvider);
  final filter = ref.watch(studentFilterProvider);

  switch (filter) {
    case StudentFilter.all:
      return repo.getByInstitution(institutionId);
    case StudentFilter.withDebt:
      return repo.getByInstitution(institutionId, onlyWithDebt: true);
    case StudentFilter.archived:
      return repo.getByInstitution(institutionId, includeArchived: true);
  }
});

/// Контроллер учеников
class StudentController extends StateNotifier<AsyncValue<void>> {
  final StudentRepository _repo;
  final Ref _ref;

  StudentController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<Student?> create({
    required String institutionId,
    required String name,
    String? phone,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final student = await _repo.create(
        institutionId: institutionId,
        name: name,
        phone: phone,
        comment: comment,
      );
      _ref.invalidate(studentsProvider(institutionId));
      state = const AsyncValue.data(null);
      return student;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> update(
    String id, {
    required String institutionId,
    String? name,
    String? phone,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(id, name: name, phone: phone, comment: comment);
      _ref.invalidate(studentsProvider(institutionId));
      _ref.invalidate(studentProvider(id));
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
      _ref.invalidate(studentsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<StudentGroup?> createGroup({
    required String institutionId,
    required String name,
    String? comment,
    List<String>? studentIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      final group = await _repo.createGroup(
        institutionId: institutionId,
        name: name,
        comment: comment,
        studentIds: studentIds,
      );
      _ref.invalidate(studentGroupsProvider(institutionId));
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

/// Провайдер контроллера учеников
final studentControllerProvider =
    StateNotifierProvider<StudentController, AsyncValue<void>>((ref) {
  final repo = ref.watch(studentRepositoryProvider);
  return StudentController(repo, ref);
});
