import 'package:flutter/material.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Виджет отображения ошибки с кнопкой повтора
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorView({
    super.key,
    this.message = AppStrings.errorOccurred,
    this.onRetry,
    this.compact = false,
  });

  /// Фабричный конструктор для AsyncValue ошибок
  /// Автоматически определяет тип ошибки и показывает user-friendly сообщение
  factory ErrorView.fromException(
    Object error, {
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    final message = getUserFriendlyMessage(error);
    return ErrorView(
      message: message,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Компактный виджет для inline ошибок (без иконки и кнопки)
  factory ErrorView.inline(Object error) {
    return ErrorView(
      message: getUserFriendlyMessage(error),
      compact: true,
    );
  }

  /// Получить user-friendly сообщение из исключения
  /// Используется для SnackBar и других мест где нужно показать ошибку
  static String getUserFriendlyMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    // Ошибки сети и Realtime
    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('no address associated') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection reset') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('websocketchannelexception') ||
        errorStr.contains('realtimesubscribeexception') ||
        errorStr.contains('channelerror')) {
      return AppStrings.networkError;
    }

    // Таймаут
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Превышено время ожидания. Попробуйте ещё раз.';
    }

    // Ошибки авторизации
    if (errorStr.contains('unauthorized') ||
        errorStr.contains('unauthenticated') ||
        errorStr.contains('jwt expired')) {
      return 'Сессия истекла. Войдите заново.';
    }

    // По умолчанию - общая ошибка
    return AppStrings.errorOccurred;
  }

  @override
  Widget build(BuildContext context) {
    // Компактный режим - только текст
    if (compact) {
      return Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
