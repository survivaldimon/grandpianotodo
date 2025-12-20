import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Репозиторий для работы с группами учеников
class GroupRepository {
  final _client = SupabaseConfig.client;

  /// Получить все группы заведения
  Future<List<StudentGroup>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('student_groups')
          .select('''
            *,
            student_group_members(
              *,
              students(*)
            )
          ''')
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('name');

      return (data as List).map((item) => StudentGroup.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки групп: $e');
    }
  }

  /// Получить группу по ID
  Future<StudentGroup> getById(String id) async {
    try {
      final data = await _client
          .from('student_groups')
          .select('''
            *,
            student_group_members(
              *,
              students(*)
            )
          ''')
          .eq('id', id)
          .single();

      return StudentGroup.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки группы: $e');
    }
  }

  /// Создать группу
  Future<StudentGroup> create({
    required String institutionId,
    required String name,
    String? comment,
  }) async {
    try {
      final data = await _client
          .from('student_groups')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'comment': comment,
          })
          .select()
          .single();

      return StudentGroup.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания группы: $e');
    }
  }

  /// Обновить группу
  Future<StudentGroup> update(
    String id, {
    String? name,
    String? comment,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (comment != null) updates['comment'] = comment;

      final data = await _client
          .from('student_groups')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return StudentGroup.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления группы: $e');
    }
  }

  /// Архивировать группу
  Future<void> archive(String id) async {
    try {
      await _client
          .from('student_groups')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации группы: $e');
    }
  }

  /// Добавить ученика в группу
  Future<void> addMember(String groupId, String studentId) async {
    try {
      await _client.from('student_group_members').insert({
        'group_id': groupId,
        'student_id': studentId,
      });
    } catch (e) {
      throw DatabaseException('Ошибка добавления участника: $e');
    }
  }

  /// Удалить ученика из группы
  Future<void> removeMember(String groupId, String studentId) async {
    try {
      await _client
          .from('student_group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления участника: $e');
    }
  }

  /// Получить архивированные группы
  Future<List<StudentGroup>> getArchived(String institutionId) async {
    try {
      final data = await _client
          .from('student_groups')
          .select()
          .eq('institution_id', institutionId)
          .not('archived_at', 'is', null)
          .order('name');

      return (data as List).map((item) => StudentGroup.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки архивированных групп: $e');
    }
  }

  /// Восстановить группу из архива
  Future<void> restore(String id) async {
    try {
      await _client
          .from('student_groups')
          .update({'archived_at': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка восстановления группы: $e');
    }
  }
}
