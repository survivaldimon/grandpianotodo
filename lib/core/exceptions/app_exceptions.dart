import 'package:kabinet/core/constants/app_strings.dart';

/// Базовый класс исключений приложения
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  /// Сообщение для пользователя
  String get userMessage => message;

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Ошибка сети
class NetworkException extends AppException {
  const NetworkException([super.message = AppStrings.networkError]);
}

/// Ошибка базы данных
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});

  @override
  String get userMessage => AppStrings.errorOccurred;
}

/// Ошибка аутентификации (renamed to avoid conflict with Supabase AuthException)
class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.code});

  @override
  String get userMessage {
    switch (code) {
      case 'invalid_credentials':
        return AppStrings.invalidCredentials;
      case 'email_in_use':
        return AppStrings.emailInUse;
      case 'weak_password':
        return AppStrings.weakPassword;
      default:
        return message;
    }
  }
}

/// Ошибка валидации
class ValidationException extends AppException {
  final String? field;

  const ValidationException(super.message, {this.field});

  @override
  String get userMessage => message;
}

/// Ошибка прав доступа
class PermissionException extends AppException {
  const PermissionException([super.message = 'Недостаточно прав']);
}

/// Неизвестная ошибка
class UnknownException extends AppException {
  const UnknownException([super.message = AppStrings.unknownError]);

  @override
  String get userMessage => AppStrings.unknownError;
}
