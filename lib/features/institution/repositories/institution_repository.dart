import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/institution.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Репозиторий для работы с заведениями
class InstitutionRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Получить список заведений пользователя
  Future<List<Institution>> getMyInstitutions() async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('institution_members')
          .select('institution:institutions!inner(*)')
          .eq('user_id', _userId!)
          .isFilter('archived_at', null)
          .isFilter('institution.archived_at', null);

      return (data as List)
          .map((item) => Institution.fromJson(item['institution']))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки заведений: $e');
    }
  }

  /// Получить заведение по ID
  Future<Institution> getById(String id) async {
    try {
      final data = await _client
          .from('institutions')
          .select()
          .eq('id', id)
          .single();

      return Institution.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки заведения: $e');
    }
  }

  /// Создать заведение
  Future<Institution> create(String name) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('institutions')
          .insert({
            'name': name,
            'owner_id': _userId,
          })
          .select()
          .single();

      return Institution.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания заведения: $e');
    }
  }

  /// Обновить заведение
  Future<Institution> update(String id, {required String name}) async {
    try {
      final data = await _client
          .from('institutions')
          .update({'name': name})
          .eq('id', id)
          .select()
          .single();

      return Institution.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления заведения: $e');
    }
  }

  /// Присоединиться к заведению по коду
  Future<Institution> joinByCode(String code) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      // Найти заведение по коду
      // RLS политика уже фильтрует archived_at IS NULL
      final institutionData = await _client
          .from('institutions')
          .select()
          .eq('invite_code', code.toUpperCase().trim())
          .maybeSingle();

      if (institutionData == null) {
        throw ValidationException('Заведение с таким кодом не найдено');
      }

      final institution = Institution.fromJson(institutionData);

      // Проверить, не состоит ли уже
      final existingMember = await _client
          .from('institution_members')
          .select()
          .eq('institution_id', institution.id)
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existingMember != null) {
        throw ValidationException('Вы уже состоите в этом заведении');
      }

      // Добавить как участника
      await _client.from('institution_members').insert({
        'institution_id': institution.id,
        'user_id': _userId,
        'role_name': 'Преподаватель',
      });

      return institution;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Ошибка присоединения: $e');
    }
  }

  /// Получить участников заведения
  Future<List<InstitutionMember>> getMembers(String institutionId) async {
    try {
      final data = await _client
          .from('institution_members')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('joined_at');

      return (data as List)
          .map((item) => InstitutionMember.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки участников: $e');
    }
  }

  /// Получить мои права в заведении
  Future<InstitutionMember?> getMyMembership(String institutionId) async {
    if (_userId == null) return null;

    try {
      final data = await _client
          .from('institution_members')
          .select()
          .eq('institution_id', institutionId)
          .eq('user_id', _userId!)
          .isFilter('archived_at', null)
          .maybeSingle();

      if (data == null) return null;
      return InstitutionMember.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки прав: $e');
    }
  }

  /// Обновить права участника
  Future<void> updateMemberPermissions(
    String memberId,
    MemberPermissions permissions,
  ) async {
    try {
      await _client
          .from('institution_members')
          .update({'permissions': permissions.toJson()})
          .eq('id', memberId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления прав: $e');
    }
  }

  /// Обновить название роли участника
  Future<void> updateMemberRole(String memberId, String roleName) async {
    try {
      await _client
          .from('institution_members')
          .update({'role_name': roleName})
          .eq('id', memberId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления роли: $e');
    }
  }

  /// Удалить участника (архивация)
  Future<void> removeMember(String memberId) async {
    try {
      await _client
          .from('institution_members')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления участника: $e');
    }
  }

  /// Перегенерировать invite code
  Future<String> regenerateInviteCode(String institutionId) async {
    try {
      final data = await _client.rpc('generate_invite_code');
      final newCode = data as String;

      await _client
          .from('institutions')
          .update({'invite_code': newCode})
          .eq('id', institutionId);

      return newCode;
    } catch (e) {
      throw DatabaseException('Ошибка генерации кода: $e');
    }
  }

  /// Архивировать заведение
  Future<void> archive(String id) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что текущий пользователь - владелец
      final institution = await getById(id);
      if (institution.ownerId != _userId) {
        throw ValidationException('Только владелец может удалить заведение');
      }

      await _client
          .from('institutions')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Ошибка удаления заведения: $e');
    }
  }

  /// Покинуть заведение (для не-владельца)
  Future<void> leave(String institutionId) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что пользователь не владелец
      final institution = await getById(institutionId);
      if (institution.ownerId == _userId) {
        throw ValidationException('Владелец не может покинуть заведение. Удалите его или передайте права.');
      }

      await _client
          .from('institution_members')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('institution_id', institutionId)
          .eq('user_id', _userId!);
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Ошибка выхода из заведения: $e');
    }
  }

  /// Получить архивированные заведения пользователя
  Future<List<Institution>> getArchivedInstitutions() async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('institutions')
          .select()
          .eq('owner_id', _userId!)
          .not('archived_at', 'is', null);

      return (data as List)
          .map((item) => Institution.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки архивированных заведений: $e');
    }
  }

  /// Восстановить заведение из архива
  Future<void> restore(String id) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что текущий пользователь - владелец
      final data = await _client
          .from('institutions')
          .select()
          .eq('id', id)
          .single();

      final institution = Institution.fromJson(data);
      if (institution.ownerId != _userId) {
        throw ValidationException('Только владелец может восстановить заведение');
      }

      await _client
          .from('institutions')
          .update({'archived_at': null})
          .eq('id', id);
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Ошибка восстановления заведения: $e');
    }
  }
}
