/// Базовый класс исключений приложения
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Ошибка сети
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error']);
}

/// Ошибка базы данных
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
}

/// Ошибка аутентификации (renamed to avoid conflict with Supabase AuthException)
class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.code});
}

/// Ошибка валидации
class ValidationException extends AppException {
  final String? field;

  const ValidationException(super.message, {this.field});
}

/// Ошибка прав доступа
class PermissionException extends AppException {
  const PermissionException([super.message = 'Permission denied']);
}

/// Неизвестная ошибка
class UnknownException extends AppException {
  const UnknownException([super.message = 'Unknown error']);
}
