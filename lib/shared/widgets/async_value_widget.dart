import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/services/app_lifecycle_service.dart';
import 'package:kabinet/core/theme/app_colors.dart';

/// Виджет для отображения AsyncValue с graceful error handling
///
/// Вместо показа ошибки предлагает кнопку "Повторить"
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final String? errorMessage;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const LoadingIndicator(),
      error: (error, stack) => ErrorRetryWidget(
        error: error,
        onRetry: onRetry,
        message: errorMessage,
      ),
    );
  }
}

/// Виджет для отображения списков из AsyncValue с поддержкой pull-to-refresh
class AsyncValueSliverWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? errorMessage;

  const AsyncValueSliverWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const SliverFillRemaining(
        child: LoadingIndicator(),
      ),
      error: (error, stack) => SliverFillRemaining(
        child: ErrorRetryWidget(
          error: error,
          onRetry: onRetry,
          message: errorMessage,
        ),
      ),
    );
  }
}

/// Индикатор загрузки
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Виджет ошибки с кнопкой "Повторить"
class ErrorRetryWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? message;

  const ErrorRetryWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем тип ошибки и сообщение
    final errorMessage = _getErrorMessage();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isConnectionError ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _isConnectionError
                  ? 'Нет соединения с сервером'
                  : 'Произошла ошибка',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (onRetry != null) {
                  onRetry!();
                } else {
                  // Принудительное обновление через сервис
                  AppLifecycleService.instance.forceRefresh();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isConnectionError {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('host') ||
        errorStr.contains('failed host lookup');
  }

  String _getErrorMessage() {
    final errorStr = error.toString();

    if (_isConnectionError) {
      return 'Проверьте подключение к интернету и попробуйте снова';
    }

    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Недостаточно прав для выполнения операции';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Данные не найдены';
    }

    // Для debug — показываем реальную ошибку
    return 'Попробуйте обновить данные';
  }
}

/// Extension для упрощённого использования AsyncValue
extension AsyncValueX<T> on AsyncValue<T> {
  /// Показать данные или placeholder при загрузке/ошибке
  Widget whenDataOrPlaceholder({
    required Widget Function(T data) data,
    required Widget placeholder,
  }) {
    return when(
      data: data,
      loading: () => placeholder,
      error: (_, __) => placeholder,
    );
  }

  /// Показать данные, loading или ошибку с кнопкой повторить
  Widget whenWithRetry({
    required Widget Function(T data) data,
    Widget? loading,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    return AsyncValueWidget(
      value: this,
      data: data,
      loading: loading,
      onRetry: onRetry,
      errorMessage: errorMessage,
    );
  }
}
