import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/config/app_config.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Экран загрузки приложения
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    // Слушаем события авторизации для обработки PASSWORD_RECOVERY
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (_navigated || !mounted) return;

      debugPrint('[SplashScreen] Auth event: ${data.event}');

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigated = true;
        debugPrint('[SplashScreen] Password recovery detected, navigating to reset-password');
        context.go('/reset-password');
        return;
      }
    });

    // Проверяем начальное состояние после небольшой задержки
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Небольшая задержка для показа splash и получения deep link
    await Future.delayed(const Duration(milliseconds: 800));

    if (_navigated || !mounted) return;

    final isAuthenticated = ref.read(isAuthenticatedProvider);
    _navigated = true;

    if (isAuthenticated) {
      context.go('/institutions');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_month,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
