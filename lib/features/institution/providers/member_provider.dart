import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/shared/models/institution_member.dart';

/// Провайдер списка участников заведения
final membersProvider =
    FutureProvider.family<List<InstitutionMember>, String>((ref, institutionId) async {
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
});
