import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/router/app_router.dart';
import 'package:kabinet/core/theme/app_theme.dart';
import 'package:kabinet/core/theme/theme_provider.dart';
import 'package:kabinet/core/providers/locale_provider.dart';
import 'package:kabinet/core/config/app_config.dart';
import 'package:kabinet/core/config/supabase_config.dart';

/// Главный виджет приложения
class KabinetApp extends ConsumerStatefulWidget {
  const KabinetApp({super.key});

  @override
  ConsumerState<KabinetApp> createState() => _KabinetAppState();
}

class _KabinetAppState extends ConsumerState<KabinetApp> {
  StreamSubscription<AuthState>? _authSubscription;

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
    // Глобальный слушатель для обработки PASSWORD_RECOVERY когда приложение уже запущено
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      debugPrint('[KabinetApp] Global auth event: ${data.event}');

      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('[KabinetApp] Password recovery detected, navigating to reset-password');
        // Используем GoRouter для навигации
        final router = ref.read(routerProvider);
        router.go('/reset-password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(localeProvider);
    final resolvedLocale = resolveLocale(appLocale);

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: resolvedLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
