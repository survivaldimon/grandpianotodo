import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/shared/models/subject.dart';

/// Провайдер списка предметов заведения
final subjectsProvider =
    FutureProvider.family<List<Subject>, String>((ref, institutionId) async {
  final client = SupabaseConfig.client;

  final data = await client
      .from('subjects')
      .select()
      .eq('institution_id', institutionId)
      .isFilter('archived_at', null)
      .order('sort_order')
      .order('name');

  return (data as List).map((item) => Subject.fromJson(item)).toList();
});

/// Создать новый предмет
Future<Subject?> createSubject({
  required SupabaseClient client,
  required String institutionId,
  required String name,
  String? color,
}) async {
  final data = await client
      .from('subjects')
      .insert({
        'institution_id': institutionId,
        'name': name,
        'color': color,
      })
      .select()
      .single();

  return Subject.fromJson(data);
}
