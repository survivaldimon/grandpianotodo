import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/config/app_config.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Экран загрузки приложения
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Небольшая задержка для показа splash
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final isAuthenticated = ref.read(isAuthenticatedProvider);
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
