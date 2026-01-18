import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kabinet/core/theme/theme_provider.dart';

const _localePrefKey = 'app_locale';

/// Поддерживаемые локали приложения
enum AppLocale {
  system, // Как в системе
  ru, // Русский
  en, // English
}

extension AppLocaleX on AppLocale {
  /// Отображаемое название языка
  String get label => switch (this) {
        AppLocale.system => 'Как в системе',
        AppLocale.ru => 'Русский',
        AppLocale.en => 'English',
      };

  /// Название на английском (для настроек)
  String get labelEn => switch (this) {
        AppLocale.system => 'System',
        AppLocale.ru => 'Russian',
        AppLocale.en => 'English',
      };

  /// Конвертация в Locale (null для system)
  Locale? toLocale() => switch (this) {
        AppLocale.system => null,
        AppLocale.ru => const Locale('ru', 'RU'),
        AppLocale.en => const Locale('en', 'US'),
      };
}

/// Провайдер текущей локали приложения
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

/// Notifier для управления локалью
class LocaleNotifier extends StateNotifier<AppLocale> {
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs) : super(_loadInitial(_prefs));

  /// Загрузить сохранённую локаль
  static AppLocale _loadInitial(SharedPreferences prefs) {
    final value = prefs.getString(_localePrefKey);
    return switch (value) {
      'ru' => AppLocale.ru,
      'en' => AppLocale.en,
      _ => AppLocale.system,
    };
  }

  /// Установить локаль
  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final value = switch (locale) {
      AppLocale.system => 'system',
      AppLocale.ru => 'ru',
      AppLocale.en => 'en',
    };
    await _prefs.setString(_localePrefKey, value);
  }
}

/// Получить фактическую локаль с учетом системных настроек
Locale resolveLocale(AppLocale appLocale) {
  if (appLocale == AppLocale.system) {
    // Определяем системную локаль
    final systemLocale = PlatformDispatcher.instance.locale;
    // Проверяем, поддерживается ли она
    if (systemLocale.languageCode == 'en') {
      return const Locale('en', 'US');
    }
    // Fallback на русский для всех остальных языков
    return const Locale('ru', 'RU');
  }
  return appLocale.toLocale()!;
}

/// Провайдер строки локали для DateFormat
final dateLocaleProvider = Provider<String>((ref) {
  final appLocale = ref.watch(localeProvider);
  final resolved = resolveLocale(appLocale);
  return resolved.languageCode;
});
