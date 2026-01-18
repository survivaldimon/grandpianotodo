import 'package:kabinet/l10n/app_localizations.dart';

/// Валидаторы форм с локализацией
class Validators {
  Validators._();

  /// Email валидатор
  static String? Function(String?) email(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return l10n.fieldRequired;
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return l10n.invalidEmail;
      }
      return null;
    };
  }

  /// Пароль валидатор
  /// - Минимум 8 символов
  /// - Хотя бы одна заглавная буква
  /// - Хотя бы один спецсимвол (!@#$%^&* и т.д.)
  static String? Function(String?) password(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return l10n.fieldRequired;
      }
      if (value.length < 8) {
        return l10n.minPasswordLength;
      }
      // Проверка на заглавную букву
      if (!RegExp(r'[A-ZА-ЯЁ]').hasMatch(value)) {
        return l10n.passwordNeedsUppercase;
      }
      // Проверка на спецсимвол
      if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]').hasMatch(value)) {
        return l10n.passwordNeedsSpecialChar;
      }
      return null;
    };
  }

  /// Подтверждение пароля
  static String? Function(String?) confirmPassword(
    AppLocalizations l10n,
    String password,
  ) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return l10n.fieldRequired;
      }
      if (value != password) {
        return l10n.passwordsDoNotMatch;
      }
      return null;
    };
  }

  /// Обязательное поле
  static String? Function(String?) required(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return l10n.fieldRequired;
      }
      return null;
    };
  }

  /// Телефон (опционально)
  static String? Function(String?) phone(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null; // Телефон не обязателен
      }
      // Простая проверка на цифры и допустимые символы
      final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]+$');
      if (!phoneRegex.hasMatch(value)) {
        return l10n.invalidPhoneNumber;
      }
      return null;
    };
  }

  /// Положительное число
  static String? Function(String?) positiveNumber(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return l10n.fieldRequired;
      }
      final number = double.tryParse(value);
      if (number == null || number <= 0) {
        return l10n.enterPositiveNumber;
      }
      return null;
    };
  }

  /// Целое положительное число
  static String? Function(String?) positiveInteger(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return l10n.fieldRequired;
      }
      final number = int.tryParse(value);
      if (number == null || number <= 0) {
        return l10n.enterPositiveInteger;
      }
      return null;
    };
  }
}
