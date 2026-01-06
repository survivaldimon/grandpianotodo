import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/profile.dart';

/// Провайдер текущего профиля пользователя
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final client = SupabaseConfig.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null) return null;

  try {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return Profile.fromJson(data);
  } catch (e) {
    throw DatabaseException('Ошибка загрузки профиля: $e');
  }
});

/// Контроллер профиля
class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController() : super(const AsyncValue.data(null));

  Future<bool> updateName(String newName) async {
    state = const AsyncValue.loading();

    final client = SupabaseConfig.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      state = AsyncValue.error(
        const AuthAppException('Пользователь не авторизован'),
        StackTrace.current,
      );
      return false;
    }

    try {
      await client
          .from('profiles')
          .update({'full_name': newName})
          .eq('id', userId);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера профиля
final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController();
});
