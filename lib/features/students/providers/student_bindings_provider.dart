import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/students/repositories/student_bindings_repository.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/student_teacher.dart';
import 'package:kabinet/shared/models/student_subject.dart';

/// Провайдер репозитория привязок
final studentBindingsRepositoryProvider =
    Provider<StudentBindingsRepository>((ref) {
  return StudentBindingsRepository();
});

/// Провайдер преподавателей ученика
final studentTeachersProvider =
    FutureProvider.family<List<StudentTeacher>, String>((ref, studentId) async {
  final repo = ref.watch(studentBindingsRepositoryProvider);
  return repo.getStudentTeachers(studentId);
});

/// Провайдер предметов ученика
final studentSubjectsProvider =
    FutureProvider.family<List<StudentSubject>, String>((ref, studentId) async {
  final repo = ref.watch(studentBindingsRepositoryProvider);
  return repo.getStudentSubjects(studentId);
});

/// Провайдер последнего занятия ученика (для автозаполнения)
final studentLastLessonProvider =
    FutureProvider.family<Lesson?, String>((ref, studentId) async {
  if (studentId.isEmpty) return null;
  final repo = ref.watch(studentBindingsRepositoryProvider);
  return repo.getStudentLastLesson(studentId);
});

/// Параметры для получения ID учеников преподавателя
class TeacherStudentsParams {
  final String userId;
  final String institutionId;

  const TeacherStudentsParams(this.userId, this.institutionId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherStudentsParams &&
          userId == other.userId &&
          institutionId == other.institutionId;

  @override
  int get hashCode => userId.hashCode ^ institutionId.hashCode;
}

/// Провайдер ID учеников преподавателя (для фильтра "Мои ученики")
final teacherStudentIdsProvider =
    FutureProvider.family<List<String>, TeacherStudentsParams>(
        (ref, params) async {
  final repo = ref.watch(studentBindingsRepositoryProvider);
  return repo.getTeacherStudentIds(params.userId, params.institutionId);
});

/// Контроллер для управления привязками
class StudentBindingsController extends StateNotifier<AsyncValue<void>> {
  final StudentBindingsRepository _repo;
  final Ref _ref;

  StudentBindingsController(this._repo, this._ref)
      : super(const AsyncValue.data(null));

  /// Добавить преподавателя к ученику
  Future<bool> addTeacher({
    required String studentId,
    required String userId,
    required String institutionId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addStudentTeacher(
        studentId: studentId,
        userId: userId,
        institutionId: institutionId,
      );
      _ref.invalidate(studentTeachersProvider(studentId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить преподавателя от ученика
  Future<bool> removeTeacher(String studentId, String userId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeStudentTeacher(studentId, userId);
      _ref.invalidate(studentTeachersProvider(studentId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Добавить предмет к ученику
  Future<bool> addSubject({
    required String studentId,
    required String subjectId,
    required String institutionId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addStudentSubject(
        studentId: studentId,
        subjectId: subjectId,
        institutionId: institutionId,
      );
      _ref.invalidate(studentSubjectsProvider(studentId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить предмет от ученика
  Future<bool> removeSubject(String studentId, String subjectId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeStudentSubject(studentId, subjectId);
      _ref.invalidate(studentSubjectsProvider(studentId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Автоматически создать привязки при создании занятия
  /// Не блокирует и не выбрасывает ошибки
  Future<void> createBindingsFromLesson({
    required String studentId,
    required String teacherId,
    String? subjectId,
    required String institutionId,
  }) async {
    await _repo.createBindingsFromLesson(
      studentId: studentId,
      teacherId: teacherId,
      subjectId: subjectId,
      institutionId: institutionId,
    );
    // Инвалидируем кеш для обновления данных
    _ref.invalidate(studentTeachersProvider(studentId));
    if (subjectId != null) {
      _ref.invalidate(studentSubjectsProvider(studentId));
    }
  }
}

/// Провайдер контроллера привязок
final studentBindingsControllerProvider =
    StateNotifierProvider<StudentBindingsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(studentBindingsRepositoryProvider);
  return StudentBindingsController(repo, ref);
});
