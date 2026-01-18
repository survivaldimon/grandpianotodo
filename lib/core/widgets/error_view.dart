import 'package:flutter/material.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/services/app_lifecycle_service.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Тип ошибки для определения локализованного сообщения
enum ErrorType {
  network,
  timeout,
  sessionExpired,
  roomOccupied,
  custom,
  unknown,
}

/// Виджет отображения ошибки с кнопкой повтора
class ErrorView extends StatelessWidget {
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;
  final bool showRetryButton;

  const ErrorView({
    super.key,
    this.message,
    this.error,
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
    return ErrorView(
      error: error,
      onRetry: onRetry,
      compact: compact,
      showRetryButton: true,
    );
  }

  /// Компактный виджет для inline ошибок (без иконки и кнопки)
  factory ErrorView.inline(Object error) {
    return ErrorView(
      error: error,
      compact: true,
    );
  }

  /// Определяет тип ошибки
  static ErrorType getErrorType(Object error) {
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
      return ErrorType.network;
    }

    // Таймаут
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return ErrorType.timeout;
    }

    // Ошибки авторизации
    if (errorStr.contains('unauthorized') ||
        errorStr.contains('unauthenticated') ||
        errorStr.contains('jwt expired')) {
      return ErrorType.sessionExpired;
    }

    // Конфликт времени (кабинет занят)
    if (errorStr.contains('кабинет занят') ||
        errorStr.contains('занят в это время') ||
        errorStr.contains('room occupied') ||
        errorStr.contains('room is occupied')) {
      return ErrorType.roomOccupied;
    }

    // Если это Exception с кастомным сообщением
    if (error is Exception) {
      final message = error.toString();
      if (message.startsWith('Exception: ')) {
        final customMessage = message.substring('Exception: '.length);
        if (customMessage.isNotEmpty) {
          return ErrorType.custom;
        }
      }
    }

    return ErrorType.unknown;
  }

  /// Получить кастомное сообщение из Exception
  static String? getCustomMessage(Object error) {
    if (error is Exception) {
      final message = error.toString();
      if (message.startsWith('Exception: ')) {
        final customMessage = message.substring('Exception: '.length);
        if (customMessage.isNotEmpty) {
          return customMessage;
        }
      }
    }
    return null;
  }

  /// Получить локализованное сообщение об ошибке
  static String getLocalizedErrorMessage(Object error, AppLocalizations l10n) {
    final errorType = getErrorType(error);

    switch (errorType) {
      case ErrorType.network:
        return l10n.networkErrorMessage;
      case ErrorType.timeout:
        return l10n.timeoutErrorMessage;
      case ErrorType.sessionExpired:
        return l10n.sessionExpiredMessage;
      case ErrorType.roomOccupied:
        return l10n.roomOccupied;
      case ErrorType.custom:
        return getCustomMessage(error) ?? l10n.errorOccurredMessage;
      case ErrorType.unknown:
        return l10n.errorOccurredMessage;
    }
  }

  /// Получить user-friendly сообщение из исключения (без локализации - fallback на русский)
  /// Используется когда нет доступа к context
  static String getUserFriendlyMessage(Object error) {
    final errorType = getErrorType(error);

    switch (errorType) {
      case ErrorType.network:
        return 'Ошибка сети. Проверьте подключение к интернету.';
      case ErrorType.timeout:
        return 'Превышено время ожидания. Попробуйте ещё раз.';
      case ErrorType.sessionExpired:
        return 'Сессия истекла. Войдите заново.';
      case ErrorType.roomOccupied:
        return 'Кабинет занят в это время';
      case ErrorType.custom:
        return getCustomMessage(error) ?? 'Произошла ошибка';
      case ErrorType.unknown:
        return 'Произошла ошибка';
    }
  }

  /// Определяет, является ли ошибка проблемой с сетью
  bool _isConnectionError(String displayMessage) {
    final msgLower = displayMessage.toLowerCase();
    return msgLower.contains('сеть') ||
        msgLower.contains('network') ||
        msgLower.contains('соединен') ||
        msgLower.contains('connection') ||
        msgLower.contains('интернет') ||
        msgLower.contains('подключ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Приоритет: явное message > локализованное из error > fallback
    final displayMessage = message ??
        (error != null ? getLocalizedErrorMessage(error!, l10n) : l10n.errorOccurred);

    // Компактный режим - только текст
    if (compact) {
      return Text(
        displayMessage,
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }

    final isConnectionErr = _isConnectionError(displayMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnectionErr ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: isConnectionErr ? AppColors.textSecondary : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              isConnectionErr ? l10n.noServerConnection : l10n.errorOccurredTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
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
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
