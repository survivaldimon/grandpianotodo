import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Провайдер Supabase клиента
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Провайдер текущего пользователя (из auth state)
final currentUserProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

/// Провайдер ID текущего пользователя
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.id;
});

/// Провайдер проверки аутентификации
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return userId != null;
});
