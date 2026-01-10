import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kabinet/core/theme/theme_provider.dart';

const _phoneCountryCodeKey = 'phone_country_code';

/// Доступные коды стран для телефона
enum PhoneCountryCode {
  auto('auto', 'Автоматически', ''),
  kz('+7', 'Казахстан', '+7'),
  ru('+7', 'Россия', '+7'),
  uz('+998', 'Узбекистан', '+998'),
  kg('+996', 'Кыргызстан', '+996'),
  by('+375', 'Беларусь', '+375'),
  ua('+380', 'Украина', '+380'),
  none('none', 'Без кода', '');

  final String code;
  final String label;
  final String prefix;

  const PhoneCountryCode(this.code, this.label, this.prefix);

  /// Получить код для сохранения в настройках
  String get settingsValue => name;

  /// Получить отображаемое название с кодом
  String get displayLabel {
    if (this == auto) return label;
    if (this == none) return label;
    return '$label ($code)';
  }
}

/// Провайдер настройки кода страны для телефона
final phoneCountryCodeProvider =
    StateNotifierProvider<PhoneCountryCodeNotifier, PhoneCountryCode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PhoneCountryCodeNotifier(prefs);
});

/// Notifier для управления кодом страны
class PhoneCountryCodeNotifier extends StateNotifier<PhoneCountryCode> {
  final SharedPreferences _prefs;

  PhoneCountryCodeNotifier(this._prefs) : super(_loadInitial(_prefs));

  /// Загрузить сохранённую настройку
  static PhoneCountryCode _loadInitial(SharedPreferences prefs) {
    final value = prefs.getString(_phoneCountryCodeKey);
    if (value == null) return PhoneCountryCode.auto;

    return PhoneCountryCode.values.firstWhere(
      (c) => c.settingsValue == value,
      orElse: () => PhoneCountryCode.auto,
    );
  }

  /// Установить код страны
  Future<void> setCountryCode(PhoneCountryCode code) async {
    state = code;
    await _prefs.setString(_phoneCountryCodeKey, code.settingsValue);
  }
}

/// Провайдер префикса телефона (с учётом автоопределения)
final phoneDefaultPrefixProvider = Provider<String>((ref) {
  final setting = ref.watch(phoneCountryCodeProvider);

  if (setting == PhoneCountryCode.auto) {
    return _detectCountryPrefix();
  }

  return setting.prefix;
});

/// Определение кода страны по локали устройства
String _detectCountryPrefix() {
  try {
    final locale = Platform.localeName; // например: "ru_KZ", "ru_RU", "en_US"
    final parts = locale.split('_');
    final countryCode = parts.length > 1 ? parts[1].toUpperCase() : '';

    return switch (countryCode) {
      'KZ' => '+7',
      'RU' => '+7',
      'UZ' => '+998',
      'KG' => '+996',
      'BY' => '+375',
      'UA' => '+380',
      _ => '+7', // По умолчанию Казахстан/Россия
    };
  } catch (_) {
    return '+7'; // Fallback
  }
}
