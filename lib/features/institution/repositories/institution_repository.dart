import 'dart:async';

import 'package:flutter/foundation.dart';
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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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

  /// Стрим заведения по ID (realtime)
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<Institution> watchById(String id) {
    final controller = StreamController<Institution>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final institution = await getById(id);
        if (!controller.isClosed) {
          controller.add(institution);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('institutions')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .listen(
          (_) => loadAndEmit(),
          onError: (e) {
            debugPrint('[InstitutionRepository] watchById error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Создать заведение
  Future<Institution> create(String name) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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

  /// Обновить рабочее время заведения
  Future<Institution> updateWorkingHours(
    String id, {
    required int startHour,
    required int endHour,
  }) async {
    try {
      final data = await _client
          .from('institutions')
          .update({
            'work_start_hour': startHour,
            'work_end_hour': endHour,
          })
          .eq('id', id)
          .select()
          .single();

      return Institution.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления рабочего времени: $e');
    }
  }

  /// Присоединиться к заведению по коду
  Future<Institution> joinByCode(String code) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      // Найти заведение по коду
      // RLS политика уже фильтрует archived_at IS NULL
      final institutionData = await _client
          .from('institutions')
          .select()
          .eq('invite_code', code.toUpperCase().trim())
          .maybeSingle();

      if (institutionData == null) {
        throw const ValidationException('Заведение с таким кодом не найдено');
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
        throw const ValidationException('Вы уже состоите в этом заведении');
      }

      // Добавить как участника с базовыми правами
      await _client.from('institution_members').insert({
        'institution_id': institution.id,
        'user_id': _userId,
        'role_name': 'Преподаватель',
        'permissions': const MemberPermissions().toJson(),
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

  /// Стрим моего членства в заведении (realtime)
  /// Обновляется автоматически при изменении прав
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<InstitutionMember?> watchMyMembership(String institutionId) {
    final controller = StreamController<InstitutionMember?>.broadcast();

    if (_userId == null) {
      controller.add(null);
      controller.close();
      return controller.stream;
    }

    final userId = _userId;

    Future<void> loadAndEmit() async {
      try {
        final member = await getMyMembership(institutionId);
        if (!controller.isClosed) {
          controller.add(member);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client
        .from('institution_members')
        .stream(primaryKey: ['id'])
        .eq('institution_id', institutionId)
        .listen(
          (data) {
            // Находим запись текущего пользователя
            final myData = data.where((item) =>
              item['user_id'] == userId &&
              item['archived_at'] == null
            ).firstOrNull;

            if (!controller.isClosed) {
              if (myData != null) {
                controller.add(InstitutionMember.fromJson(myData));
              } else {
                controller.add(null);
              }
            }
          },
          onError: (e) {
            debugPrint('[InstitutionRepository] watchMyMembership error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
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

  /// Обновить статус администратора
  Future<void> updateMemberAdminStatus(String memberId, bool isAdmin) async {
    try {
      await _client
          .from('institution_members')
          .update({'is_admin': isAdmin})
          .eq('id', memberId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления статуса администратора: $e');
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

  /// Обновить цвет участника
  Future<void> updateMemberColor(String memberId, String? color) async {
    try {
      final result = await _client
          .from('institution_members')
          .update({'color': color})
          .eq('id', memberId)
          .select();

      if ((result as List).isEmpty) {
        throw const DatabaseException('Не удалось обновить цвет (RLS или запись не найдена)');
      }
    } catch (e) {
      throw DatabaseException('Ошибка обновления цвета: $e');
    }
  }

  /// Обновить кабинеты по умолчанию для участника
  /// [roomIds]: null = не настроено, [] = показывать все, [...] = выбранные
  Future<void> updateMemberDefaultRooms(String memberId, List<String>? roomIds) async {
    try {
      final result = await _client
          .from('institution_members')
          .update({'default_room_ids': roomIds})
          .eq('id', memberId)
          .select();

      if ((result as List).isEmpty) {
        throw const DatabaseException('Не удалось обновить кабинеты (RLS или запись не найдена)');
      }
    } catch (e) {
      throw DatabaseException('Ошибка обновления кабинетов: $e');
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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что текущий пользователь - владелец
      final institution = await getById(id);
      if (institution.ownerId != _userId) {
        throw const ValidationException('Только владелец может удалить заведение');
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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что пользователь не владелец
      final institution = await getById(institutionId);
      if (institution.ownerId == _userId) {
        throw const ValidationException('Владелец не может покинуть заведение. Удалите его или передайте права.');
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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      // Проверить, что текущий пользователь - владелец
      final data = await _client
          .from('institutions')
          .select()
          .eq('id', id)
          .single();

      final institution = Institution.fromJson(data);
      if (institution.ownerId != _userId) {
        throw const ValidationException('Только владелец может восстановить заведение');
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

  /// Передать права владельца другому участнику
  /// Использует RPC функцию с SECURITY DEFINER для обхода RLS
  Future<void> transferOwnership(String institutionId, String newOwnerUserId) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      await _client.rpc('transfer_institution_ownership', params: {
        'p_institution_id': institutionId,
        'p_new_owner_id': newOwnerUserId,
      });
    } on PostgrestException catch (e) {
      // Преобразуем ошибки PostgreSQL в понятные пользователю
      if (e.message.contains('Только владелец')) {
        throw const ValidationException('Только владелец может передать права');
      } else if (e.message.contains('не является участником')) {
        throw const ValidationException('Пользователь не является участником заведения');
      } else if (e.message.contains('не найдено')) {
        throw const ValidationException('Заведение не найдено');
      }
      throw DatabaseException('Ошибка передачи прав владельца: $e');
    } catch (e) {
      throw DatabaseException('Ошибка передачи прав владельца: $e');
    }
  }
}
