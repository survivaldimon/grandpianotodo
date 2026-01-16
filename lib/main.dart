import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kabinet/core/cache/cache_service.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/theme/theme_provider.dart';
import 'package:kabinet/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локали для дат
  await initializeDateFormatting('ru', null);

  // Инициализация Hive кэша (Telegram/Instagram-style offline support)
  await CacheService.initialize();

  // Инициализация Supabase
  await SupabaseConfig.initialize();

  // Инициализация SharedPreferences для темы
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KabinetApp(),
    ),
  );
}
