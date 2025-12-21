import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Провайдер репозитория занятий
final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository();
});

/// Параметры для загрузки занятий по кабинету
class RoomDateParams {
  final String roomId;
  final DateTime date;

  RoomDateParams(this.roomId, this.date);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomDateParams &&
        other.roomId == roomId &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => Object.hash(roomId, date.year, date.month, date.day);
}

/// Провайдер занятий по кабинету и дате
final lessonsByRoomProvider =
    FutureProvider.family<List<Lesson>, RoomDateParams>((ref, params) async {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.getByRoomAndDate(params.roomId, params.date);
});

/// Стрим занятий по кабинету (realtime)
final lessonsStreamProvider =
    StreamProvider.family<List<Lesson>, RoomDateParams>((ref, params) {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.watchByRoom(params.roomId, params.date);
});

/// Провайдер занятия по ID
final lessonProvider = FutureProvider.family<Lesson, String>((ref, id) async {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.getById(id);
});

/// Провайдер моих занятий на сегодня
final myTodayLessonsProvider = FutureProvider<List<Lesson>>((ref) async {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.getMyLessonsForDate(DateTime.now());
});

/// Параметры для загрузки занятий по заведению и дате
class InstitutionDateParams {
  final String institutionId;
  final DateTime date;

  InstitutionDateParams(this.institutionId, this.date);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstitutionDateParams &&
        other.institutionId == institutionId &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => Object.hash(institutionId, date.year, date.month, date.day);
}

/// Провайдер занятий заведения за день (сегодня) - realtime
final institutionTodayLessonsProvider =
    StreamProvider.family<List<Lesson>, String>((ref, institutionId) {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.watchByInstitution(institutionId, DateTime.now());
});

/// Провайдер занятий заведения за указанную дату
final lessonsByInstitutionProvider =
    FutureProvider.family<List<Lesson>, InstitutionDateParams>((ref, params) async {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.getByInstitutionAndDate(params.institutionId, params.date);
});

/// Провайдер выбранной даты
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Провайдер неотмеченных занятий (FutureProvider)
/// Для owner/admin - все занятия, для teacher - только его
final unmarkedLessonsProvider =
    FutureProvider.family<List<Lesson>, String>((ref, institutionId) async {
  final repo = ref.watch(lessonRepositoryProvider);
  final membership = await ref.watch(myMembershipProvider(institutionId).future);
  final userId = ref.watch(currentUserIdProvider);

  if (membership == null || userId == null) {
    return [];
  }

  // Owner и admin видят все занятия
  // roleName может быть на русском или английском
  final role = membership.roleName.toLowerCase();
  final isAdminOrOwner = role == 'owner' ||
      role == 'admin' ||
      role == 'владелец' ||
      role == 'администратор';

  return repo.getUnmarkedLessons(
    institutionId: institutionId,
    isAdminOrOwner: isAdminOrOwner,
    teacherId: userId,
  );
});

/// Провайдер неотмеченных занятий (StreamProvider - realtime)
/// Для owner/admin - все занятия, для teacher - только его
final unmarkedLessonsStreamProvider =
    StreamProvider.family<List<Lesson>, String>((ref, institutionId) async* {
  final repo = ref.watch(lessonRepositoryProvider);
  final membership = await ref.watch(myMembershipProvider(institutionId).future);
  final userId = ref.watch(currentUserIdProvider);

  if (membership == null || userId == null) {
    yield [];
    return;
  }

  // Owner и admin видят все занятия
  final role = membership.roleName.toLowerCase();
  final isAdminOrOwner = role == 'owner' ||
      role == 'admin' ||
      role == 'владелец' ||
      role == 'администратор';

  yield* repo.watchUnmarkedLessons(
    institutionId: institutionId,
    isAdminOrOwner: isAdminOrOwner,
    teacherId: userId,
  );
});

/// Контроллер занятий
class LessonController extends StateNotifier<AsyncValue<void>> {
  final LessonRepository _repo;
  final Ref _ref;

  LessonController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<Lesson?> create({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Проверка конфликта времени
      final hasConflict = await _repo.hasTimeConflict(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasConflict) {
        throw Exception('Кабинет занят в это время');
      }

      final lesson = await _repo.create(
        institutionId: institutionId,
        roomId: roomId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        studentId: studentId,
        groupId: groupId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        comment: comment,
      );

      _invalidateForRoom(roomId, date);
      state = const AsyncValue.data(null);
      return lesson;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> update(
    String id, {
    required String roomId,
    required DateTime date,
    String? newRoomId,
    DateTime? newDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? comment,
    LessonStatus? status,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Проверка конфликта при изменении времени
      if (startTime != null && endTime != null) {
        final hasConflict = await _repo.hasTimeConflict(
          roomId: newRoomId ?? roomId,
          date: newDate ?? date,
          startTime: startTime,
          endTime: endTime,
          excludeLessonId: id,
        );

        if (hasConflict) {
          throw Exception('Кабинет занят в это время');
        }
      }

      await _repo.update(
        id,
        roomId: newRoomId,
        date: newDate,
        startTime: startTime,
        endTime: endTime,
        comment: comment,
      );

      if (status != null) {
        await _repo.updateStatus(id, status);
      }

      _invalidateForRoom(roomId, date);
      if (newRoomId != null || newDate != null) {
        _invalidateForRoom(newRoomId ?? roomId, newDate ?? date);
      }
      _ref.invalidate(lessonProvider(id));

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> complete(String id, String roomId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.complete(id);
      _invalidateForRoom(roomId, date);
      _ref.invalidate(lessonProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> uncomplete(String id, String roomId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.uncomplete(id);
      _invalidateForRoom(roomId, date);
      _ref.invalidate(lessonProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> cancel(String id, String roomId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.cancel(id);
      _invalidateForRoom(roomId, date);
      _ref.invalidate(lessonProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archive(String id, String roomId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _invalidateForRoom(roomId, date);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id, String roomId, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidateForRoom(roomId, date);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void _invalidateForRoom(String roomId, DateTime date) {
    _ref.invalidate(lessonsByRoomProvider(RoomDateParams(roomId, date)));
  }
}

/// Провайдер контроллера занятий
final lessonControllerProvider =
    StateNotifierProvider<LessonController, AsyncValue<void>>((ref) {
  final repo = ref.watch(lessonRepositoryProvider);
  return LessonController(repo, ref);
});
