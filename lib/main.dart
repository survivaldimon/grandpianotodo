import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локали для дат
  await initializeDateFormatting('ru', null);

  // Инициализация Supabase
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: KabinetApp(),
    ),
  );
}
