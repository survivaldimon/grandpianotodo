import 'package:supabase_flutter/supabase_flutter.dart';

/// Конфигурация Supabase
class SupabaseConfig {
  static const String supabaseUrl = 'https://ncfpxetzmeeqxgqidosj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jZnB4ZXR6bWVlcXhncWlkb3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTk4NDEsImV4cCI6MjA4MTc5NTg0MX0.lNmvsQc5e6VvN_hbnhfzdz3Y7FhpiRNockXiXqGJ7vQ';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}
