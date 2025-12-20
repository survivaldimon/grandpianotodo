import 'package:kabinet/core/constants/app_strings.dart';

/// Валидаторы форм
class Validators {
  Validators._();

  /// Email валидатор
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppStrings.invalidEmail;
    }
    return null;
  }

  /// Пароль валидатор (минимум 8 символов)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.length < 8) {
      return AppStrings.minPasswordLength;
    }
    return null;
  }

  /// Подтверждение пароля
  static String? Function(String?) confirmPassword(String password) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return AppStrings.fieldRequired;
      }
      if (value != password) {
        return AppStrings.passwordsDoNotMatch;
      }
      return null;
    };
  }

  /// Обязательное поле
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    return null;
  }

  /// Телефон (опционально)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Телефон не обязателен
    }
    // Простая проверка на цифры и допустимые символы
    final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]+$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Некорректный номер телефона';
    }
    return null;
  }

  /// Положительное число
  static String? positiveNumber(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    final number = double.tryParse(value);
    if (number == null || number <= 0) {
      return 'Введите положительное число';
    }
    return null;
  }

  /// Целое положительное число
  static String? positiveInteger(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return 'Введите целое положительное число';
    }
    return null;
  }
}
