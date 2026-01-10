import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/schedule/repositories/lesson_repository.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/students/repositories/student_repository.dart';
import 'package:kabinet/features/subscriptions/repositories/subscription_repository.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Провайдер репозитория занятий
final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository();
});

/// Провайдер репозитория подписок (для списания занятий)
final subscriptionRepoProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
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

/// Провайдер занятий заведения за указанную дату (realtime)
final lessonsByInstitutionStreamProvider =
    StreamProvider.family<List<Lesson>, InstitutionDateParams>((ref, params) {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.watchByInstitution(params.institutionId, params.date);
});

/// Параметры для загрузки занятий за неделю
class InstitutionWeekParams {
  final String institutionId;
  final DateTime weekStart; // Понедельник недели

  InstitutionWeekParams(this.institutionId, this.weekStart);

  /// Получить понедельник для указанной даты
  static DateTime getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1 = Пн, 7 = Вс
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  /// Получить все дни недели
  List<DateTime> get weekDays {
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstitutionWeekParams &&
        other.institutionId == institutionId &&
        other.weekStart.year == weekStart.year &&
        other.weekStart.month == weekStart.month &&
        other.weekStart.day == weekStart.day;
  }

  @override
  int get hashCode => Object.hash(institutionId, weekStart.year, weekStart.month, weekStart.day);
}

/// Провайдер занятий заведения за неделю
/// Возвращает Map<DateTime, List<Lesson>> где ключ - дата (начало дня)
final lessonsByInstitutionWeekProvider =
    FutureProvider.family<Map<DateTime, List<Lesson>>, InstitutionWeekParams>((ref, params) async {
  final repo = ref.watch(lessonRepositoryProvider);
  final result = <DateTime, List<Lesson>>{};

  // Загружаем занятия для каждого дня недели
  for (final day in params.weekDays) {
    final lessons = await repo.getByInstitutionAndDate(params.institutionId, day);
    final normalizedDay = DateTime(day.year, day.month, day.day);
    result[normalizedDay] = lessons;
  }

  return result;
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
  final SubscriptionRepository _subscriptionRepo;
  final Ref _ref;

  LessonController(this._repo, this._subscriptionRepo, this._ref) : super(const AsyncValue.data(null));

  /// Получить репозиторий студентов для работы с долгом
  StudentRepository get _studentRepo => _ref.read(studentRepositoryProvider);

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
      // studentId передаётся чтобы исключить слот этого же ученика из проверки
      final hasConflict = await _repo.hasTimeConflict(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        studentId: studentId,
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

      _invalidateForRoom(roomId, date, institutionId: institutionId);
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
    required String institutionId,
    String? newRoomId,
    DateTime? newDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? comment,
    LessonStatus? status,
    String? studentId,
    String? groupId,
    String? subjectId,
    String? lessonTypeId,
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
        studentId: studentId,
        groupId: groupId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
      );

      if (status != null) {
        await _repo.updateStatus(id, status);
      }

      _invalidateForRoom(roomId, date, institutionId: institutionId);
      if (newRoomId != null || newDate != null) {
        _invalidateForRoom(newRoomId ?? roomId, newDate ?? date, institutionId: institutionId);
      }
      _ref.invalidate(lessonProvider(id));

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> complete(String id, String roomId, DateTime date, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      // Получаем занятие, чтобы узнать studentId и участников
      final lesson = await _repo.getById(id);

      // Занятие уже было списано если статус completed ИЛИ cancelled
      // При переключении cancelled → completed НЕ списываем повторно
      final alreadyDeducted = lesson.status == LessonStatus.completed ||
                              lesson.status == LessonStatus.cancelled;

      // Защита от повторного списания: если занятие уже проведено — не списываем
      if (lesson.status == LessonStatus.completed) {
        _invalidateForRoom(roomId, date, institutionId: institutionId);
        _ref.invalidate(lessonProvider(id));
        // Инвалидируем статистику даже при раннем возврате
        if (lesson.studentId != null) {
          _ref.invalidate(studentLessonStatsProvider(lesson.studentId!));
        } else if (lesson.groupId != null && lesson.lessonStudents != null) {
          for (final ls in lesson.lessonStudents!) {
            _ref.invalidate(studentLessonStatsProvider(ls.studentId));
          }
        }
        state = const AsyncValue.data(null);
        return true;
      }

      await _repo.complete(id);

      // Списываем занятие ТОЛЬКО если статус БЫЛ scheduled (ещё не списано)
      // При переключении cancelled → completed уже было списано при cancel()
      if (!alreadyDeducted) {
        // Списываем занятие с абонемента и привязываем к подписке
        // Ошибка списания НЕ должна влиять на успешное изменение статуса
        if (lesson.studentId != null) {
          // Индивидуальное занятие
          try {
            // Приоритет списания: 1) legacy_balance, 2) subscription, 3) долг
            final student = await _studentRepo.getById(lesson.studentId!);

            if (student.legacyBalance > 0) {
              // Списываем из остатка (legacy_balance) в первую очередь
              await _studentRepo.decrementLegacyBalance(lesson.studentId!);
              // subscriptionId остаётся null — не привязано к подписке
            } else {
              // Пробуем списать с подписки
              final subscriptionId = await _subscriptionRepo.deductLessonAndGetId(lesson.studentId!);

              if (subscriptionId != null) {
                // Привязываем занятие к подписке для расчёта стоимости
                await _repo.setSubscriptionId(id, subscriptionId);
              } else {
                // Нет активной подписки — списываем напрямую (уход в долг)
                await _studentRepo.decrementPrepaidCount(lesson.studentId!);
              }
            }
          } catch (e) {
            // Не критичная ошибка - занятие проведено, но подписка/долг не списаны
          }
        } else if (lesson.groupId != null && lesson.lessonStudents != null) {
          // Групповое занятие — списываем у каждого присутствовавшего
          for (final lessonStudent in lesson.lessonStudents!) {
            if (!lessonStudent.attended) continue;

            try {
              // Приоритет списания: 1) legacy_balance, 2) subscription, 3) долг
              final student = await _studentRepo.getById(lessonStudent.studentId);

              if (student.legacyBalance > 0) {
                // Списываем из остатка (legacy_balance) в первую очередь
                await _studentRepo.decrementLegacyBalance(lessonStudent.studentId);
                // subscriptionId остаётся null — не привязано к подписке
              } else {
                final subscriptionId = await _subscriptionRepo.deductLessonAndGetId(lessonStudent.studentId);

                if (subscriptionId != null) {
                  // Сохраняем subscription_id в lesson_students для корректного возврата
                  await _repo.setLessonStudentSubscriptionId(
                    id,
                    lessonStudent.studentId,
                    subscriptionId,
                  );
                } else {
                  // Нет активной подписки — списываем напрямую (уход в долг)
                  await _studentRepo.decrementPrepaidCount(lessonStudent.studentId);
                }
              }
            } catch (e) {
              // Пропускаем ошибку для конкретного студента
            }
          }
          // Инвалидируем группы для обновления баланса в меню
          _ref.invalidate(studentGroupsProvider(institutionId));
        }
      }

      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(id));
      // Гибридный Realtime: обновляем список учеников для актуального баланса
      _ref.invalidate(studentsProvider(institutionId));

      // Инвалидируем статистику занятий ученика (проведено/отменено)
      if (lesson.studentId != null) {
        _ref.invalidate(studentLessonStatsProvider(lesson.studentId!));
      } else if (lesson.groupId != null && lesson.lessonStudents != null) {
        for (final ls in lesson.lessonStudents!) {
          _ref.invalidate(studentLessonStatsProvider(ls.studentId));
        }
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> uncomplete(String id, String roomId, DateTime date, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      // Получаем занятие, чтобы узнать studentId, subscriptionId и участников
      final lesson = await _repo.getById(id);

      // Если уже scheduled — ничего не делаем
      if (lesson.status == LessonStatus.scheduled) {
        _invalidateForRoom(roomId, date, institutionId: institutionId);
        _ref.invalidate(lessonProvider(id));
        state = const AsyncValue.data(null);
        return true;
      }

      // Было cancelled или completed — меняем статус И возвращаем занятие на абонемент
      await _repo.uncomplete(id);

      // Возвращаем занятие на абонемент или уменьшаем долг
      // Ошибка возврата НЕ должна влиять на успешное изменение статуса
      if (lesson.studentId != null) {
        // Индивидуальное занятие
        try {
          if (lesson.subscriptionId != null) {
            // Было списано с подписки — возвращаем туда
            await _subscriptionRepo.returnLesson(
              lesson.studentId!,
              subscriptionId: lesson.subscriptionId,
            );
            await _repo.clearSubscriptionId(id);
          } else {
            // Было списано в долг — возвращаем (уменьшаем долг)
            await _studentRepo.incrementPrepaidCount(lesson.studentId!);
          }
        } catch (e) {
          // Не критичная ошибка - статус изменён, но баланс не возвращён
          debugPrint('Error returning subscription/debt: $e');
        }
      } else if (lesson.groupId != null && lesson.lessonStudents != null) {
        // Групповое занятие — возвращаем занятие участникам
        // Если было completed — только присутствовавшим
        // Если было cancelled — всем участникам (т.к. списывали со всех)
        final wasCancelled = lesson.status == LessonStatus.cancelled;

        for (final lessonStudent in lesson.lessonStudents!) {
          // Для completed возвращаем только присутствовавшим
          // Для cancelled возвращаем всем
          if (!wasCancelled && !lessonStudent.attended) continue;

          try {
            if (lessonStudent.subscriptionId != null) {
              // Было списано с подписки — возвращаем туда
              await _subscriptionRepo.returnLesson(
                lessonStudent.studentId,
                subscriptionId: lessonStudent.subscriptionId,
              );
              await _repo.clearLessonStudentSubscriptionId(
                id,
                lessonStudent.studentId,
              );
            } else {
              // Было списано в долг — возвращаем (уменьшаем долг)
              await _studentRepo.incrementPrepaidCount(lessonStudent.studentId);
            }
          } catch (e) {
            debugPrint('Error returning for student ${lessonStudent.studentId}: $e');
          }
        }
        // Инвалидируем группы для обновления баланса в меню
        _ref.invalidate(studentGroupsProvider(institutionId));
      }

      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(id));
      // Гибридный Realtime: обновляем список учеников для актуального баланса
      _ref.invalidate(studentsProvider(institutionId));

      // Инвалидируем статистику занятий ученика (проведено/отменено)
      if (lesson.studentId != null) {
        _ref.invalidate(studentLessonStatsProvider(lesson.studentId!));
      } else if (lesson.groupId != null && lesson.lessonStudents != null) {
        for (final ls in lesson.lessonStudents!) {
          _ref.invalidate(studentLessonStatsProvider(ls.studentId));
        }
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> cancel(String id, String roomId, DateTime date, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      final lesson = await _repo.getById(id);

      // Занятие уже было списано если статус completed ИЛИ cancelled
      // При переключении completed → cancelled НЕ списываем повторно
      final alreadyDeducted = lesson.status == LessonStatus.completed ||
                              lesson.status == LessonStatus.cancelled;

      // Защита от повторного списания: если занятие уже отменено — не списываем
      if (lesson.status == LessonStatus.cancelled) {
        _invalidateForRoom(roomId, date, institutionId: institutionId);
        _ref.invalidate(lessonProvider(id));
        // Инвалидируем статистику даже при раннем возврате
        if (lesson.studentId != null) {
          _ref.invalidate(studentLessonStatsProvider(lesson.studentId!));
        } else if (lesson.groupId != null && lesson.lessonStudents != null) {
          for (final ls in lesson.lessonStudents!) {
            _ref.invalidate(studentLessonStatsProvider(ls.studentId));
          }
        }
        state = const AsyncValue.data(null);
        return true;
      }

      await _repo.cancel(id);

      // Списываем занятие ТОЛЬКО если статус БЫЛ scheduled (ещё не списано)
      // При переключении completed → cancelled уже было списано при complete()
      if (!alreadyDeducted) {
        if (lesson.studentId != null) {
          // Индивидуальное занятие
          try {
            // Приоритет списания: 1) legacy_balance, 2) subscription, 3) долг
            final student = await _studentRepo.getById(lesson.studentId!);

            if (student.legacyBalance > 0) {
              // Списываем из остатка (legacy_balance) в первую очередь
              await _studentRepo.decrementLegacyBalance(lesson.studentId!);
              // subscriptionId остаётся null — не привязано к подписке
            } else {
              final subscriptionId = await _subscriptionRepo.deductLessonAndGetId(lesson.studentId!);

              if (subscriptionId != null) {
                // Привязываем занятие к подписке для корректного возврата
                await _repo.setSubscriptionId(id, subscriptionId);
              } else {
                // Нет активной подписки — списываем напрямую (уход в долг)
                await _studentRepo.decrementPrepaidCount(lesson.studentId!);
              }
            }
          } catch (e) {
            // Не критичная ошибка
          }
        } else if (lesson.groupId != null && lesson.lessonStudents != null) {
          // Групповое занятие — списываем у каждого участника
          for (final lessonStudent in lesson.lessonStudents!) {
            // Для отменённых занятий списываем у ВСЕХ участников (не только attended)
            try {
              // Приоритет списания: 1) legacy_balance, 2) subscription, 3) долг
              final student = await _studentRepo.getById(lessonStudent.studentId);

              if (student.legacyBalance > 0) {
                // Списываем из остатка (legacy_balance) в первую очередь
                await _studentRepo.decrementLegacyBalance(lessonStudent.studentId);
                // subscriptionId остаётся null
              } else {
                final subscriptionId = await _subscriptionRepo.deductLessonAndGetId(lessonStudent.studentId);

                if (subscriptionId != null) {
                  await _repo.setLessonStudentSubscriptionId(
                    id,
                    lessonStudent.studentId,
                    subscriptionId,
                  );
                } else {
                  await _studentRepo.decrementPrepaidCount(lessonStudent.studentId);
                }
              }
            } catch (e) {
              // Пропускаем ошибку для конкретного студента
            }
          }
          _ref.invalidate(studentGroupsProvider(institutionId));
        }
      }

      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(id));
      _ref.invalidate(studentsProvider(institutionId));

      // Инвалидируем статистику занятий ученика
      if (lesson.studentId != null) {
        _ref.invalidate(studentLessonStatsProvider(lesson.studentId!));
      } else if (lesson.groupId != null && lesson.lessonStudents != null) {
        for (final ls in lesson.lessonStudents!) {
          _ref.invalidate(studentLessonStatsProvider(ls.studentId));
        }
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archive(String id, String roomId, DateTime date, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _invalidateForRoom(roomId, date, institutionId: institutionId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id, String roomId, DateTime date, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _invalidateForRoom(roomId, date, institutionId: institutionId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Создать серию повторяющихся занятий
  Future<List<Lesson>?> createSeries({
    required String institutionId,
    required String roomId,
    required String teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    required List<DateTime> dates,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final lessons = await _repo.createSeries(
        institutionId: institutionId,
        roomId: roomId,
        teacherId: teacherId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
        studentId: studentId,
        groupId: groupId,
        dates: dates,
        startTime: startTime,
        endTime: endTime,
        comment: comment,
      );

      // Инвалидируем кэш для всех дат
      for (final date in dates) {
        _invalidateForRoom(roomId, date, institutionId: institutionId);
      }

      state = const AsyncValue.data(null);
      return lessons;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Проверить конфликты для списка дат
  Future<List<DateTime>> checkConflictsForDates({
    required String roomId,
    required List<DateTime> dates,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    return _repo.checkConflictsForDates(
      roomId: roomId,
      dates: dates,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Удалить это и все последующие занятия серии
  Future<bool> deleteFollowing(String repeatGroupId, DateTime fromDate, String roomId, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteFollowingLessons(repeatGroupId, fromDate);
      _invalidateForRoom(roomId, fromDate, institutionId: institutionId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Обновить поля для последующих занятий серии
  /// Поддерживает: время, кабинет, ученик, предмет, тип занятия
  Future<bool> updateFollowing(
    String repeatGroupId,
    DateTime fromDate,
    String originalRoomId,
    String institutionId, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? roomId,
    String? studentId,
    String? subjectId,
    String? lessonTypeId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateFollowingLessons(
        repeatGroupId,
        fromDate,
        startTime: startTime,
        endTime: endTime,
        roomId: roomId,
        studentId: studentId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
      );
      // Инвалидируем и старый и новый кабинет (если менялся)
      _invalidateForRoom(originalRoomId, fromDate, institutionId: institutionId);
      if (roomId != null && roomId != originalRoomId) {
        _invalidateForRoom(roomId, fromDate, institutionId: institutionId);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Получить количество последующих занятий в серии
  Future<int> getFollowingCount(String repeatGroupId, DateTime fromDate) async {
    final lessons = await _repo.getFollowingLessons(repeatGroupId, fromDate);
    return lessons.length;
  }

  /// Обновить выбранные занятия по списку ID
  /// Поддерживает: время, кабинет, ученик, предмет, тип занятия
  Future<bool> updateSelected(
    List<String> lessonIds,
    String institutionId, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? roomId,
    String? studentId,
    String? subjectId,
    String? lessonTypeId,
  }) async {
    if (lessonIds.isEmpty) {
      return true;
    }

    state = const AsyncValue.loading();
    try {
      await _repo.updateSelectedLessons(
        lessonIds,
        startTime: startTime,
        endTime: endTime,
        roomId: roomId,
        studentId: studentId,
        subjectId: subjectId,
        lessonTypeId: lessonTypeId,
      );

      // Инвалидируем все дневные провайдеры для заведения (за 30 дней вперёд и назад)
      final now = DateTime.now();
      for (int i = -30; i <= 30; i++) {
        final date = now.add(Duration(days: i));
        _ref.invalidate(lessonsByInstitutionStreamProvider(
          InstitutionDateParams(institutionId, date),
        ));
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // ============================================================
  // МЕТОДЫ ДЛЯ УПРАВЛЕНИЯ УЧАСТНИКАМИ ГРУППОВОГО ЗАНЯТИЯ
  // ============================================================

  /// Добавить гостя (ученика не из группы) в занятие
  Future<bool> addGuestToLesson(
    String lessonId,
    String studentId,
    String roomId,
    DateTime date,
    String institutionId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addGuestToLesson(lessonId, studentId);
      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(lessonId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Удалить участника из занятия
  Future<bool> removeLessonStudent(
    String lessonId,
    String studentId,
    String roomId,
    DateTime date,
    String institutionId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeLessonStudent(lessonId, studentId);
      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(lessonId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Обновить статус присутствия участника
  Future<bool> updateAttendance(
    String lessonId,
    String studentId,
    bool attended,
    String roomId,
    DateTime date,
    String institutionId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateAttendance(lessonId, studentId, attended);
      _invalidateForRoom(roomId, date, institutionId: institutionId);
      _ref.invalidate(lessonProvider(lessonId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void _invalidateForRoom(String roomId, DateTime date, {String? institutionId}) {
    _ref.invalidate(lessonsByRoomProvider(RoomDateParams(roomId, date)));

    // Гибридный Realtime: инвалидируем провайдеры для надёжного обновления
    if (institutionId != null) {
      // Дневной режим
      _ref.invalidate(lessonsByInstitutionStreamProvider(
        InstitutionDateParams(institutionId, date),
      ));

      // Недельный режим
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final normalizedWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
      _ref.invalidate(lessonsByInstitutionWeekProvider(
        InstitutionWeekParams(institutionId, normalizedWeekStart),
      ));
    }
  }
}

/// Провайдер контроллера занятий
final lessonControllerProvider =
    StateNotifierProvider<LessonController, AsyncValue<void>>((ref) {
  final repo = ref.watch(lessonRepositoryProvider);
  final subscriptionRepo = ref.watch(subscriptionRepoProvider);
  return LessonController(repo, subscriptionRepo, ref);
});

// ============================================================
// ПРОВАЙДЕРЫ ДЛЯ УЧАСТНИКОВ ГРУППОВОГО ЗАНЯТИЯ
// ============================================================

/// Провайдер участников группового занятия
final lessonStudentsProvider =
    FutureProvider.family<List<LessonStudent>, String>((ref, lessonId) async {
  final repo = ref.watch(lessonRepositoryProvider);
  return repo.getLessonStudents(lessonId);
});
