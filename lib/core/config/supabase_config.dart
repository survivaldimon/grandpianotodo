import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

/// Конфигурация Supabase
class SupabaseConfig {
  static const String supabaseUrl = 'https://ncfpxetzmeeqxgqidosj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jZnB4ZXR6bWVlcXhncWlkb3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTk4NDEsImV4cCI6MjA4MTc5NTg0MX0.lNmvsQc5e6VvN_hbnhfzdz3Y7FhpiRNockXiXqGJ7vQ';

  /// Deep link scheme для авторизации
  static const String authCallbackScheme = 'com.kabinet.kabinet';
  static const String authCallbackUrl = '$authCallbackScheme://login-callback';

  static final AppLinks _appLinks = AppLinks();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // Автоматическое обновление токена перед истечением
        autoRefreshToken: true,
      ),
    );

    // Слушаем события авторизации для логирования
    client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('[Supabase] Auth event: $event');
    });

    // Настраиваем обработку deep links
    _setupDeepLinkHandler();
  }

  /// Настройка обработчика deep links
  static void _setupDeepLinkHandler() {
    // Обработка ссылки при запуске приложения (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[Supabase] Initial deep link: $uri');
        _handleDeepLink(uri);
      }
    });

    // Обработка ссылок когда приложение уже запущено
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[Supabase] Incoming deep link: $uri');
      _handleDeepLink(uri);
    });
  }

  /// Обработка deep link для авторизации
  static Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[Supabase] Handling deep link: $uri');

    // Проверяем, что это наша схема
    if (uri.scheme == authCallbackScheme) {
      try {
        // Supabase автоматически обработает сессию из URI
        final response = await client.auth.getSessionFromUrl(uri);
        debugPrint('[Supabase] Session from URL: ${response.session.user.email}');
      } catch (e) {
        debugPrint('[Supabase] Error handling deep link: $e');
      }
    }
  }

  /// Попытка восстановить сессию (вызывать при ошибках авторизации)
  static Future<bool> tryRecoverSession() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) {
        debugPrint('[Supabase] No session to recover');
        return false;
      }

      // Принудительно обновляем токен
      await client.auth.refreshSession();
      debugPrint('[Supabase] Session recovered successfully');
      return true;
    } catch (e) {
      debugPrint('[Supabase] Failed to recover session: $e');
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}
