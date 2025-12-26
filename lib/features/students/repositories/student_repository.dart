import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Репозиторий для работы с учениками
class StudentRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Получить список учеников заведения
  Future<List<Student>> getByInstitution(
    String institutionId, {
    bool includeArchived = false,
    bool onlyWithDebt = false,
  }) async {
    try {
      var query = _client
          .from('students')
          .select()
          .eq('institution_id', institutionId);

      if (!includeArchived) {
        query = query.isFilter('archived_at', null);
      }

      if (onlyWithDebt) {
        query = query.lt('prepaid_lessons_count', 0);
      }

      final data = await query.order('name');

      return (data as List).map((item) => Student.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки учеников: $e');
    }
  }

  /// Получить ученика по ID
  Future<Student> getById(String id) async {
    try {
      final data = await _client
          .from('students')
          .select()
          .eq('id', id)
          .single();

      return Student.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки ученика: $e');
    }
  }

  /// Создать ученика
  Future<Student> create({
    required String institutionId,
    required String name,
    String? phone,
    String? comment,
  }) async {
    try {
      final data = await _client
          .from('students')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'phone': phone,
            'comment': comment,
          })
          .select()
          .single();

      return Student.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания ученика: $e');
    }
  }

  /// Обновить ученика
  Future<Student> update(
    String id, {
    String? name,
    String? phone,
    String? comment,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (comment != null) updates['comment'] = comment;

      final data = await _client
          .from('students')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Student.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления ученика: $e');
    }
  }

  /// Архивировать ученика
  Future<void> archive(String id) async {
    try {
      await _client
          .from('students')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации ученика: $e');
    }
  }

  /// Восстановить ученика
  Future<void> restore(String id) async {
    try {
      await _client
          .from('students')
          .update({'archived_at': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка восстановления ученика: $e');
    }
  }

  /// Поиск учеников
  Future<List<Student>> search(String institutionId, String query) async {
    try {
      final data = await _client
          .from('students')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .ilike('name', '%$query%')
          .order('name')
          .limit(20);

      return (data as List).map((item) => Student.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка поиска: $e');
    }
  }

  /// Стрим учеников (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  Stream<List<Student>> watchByInstitution(String institutionId) async* {
    await for (final _ in _client.from('students').stream(primaryKey: ['id'])) {
      // При любом изменении загружаем актуальные данные (включая архивированных)
      final students = await getByInstitution(institutionId, includeArchived: true);
      yield students;
    }
  }

  // === Группы ===

  /// Получить группы заведения
  Future<List<StudentGroup>> getGroups(String institutionId) async {
    try {
      final data = await _client
          .from('student_groups')
          .select('*, student_group_members(*, students(*))')
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('name');

      return (data as List)
          .map((item) => StudentGroup.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки групп: $e');
    }
  }

  /// Создать группу
  Future<StudentGroup> createGroup({
    required String institutionId,
    required String name,
    String? comment,
    List<String>? studentIds,
  }) async {
    try {
      final groupData = await _client
          .from('student_groups')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'comment': comment,
          })
          .select()
          .single();

      final group = StudentGroup.fromJson(groupData);

      // Добавить участников
      if (studentIds != null && studentIds.isNotEmpty) {
        await _client.from('student_group_members').insert(
          studentIds.map((id) => {
            'group_id': group.id,
            'student_id': id,
          }).toList(),
        );
      }

      return group;
    } catch (e) {
      throw DatabaseException('Ошибка создания группы: $e');
    }
  }

  /// Добавить ученика в группу
  Future<void> addToGroup(String groupId, String studentId) async {
    try {
      await _client.from('student_group_members').insert({
        'group_id': groupId,
        'student_id': studentId,
      });
    } catch (e) {
      throw DatabaseException('Ошибка добавления в группу: $e');
    }
  }

  /// Удалить ученика из группы
  Future<void> removeFromGroup(String groupId, String studentId) async {
    try {
      await _client
          .from('student_group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления из группы: $e');
    }
  }
}
