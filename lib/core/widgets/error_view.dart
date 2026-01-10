import 'package:flutter/material.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/services/app_lifecycle_service.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Виджет отображения ошибки с кнопкой повтора
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool compact;
  final bool showRetryButton;

  const ErrorView({
    super.key,
    this.message = AppStrings.errorOccurred,
    this.onRetry,
    this.compact = false,
    this.showRetryButton = true,
  });

  /// Фабричный конструктор для AsyncValue ошибок
  /// Автоматически определяет тип ошибки и показывает user-friendly сообщение
  /// Если onRetry не передан, используется AppLifecycleService.forceRefresh()
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
      showRetryButton: true, // Всегда показываем кнопку retry
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

    // Конфликт времени (кабинет занят)
    if (errorStr.contains('кабинет занят') ||
        errorStr.contains('занят в это время')) {
      return 'Кабинет занят в это время';
    }

    // Если это Exception с кастомным сообщением — извлекаем его
    if (error is Exception) {
      final message = error.toString();
      // Exception: message -> извлекаем message
      if (message.startsWith('Exception: ')) {
        final customMessage = message.substring('Exception: '.length);
        // Возвращаем кастомное сообщение если оно не пустое и на кириллице
        if (customMessage.isNotEmpty && RegExp(r'[а-яА-ЯёЁ]').hasMatch(customMessage)) {
          return customMessage;
        }
      }
    }

    // По умолчанию - общая ошибка
    return AppStrings.errorOccurred;
  }

  /// Определяет, является ли ошибка проблемой с сетью
  bool get _isConnectionError {
    final msgLower = message.toLowerCase();
    return msgLower.contains('сеть') ||
        msgLower.contains('соединен') ||
        msgLower.contains('интернет') ||
        msgLower.contains('подключ') ||
        message == AppStrings.networkError;
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
            Icon(
              _isConnectionError ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: _isConnectionError ? AppColors.textSecondary : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _isConnectionError ? 'Нет соединения с сервером' : 'Произошла ошибка',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (showRetryButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // Сначала пробуем восстановить сессию (на случай истёкшего токена)
                  await SupabaseConfig.tryRecoverSession();

                  if (onRetry != null) {
                    onRetry!();
                  } else {
                    // Используем глобальное обновление через сервис
                    AppLifecycleService.instance.forceRefresh();
                  }
                },
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
