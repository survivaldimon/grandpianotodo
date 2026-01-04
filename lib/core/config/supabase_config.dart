import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Конфигурация Supabase
class SupabaseConfig {
  static const String supabaseUrl = 'https://ncfpxetzmeeqxgqidosj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jZnB4ZXR6bWVlcXhncWlkb3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTk4NDEsImV4cCI6MjA4MTc5NTg0MX0.lNmvsQc5e6VvN_hbnhfzdz3Y7FhpiRNockXiXqGJ7vQ';

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
