import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
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
final membersStreamProvider =
    StreamProvider.family<List<InstitutionMember>, String>((ref, institutionId) {
  final client = SupabaseConfig.client;

  // Создаём контроллер для стрима с профилями
  final controller = StreamController<List<InstitutionMember>>();

  // Подписываемся на realtime изменения
  final subscription = client
      .from('institution_members')
      .stream(primaryKey: ['id'])
      .eq('institution_id', institutionId)
      .listen((data) async {
    // При каждом изменении загружаем данные с профилями
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
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});
