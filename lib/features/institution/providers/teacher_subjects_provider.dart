import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Провайдер для получения предметов преподавателя
final teacherSubjectsProvider = FutureProvider.family<List<TeacherSubject>, TeacherSubjectsParams>(
  (ref, params) async {
    try {
      final client = SupabaseConfig.client;

      final data = await client
          .from('teacher_subjects')
          .select('*, subjects(*)')
          .eq('user_id', params.userId)
          .eq('institution_id', params.institutionId);

      return (data as List).map((item) => TeacherSubject.fromJson(item)).toList();
    } catch (e) {
      debugPrint('[TeacherSubjectsProvider] teacherSubjectsProvider error: $e');
      rethrow;
    }
  },
);

/// Параметры для teacherSubjectsProvider
class TeacherSubjectsParams {
  final String userId;
  final String institutionId;

  const TeacherSubjectsParams({
    required this.userId,
    required this.institutionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherSubjectsParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          institutionId == other.institutionId;

  @override
  int get hashCode => userId.hashCode ^ institutionId.hashCode;
}

/// Контроллер для управления привязками преподаватель-предмет
final teacherSubjectsControllerProvider =
    StateNotifierProvider<TeacherSubjectsController, AsyncValue<void>>(
  (ref) => TeacherSubjectsController(ref),
);

class TeacherSubjectsController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TeacherSubjectsController(this._ref) : super(const AsyncValue.data(null));

  /// Добавить привязку предмета к преподавателю
  Future<void> addSubject({
    required String userId,
    required String subjectId,
    required String institutionId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await SupabaseConfig.client.from('teacher_subjects').upsert(
        {
          'user_id': userId,
          'subject_id': subjectId,
          'institution_id': institutionId,
        },
        onConflict: 'user_id,subject_id',
      );

      // Инвалидируем кэш
      _ref.invalidate(teacherSubjectsProvider(
        TeacherSubjectsParams(userId: userId, institutionId: institutionId),
      ));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('Error adding teacher subject: $e');
    }
  }

  /// Удалить привязку предмета от преподавателя
  Future<void> removeSubject({
    required String userId,
    required String subjectId,
    required String institutionId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await SupabaseConfig.client
          .from('teacher_subjects')
          .delete()
          .eq('user_id', userId)
          .eq('subject_id', subjectId);

      // Инвалидируем кэш
      _ref.invalidate(teacherSubjectsProvider(
        TeacherSubjectsParams(userId: userId, institutionId: institutionId),
      ));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('Error removing teacher subject: $e');
    }
  }
}
