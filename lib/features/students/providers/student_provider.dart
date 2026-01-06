import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/features/students/repositories/student_repository.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Провайдер репозитория учеников
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

/// Провайдер списка учеников заведения (realtime)
final studentsProvider =
    StreamProvider.family<List<Student>, String>((ref, institutionId) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.watchByInstitution(institutionId).map(
        (students) => students.where((s) => s.archivedAt == null).toList(),
      );
});

/// Провайдер учеников с долгом (realtime)
final studentsWithDebtProvider =
    StreamProvider.family<List<Student>, String>((ref, institutionId) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.watchByInstitution(institutionId).map(
        (students) => students
            .where((s) => s.archivedAt == null && s.balance < 0)
            .toList(),
      );
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
enum StudentFilter { all, withDebt, archived, myStudents }

/// Состояние фильтра учеников
final studentFilterProvider = StateProvider<StudentFilter>((ref) {
  return StudentFilter.all;
});

/// Параметры фильтрации учеников
class StudentFilterParams {
  final String institutionId;
  final bool onlyMyStudents;

  const StudentFilterParams({
    required this.institutionId,
    this.onlyMyStudents = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentFilterParams &&
          institutionId == other.institutionId &&
          onlyMyStudents == other.onlyMyStudents;

  @override
  int get hashCode => institutionId.hashCode ^ onlyMyStudents.hashCode;
}

/// Провайдер отфильтрованных учеников (realtime)
/// Если onlyMyStudents = true, показывает только учеников привязанных к текущему пользователю
final filteredStudentsProvider =
    StreamProvider.family<List<Student>, StudentFilterParams>((ref, params) async* {
  final repo = ref.watch(studentRepositoryProvider);
  final filter = ref.watch(studentFilterProvider);
  final institutionId = params.institutionId;

  // Получаем ID учеников текущего пользователя если нужна фильтрация
  Set<String>? myStudentIds;
  if (params.onlyMyStudents || filter == StudentFilter.myStudents) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    if (currentUserId != null) {
      final bindingsRepo = ref.read(studentBindingsRepositoryProvider);
      final ids = await bindingsRepo.getTeacherStudentIds(
        currentUserId,
        institutionId,
      );
      myStudentIds = ids.toSet();
    }
  }

  await for (final students in repo.watchByInstitution(institutionId)) {
    List<Student> filtered;

    switch (filter) {
      case StudentFilter.all:
        filtered = students.where((s) => s.archivedAt == null).toList();
      case StudentFilter.withDebt:
        filtered = students
            .where((s) => s.archivedAt == null && s.balance < 0)
            .toList();
      case StudentFilter.archived:
        filtered = students.where((s) => s.archivedAt != null).toList();
      case StudentFilter.myStudents:
        filtered = students
            .where((s) =>
                s.archivedAt == null &&
                myStudentIds != null &&
                myStudentIds.contains(s.id))
            .toList();
    }

    // Если onlyMyStudents = true, дополнительно фильтруем по привязке
    if (params.onlyMyStudents && myStudentIds != null) {
      filtered = filtered.where((s) => myStudentIds!.contains(s.id)).toList();
    }

    yield filtered;
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
    int legacyBalance = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final student = await _repo.create(
        institutionId: institutionId,
        name: name,
        phone: phone,
        comment: comment,
        legacyBalance: legacyBalance,
      );

      // Автоматически привязываем созданного ученика к текущему пользователю
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final bindingsController = _ref.read(studentBindingsControllerProvider.notifier);
        await bindingsController.addTeacher(
          studentId: student.id,
          userId: currentUserId,
          institutionId: institutionId,
        );
        // Инвалидируем кэш своих учеников
        _ref.invalidate(myStudentIdsProvider(institutionId));
      }

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
    int? legacyBalance,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(id, name: name, phone: phone, comment: comment, legacyBalance: legacyBalance);
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
      _ref.invalidate(studentProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> restore(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.restore(id);
      _ref.invalidate(studentsProvider(institutionId));
      _ref.invalidate(studentProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Полностью удалить ученика и все его данные
  /// ВАЖНО: Удаляет ВСЁ - занятия, оплаты, подписки. НЕОБРАТИМО!
  Future<bool> deleteCompletely(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCompletely(id);
      // Инвалидируем все связанные провайдеры
      _ref.invalidate(studentsProvider(institutionId));
      _ref.invalidate(studentProvider(id));
      // Инвалидируем расписание (т.к. занятия удаляются)
      _ref.invalidate(lessonsByInstitutionStreamProvider);
      // Инвалидируем оплаты
      _ref.invalidate(paymentsStreamProvider(institutionId));
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

  /// Объединить несколько учеников в одного нового
  /// Создаёт новую карточку, переносит все данные, архивирует исходных
  Future<Student?> mergeStudents({
    required List<String> sourceIds,
    required String institutionId,
    required String newName,
    String? newPhone,
    String? newComment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final student = await _repo.mergeStudents(
        sourceIds: sourceIds,
        institutionId: institutionId,
        newName: newName,
        newPhone: newPhone,
        newComment: newComment,
      );

      // Инвалидируем всё что связано с учениками
      _ref.invalidate(studentsProvider(institutionId));
      _ref.invalidate(studentGroupsProvider(institutionId));
      for (final id in sourceIds) {
        _ref.invalidate(studentProvider(id));
      }
      _ref.invalidate(studentProvider(student.id));

      state = const AsyncValue.data(null);
      return student;
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

/// Параметры для проверки "своего" ученика
class IsMyStudentParams {
  final String studentId;
  final String institutionId;

  const IsMyStudentParams(this.studentId, this.institutionId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IsMyStudentParams &&
          studentId == other.studentId &&
          institutionId == other.institutionId;

  @override
  int get hashCode => studentId.hashCode ^ institutionId.hashCode;
}

/// Провайдер для проверки, является ли ученик "своим" (привязан к текущему пользователю)
final isMyStudentProvider =
    FutureProvider.family<bool, IsMyStudentParams>((ref, params) async {
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId == null) return false;

  final bindingsRepo = ref.read(studentBindingsRepositoryProvider);
  final myStudentIds = await bindingsRepo.getTeacherStudentIds(
    currentUserId,
    params.institutionId,
  );

  return myStudentIds.contains(params.studentId);
});

/// Провайдер учеников для добавления оплаты (фильтрует по правам)
/// Возвращает только своих учеников, если нет права addPaymentsForAllStudents
final studentsForPaymentProvider =
    FutureProvider.family<List<Student>, String>((ref, institutionId) async {
  final repo = ref.watch(studentRepositoryProvider);
  final allStudents = await repo.getByInstitution(institutionId);
  final activeStudents = allStudents.where((s) => s.archivedAt == null).toList();

  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId == null) return [];

  // Получаем права текущего пользователя
  final bindingsRepo = ref.read(studentBindingsRepositoryProvider);
  final myStudentIds = await bindingsRepo.getTeacherStudentIds(
    currentUserId,
    institutionId,
  );

  // Фильтруем только своих учеников
  return activeStudents.where((s) => myStudentIds.contains(s.id)).toList();
});

/// Провайдер ID своих учеников (для фильтрации оплат)
final myStudentIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, institutionId) async {
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId == null) return {};

  final bindingsRepo = ref.read(studentBindingsRepositoryProvider);
  final ids = await bindingsRepo.getTeacherStudentIds(
    currentUserId,
    institutionId,
  );

  return ids.toSet();
});

/// Провайдер имён учеников по списку ID
/// Используется для отображения объединённых учеников как chips
final mergedStudentNamesProvider =
    FutureProvider.family<List<String>, List<String>>((ref, ids) async {
  if (ids.isEmpty) return [];
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getNamesByIds(ids);
});
