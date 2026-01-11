import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/institution/repositories/institution_repository.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Загрузка участников с профилями
Future<List<InstitutionMember>> _loadMembersWithProfiles(String institutionId) async {
  final client = SupabaseConfig.client;

  // Получаем участников
  final data = await client
      .from('institution_members')
      .select()
      .eq('institution_id', institutionId)
      .isFilter('archived_at', null)
      .order('joined_at');

  final members = (data as List).map((item) => InstitutionMember.fromJson(item)).toList();

  // Загружаем профили отдельно
  if (members.isNotEmpty) {
    final userIds = members.map((m) => m.userId).toList();
    final profilesData = await client
        .from('profiles')
        .select()
        .inFilter('id', userIds);

    final profilesMap = <String, Map<String, dynamic>>{};
    for (final p in profilesData as List) {
      profilesMap[p['id'] as String] = p;
    }

    return members.map((m) {
      final profileData = profilesMap[m.userId];
      if (profileData != null) {
        return InstitutionMember.fromJsonWithProfile(m, profileData);
      }
      return m;
    }).toList();
  }

  return members;
}

/// Провайдер списка участников заведения (FutureProvider для совместимости)
final membersProvider =
    FutureProvider.family<List<InstitutionMember>, String>((ref, institutionId) async {
  return _loadMembersWithProfiles(institutionId);
});

/// StreamProvider для realtime обновлений участников
/// Подписывается на изменения и автоматически загружает профили
/// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
final membersStreamProvider =
    StreamProvider.family<List<InstitutionMember>, String>((ref, institutionId) {
  final client = SupabaseConfig.client;

  // Создаём контроллер для стрима с профилями
  final controller = StreamController<List<InstitutionMember>>();

  // Функция загрузки и эмита данных
  Future<void> loadAndEmit() async {
    try {
      final membersWithProfiles = await _loadMembersWithProfiles(institutionId);
      if (!controller.isClosed) {
        controller.add(membersWithProfiles);
      }
      // Также инвалидируем FutureProvider для обратной совместимости
      ref.invalidate(membersProvider(institutionId));
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // 1. Сразу загружаем начальные данные
  loadAndEmit();

  // 2. Подписываемся на realtime изменения
  final subscription = client
      .from('institution_members')
      .stream(primaryKey: ['id'])
      .eq('institution_id', institutionId)
      .listen((_) => loadAndEmit());

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Контроллер для операций с участниками
class MemberController extends StateNotifier<AsyncValue<void>> {
  final InstitutionRepository _repo;
  final Ref _ref;

  MemberController(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Обновить цвет участника
  Future<bool> updateColor(String memberId, String institutionId, String? color) async {
    state = const AsyncValue.loading();
    try {
      // Убираем # если есть (в базе хранится без #)
      final cleanColor = color?.replaceAll('#', '').toUpperCase();
      await _repo.updateMemberColor(memberId, cleanColor);
      _ref.invalidate(membersProvider(institutionId));
      _ref.invalidate(membersStreamProvider(institutionId));
      _ref.invalidate(myMembershipProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Обновить кабинеты по умолчанию
  /// [roomIds]: null = не настроено, [] = показывать все, [...] = выбранные
  Future<bool> updateDefaultRooms(
    String memberId,
    String institutionId,
    List<String>? roomIds,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateMemberDefaultRooms(memberId, roomIds);
      _ref.invalidate(membersProvider(institutionId));
      _ref.invalidate(membersStreamProvider(institutionId));
      _ref.invalidate(myMembershipProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера участников
final memberControllerProvider =
    StateNotifierProvider<MemberController, AsyncValue<void>>((ref) {
  return MemberController(InstitutionRepository(), ref);
});

/// Провайдер проверки необходимости онбординга
/// Возвращает true если преподавателю нужно заполнить цвет или направления
/// Возвращает false пока данные загружаются (чтобы баннер не мелькал)
final needsOnboardingProvider = Provider.family<bool, String>((ref, institutionId) {
  final membershipAsync = ref.watch(myMembershipProvider(institutionId));
  final membership = membershipAsync.valueOrNull;

  // Пока membership загружается — не показываем баннер
  if (membership == null) return false;

  // Владельцу онбординг не нужен
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  final institution = ref.watch(currentInstitutionProvider(institutionId)).valueOrNull;
  final isOwner = institution != null && institution.ownerId == currentUserId;
  if (isOwner) return false;

  // Проверяем наличие цвета
  final hasColor = membership.color != null && membership.color!.isNotEmpty;

  // Проверяем наличие направлений (предметов)
  final subjectsAsync = ref.watch(teacherSubjectsProvider(
    TeacherSubjectsParams(userId: membership.userId, institutionId: institutionId),
  ));

  // Пока subjects загружаются — не показываем баннер (избегаем мелькания)
  if (subjectsAsync.isLoading && !subjectsAsync.hasValue) return false;

  final hasSubjects = (subjectsAsync.valueOrNull?.length ?? 0) > 0;

  return !hasColor || !hasSubjects;
});

/// Провайдер проверки необходимости настройки кабинетов
/// Возвращает true если пользователю нужно настроить кабинеты по умолчанию
/// Возвращает false пока данные загружаются (чтобы промпт не мелькал)
final needsRoomSetupProvider = Provider.family<bool, String>((ref, institutionId) {
  final membershipAsync = ref.watch(myMembershipProvider(institutionId));
  final membership = membershipAsync.valueOrNull;

  // Пока membership загружается — не показываем промпт
  if (membership == null) return false;

  // Если defaultRoomIds == null — настройка не выполнена
  return membership.defaultRoomIds == null;
});
