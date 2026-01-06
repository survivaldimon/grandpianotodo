import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthResponse, AuthState, SupabaseClient, User;
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/profile.dart';

/// Репозиторий для аутентификации
class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Текущий пользователь
  User? get currentUser => _client.auth.currentUser;

  /// Авторизован ли пользователь
  bool get isAuthenticated => currentUser != null;

  /// Стрим состояния авторизации
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Регистрация по email
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response;
    } on AuthException catch (e) {
      throw AuthAppException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthAppException('Ошибка регистрации: $e');
    }
  }

  /// Вход по email
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthAppException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthAppException('Ошибка входа: $e');
    }
  }

  // TODO: OAuth (Google, Apple) требует дополнительной настройки deep links
  // Реализовать позже при необходимости

  /// Выход
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthAppException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthAppException('Ошибка выхода: $e');
    }
  }

  /// Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.authCallbackUrl,
      );
    } on AuthException catch (e) {
      throw AuthAppException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthAppException('Ошибка сброса пароля: $e');
    }
  }

  /// Вход по Magic Link (без пароля)
  Future<void> signInWithMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email);
    } on AuthException catch (e) {
      throw AuthAppException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthAppException('Ошибка отправки ссылки: $e');
    }
  }

  /// Получить профиль текущего пользователя
  Future<Profile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки профиля: $e');
    }
  }

  /// Обновить профиль
  Future<Profile> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          })
          .eq('id', user.id)
          .select()
          .single();

      return Profile.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления профиля: $e');
    }
  }

  /// Маппинг ошибок Supabase на русский
  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (message.contains('Email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту';
    }
    if (message.contains('User already registered')) {
      return 'Пользователь с таким email уже зарегистрирован';
    }
    if (message.contains('Password should be')) {
      return 'Пароль должен быть не менее 6 символов';
    }
    if (message.contains('Invalid email')) {
      return 'Неверный формат email';
    }
    return message;
  }
}
