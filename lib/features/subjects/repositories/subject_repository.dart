import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Репозиторий для работы с предметами
class SubjectRepository {
  final _client = SupabaseConfig.client;

  /// Получить все предметы заведения
  Future<List<Subject>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('subjects')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('sort_order')
          .order('name');

      return (data as List).map((item) => Subject.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки предметов: $e');
    }
  }

  /// Получить предмет по ID
  Future<Subject?> getById(String id) async {
    try {
      final data = await _client
          .from('subjects')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки предмета: $e');
    }
  }

  /// Создать новый предмет
  Future<Subject> create({
    required String institutionId,
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    try {
      final data = await _client
          .from('subjects')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'color': color,
            'sort_order': sortOrder,
          })
          .select()
          .single();

      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания предмета: $e');
    }
  }

  /// Обновить предмет
  Future<Subject> update({
    required String id,
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (color != null) updates['color'] = color;
      if (sortOrder != null) updates['sort_order'] = sortOrder;

      final data = await _client
          .from('subjects')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Subject.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления предмета: $e');
    }
  }

  /// Архивировать предмет
  Future<void> archive(String id) async {
    try {
      await _client
          .from('subjects')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивирования предмета: $e');
    }
  }

  /// Удалить предмет навсегда
  Future<void> delete(String id) async {
    try {
      await _client.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления предмета: $e');
    }
  }
}
