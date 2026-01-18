import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefKey = 'theme_mode';

/// Провайдер SharedPreferences (инициализируется в main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences не инициализирован. Вызовите override в main()');
});

/// Текущий режим темы
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

/// Notifier для управления темой
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_loadInitial(_prefs));

  /// Загрузить сохранённую тему
  static ThemeMode _loadInitial(SharedPreferences prefs) {
    final value = prefs.getString(_themePrefKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Установить режим темы
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themePrefKey, value);
  }
}

/// Получить локализованное название темы
String getThemeModeLabel(ThemeMode mode, AppLocalizations l10n) {
  return switch (mode) {
    ThemeMode.system => l10n.themeSystem,
    ThemeMode.dark => l10n.themeDark,
    ThemeMode.light => l10n.themeLight,
  };
}
