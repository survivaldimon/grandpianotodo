import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/lesson_types/repositories/lesson_type_repository.dart';
import 'package:kabinet/shared/models/lesson_type.dart';

/// Провайдер репозитория типов занятий
final lessonTypeRepositoryProvider = Provider<LessonTypeRepository>((ref) {
  return LessonTypeRepository();
});

/// Провайдер списка типов занятий
final lessonTypesProvider =
    FutureProvider.family<List<LessonType>, String>((ref, institutionId) async {
  final repo = ref.watch(lessonTypeRepositoryProvider);
  return repo.getByInstitution(institutionId);
});

/// Провайдер одного типа занятия
final lessonTypeProvider =
    FutureProvider.family<LessonType?, String>((ref, id) async {
  final repo = ref.watch(lessonTypeRepositoryProvider);
  return repo.getById(id);
});

/// Контроллер типов занятий
class LessonTypeController extends StateNotifier<AsyncValue<void>> {
  final LessonTypeRepository _repo;
  final Ref _ref;

  LessonTypeController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Создать тип занятия
  Future<LessonType?> create({
    required String institutionId,
    required String name,
    int defaultDurationMinutes = 60,
    double? defaultPrice,
    bool isGroup = false,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      final lessonType = await _repo.create(
        institutionId: institutionId,
        name: name,
        defaultDurationMinutes: defaultDurationMinutes,
        defaultPrice: defaultPrice,
        isGroup: isGroup,
        color: color,
      );
      await _repo.invalidateCache(institutionId);
      _ref.invalidate(lessonTypesProvider(institutionId));
      state = const AsyncValue.data(null);
      return lessonType;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Обновить тип занятия
  Future<bool> update({
    required String id,
    required String institutionId,
    String? name,
    int? defaultDurationMinutes,
    double? defaultPrice,
    bool? isGroup,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(
        id: id,
        name: name,
        defaultDurationMinutes: defaultDurationMinutes,
        defaultPrice: defaultPrice,
        isGroup: isGroup,
        color: color,
      );
      await _repo.invalidateCache(institutionId);
      _ref.invalidate(lessonTypesProvider(institutionId));
      _ref.invalidate(lessonTypeProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Архивировать тип занятия
  Future<bool> archive(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      await _repo.invalidateCache(institutionId);
      _ref.invalidate(lessonTypesProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить тип занятия
  Future<bool> delete(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      await _repo.invalidateCache(institutionId);
      _ref.invalidate(lessonTypesProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера типов занятий
final lessonTypeControllerProvider =
    StateNotifierProvider<LessonTypeController, AsyncValue<void>>((ref) {
  final repo = ref.watch(lessonTypeRepositoryProvider);
  return LessonTypeController(repo, ref);
});
