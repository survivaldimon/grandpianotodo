import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/auth/repositories/auth_repository.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';

/// Провайдер репозитория аутентификации
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Провайдер профиля текущего пользователя
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;
  return repo.getCurrentProfile();
});

/// Состояние формы входа/регистрации
class AuthFormState {
  final bool isLoading;
  final String? error;

  const AuthFormState({
    this.isLoading = false,
    this.error,
  });

  AuthFormState copyWith({bool? isLoading, String? error}) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Контроллер аутентификации
class AuthController extends StateNotifier<AuthFormState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthFormState());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.signUp(email: email, password: password, fullName: fullName);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resetPassword(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signInWithMagicLink(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.signInWithMagicLink(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Провайдер контроллера аутентификации
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
