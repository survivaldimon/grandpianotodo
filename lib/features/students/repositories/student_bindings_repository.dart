import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/student_teacher.dart';
import 'package:kabinet/shared/models/student_subject.dart';
import 'package:kabinet/shared/models/student_lesson_type.dart';

/// Репозиторий для работы с привязками учеников к преподавателям и предметам
class StudentBindingsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // ============================================
  // STUDENT TEACHERS
  // ============================================

  /// Получить преподавателей ученика
  Future<List<StudentTeacher>> getStudentTeachers(String studentId) async {
    try {
      // Получаем привязки без join (FK на auth.users, не на profiles)
      final bindingsData = await _client
          .from('student_teachers')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at');

      final bindings = bindingsData as List;
      if (bindings.isEmpty) return [];

      // Получаем профили отдельно
      final userIds = bindings.map((b) => b['user_id'] as String).toList();
      final profilesData = await _client
          .from('profiles')
          .select('*')
          .inFilter('id', userIds);

      // Создаём Map для быстрого поиска
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesData as List) {
        profilesMap[profile['id'] as String] = profile;
      }

      // Собираем результат с профилями
      return bindings.map((item) {
        final userId = item['user_id'] as String;
        final itemWithProfile = Map<String, dynamic>.from(item);
        itemWithProfile['profiles'] = profilesMap[userId];
        return StudentTeacher.fromJson(itemWithProfile);
      }).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки преподавателей ученика: $e');
    }
  }

  /// Получить ID учеников привязанных к преподавателю (для фильтра "Мои ученики")
  Future<List<String>> getTeacherStudentIds(
    String userId,
    String institutionId,
  ) async {
    try {
      final data = await _client
          .from('student_teachers')
          .select('student_id')
          .eq('user_id', userId)
          .eq('institution_id', institutionId);

      return (data as List)
          .map((item) => item['student_id'] as String)
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки учеников преподавателя: $e');
    }
  }

  /// Добавить привязку преподавателя к ученику (upsert)
  Future<StudentTeacher> addStudentTeacher({
    required String studentId,
    required String userId,
    required String institutionId,
  }) async {
    try {
      // Upsert привязки
      final bindingData = await _client
          .from('student_teachers')
          .upsert(
            {
              'student_id': studentId,
              'user_id': userId,
              'institution_id': institutionId,
            },
            onConflict: 'student_id,user_id',
          )
          .select('*')
          .single();

      // Получаем профиль отдельно
      final profileData = await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      final itemWithProfile = Map<String, dynamic>.from(bindingData);
      itemWithProfile['profiles'] = profileData;

      return StudentTeacher.fromJson(itemWithProfile);
    } catch (e) {
      throw DatabaseException('Ошибка добавления преподавателя: $e');
    }
  }

  /// Удалить привязку преподавателя от ученика
  Future<void> removeStudentTeacher(String studentId, String userId) async {
    try {
      await _client
          .from('student_teachers')
          .delete()
          .eq('student_id', studentId)
          .eq('user_id', userId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления преподавателя: $e');
    }
  }

  // ============================================
  // STUDENT SUBJECTS
  // ============================================

  /// Получить предметы ученика
  Future<List<StudentSubject>> getStudentSubjects(String studentId) async {
    try {
      final data = await _client
          .from('student_subjects')
          .select('*, subjects(*)')
          .eq('student_id', studentId)
          .order('created_at');

      return (data as List)
          .map((item) => StudentSubject.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки предметов ученика: $e');
    }
  }

  /// Добавить привязку предмета к ученику (upsert)
  Future<StudentSubject> addStudentSubject({
    required String studentId,
    required String subjectId,
    required String institutionId,
  }) async {
    try {
      final data = await _client
          .from('student_subjects')
          .upsert(
            {
              'student_id': studentId,
              'subject_id': subjectId,
              'institution_id': institutionId,
            },
            onConflict: 'student_id,subject_id',
          )
          .select('*, subjects(*)')
          .single();

      return StudentSubject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка добавления предмета: $e');
    }
  }

  /// Удалить привязку предмета от ученика
  Future<void> removeStudentSubject(String studentId, String subjectId) async {
    try {
      await _client
          .from('student_subjects')
          .delete()
          .eq('student_id', studentId)
          .eq('subject_id', subjectId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления предмета: $e');
    }
  }

  // ============================================
  // STUDENT LESSON TYPES
  // ============================================

  /// Получить типы занятий ученика
  Future<List<StudentLessonType>> getStudentLessonTypes(String studentId) async {
    try {
      final data = await _client
          .from('student_lesson_types')
          .select('*, lesson_types(*)')
          .eq('student_id', studentId)
          .order('created_at');

      return (data as List)
          .map((item) => StudentLessonType.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки типов занятий ученика: $e');
    }
  }

  /// Добавить привязку типа занятия к ученику (upsert)
  Future<StudentLessonType> addStudentLessonType({
    required String studentId,
    required String lessonTypeId,
    required String institutionId,
  }) async {
    try {
      final data = await _client
          .from('student_lesson_types')
          .upsert(
            {
              'student_id': studentId,
              'lesson_type_id': lessonTypeId,
              'institution_id': institutionId,
            },
            onConflict: 'student_id,lesson_type_id',
          )
          .select('*, lesson_types(*)')
          .single();

      return StudentLessonType.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка добавления типа занятия: $e');
    }
  }

  /// Удалить привязку типа занятия от ученика
  Future<void> removeStudentLessonType(String studentId, String lessonTypeId) async {
    try {
      await _client
          .from('student_lesson_types')
          .delete()
          .eq('student_id', studentId)
          .eq('lesson_type_id', lessonTypeId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления типа занятия: $e');
    }
  }

  // ============================================
  // АВТОМАТИЧЕСКОЕ СОЗДАНИЕ ПРИВЯЗОК
  // ============================================

  /// Создать привязки из занятия (upsert - не падает если уже существуют)
  /// Вызывается при создании занятия
  Future<void> createBindingsFromLesson({
    required String studentId,
    required String teacherId,
    String? subjectId,
    String? lessonTypeId,
    required String institutionId,
  }) async {
    try {
      // Всегда создаём привязку ученик-преподаватель
      await _client.from('student_teachers').upsert(
        {
          'student_id': studentId,
          'user_id': teacherId,
          'institution_id': institutionId,
        },
        onConflict: 'student_id,user_id',
      );

      // Создаём привязку ученик-предмет если предмет указан
      if (subjectId != null) {
        debugPrint('Creating subject binding: studentId=$studentId, subjectId=$subjectId');
        await _client.from('student_subjects').upsert(
          {
            'student_id': studentId,
            'subject_id': subjectId,
            'institution_id': institutionId,
          },
          onConflict: 'student_id,subject_id',
        );
        debugPrint('Subject binding created successfully');
      }

      // Создаём привязку ученик-тип занятия если тип указан
      if (lessonTypeId != null) {
        debugPrint('Creating lesson type binding: studentId=$studentId, lessonTypeId=$lessonTypeId');
        await _client.from('student_lesson_types').upsert(
          {
            'student_id': studentId,
            'lesson_type_id': lessonTypeId,
            'institution_id': institutionId,
          },
          onConflict: 'student_id,lesson_type_id',
        );
        debugPrint('Lesson type binding created successfully');
      }
    } catch (e, st) {
      // Логируем ошибку, но не прерываем выполнение
      // Привязки - вторичная функция, не должна блокировать создание занятия
      debugPrint('ERROR: Не удалось создать привязки: $e');
      debugPrint('Stack trace: $st');
    }
  }

  // ============================================
  // ПОСЛЕДНЕЕ ЗАНЯТИЕ (для автозаполнения)
  // ============================================

  /// Получить последнее занятие ученика
  /// Используется для автозаполнения полей при создании нового занятия
  Future<Lesson?> getStudentLastLesson(String studentId) async {
    try {
      final data = await _client
          .from('lessons')
          .select('''
            *,
            rooms(*),
            subjects(*),
            lesson_types(*),
            profiles!lessons_teacher_id_fkey(*)
          ''')
          .eq('student_id', studentId)
          .isFilter('archived_at', null)
          .order('date', ascending: false)
          .order('end_time', ascending: false)
          .limit(1);

      final list = data as List;
      if (list.isEmpty) return null;

      return Lesson.fromJson(list.first);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки последнего занятия: $e');
    }
  }
}
