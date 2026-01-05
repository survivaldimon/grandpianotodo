import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kabinet/core/services/connection_manager.dart'
    show AppConnectionState, ConnectionManager;

/// Helper для создания надёжных Realtime streams с автоматическим retry
///
/// Интегрирован с ConnectionManager для:
/// - Проверки состояния соединения при ошибках
/// - Координации с централизованным управлением соединением
class RealtimeStreamHelper {
  /// Максимальное количество попыток переподключения
  static const int maxRetries = 3;

  /// Начальная задержка между retry (в миллисекундах)
  static const int initialRetryDelay = 1000;

  /// Создаёт надёжный stream с автоматическим retry при ошибках
  ///
  /// Логика:
  /// 1. Сразу выдаёт данные через fallback (быстрый первый рендер)
  /// 2. Подключается к realtime stream
  /// 3. При ошибках — retry с exponential backoff
  /// 4. Если нет соединения — ждёт reconnect от ConnectionManager
  static Stream<T> createResilientStream<T>({
    required Stream<T> Function() streamFactory,
    required Future<T> Function() fallbackFetch,
    void Function(Object error)? onError,
  }) async* {
    int retryCount = 0;
    final connectionManager = ConnectionManager.instance;

    // 1. Сразу выдаём данные через fallback (быстрый первый рендер)
    try {
      final initialData = await fallbackFetch();
      yield initialData;
    } catch (e) {
      debugPrint('[RealtimeStream] Initial fetch failed: $e');
      // Продолжаем — попробуем через stream
    }

    // 2. Подключаемся к realtime stream с retry
    while (retryCount <= maxRetries) {
      try {
        await for (final data in streamFactory()) {
          retryCount = 0; // Сброс счётчика при успешном получении данных
          yield data;
        }
        // Stream завершился нормально
        break;
      } catch (e, st) {
        onError?.call(e);
        debugPrint('[RealtimeStream] Stream error: $e');

        // Если нет соединения — не делаем retry, ждём reconnect от ConnectionManager
        if (connectionManager.currentState == AppConnectionState.offline ||
            connectionManager.currentState == AppConnectionState.serverUnavailable) {
          debugPrint('[RealtimeStream] No connection, waiting for reconnect...');
          // Выдаём последние данные через fallback и выходим
          // ConnectionManager переподключит все streams когда соединение восстановится
          try {
            yield await fallbackFetch();
          } catch (_) {}
          return;
        }

        retryCount++;
        if (retryCount > maxRetries) {
          debugPrint('[RealtimeStream] Max retries reached');
          // Пробуем fallback в последний раз
          try {
            yield await fallbackFetch();
          } catch (fallbackError) {
            Error.throwWithStackTrace(e, st);
          }
          break;
        }

        // Exponential backoff с jitter
        final baseDelay = initialRetryDelay * (1 << (retryCount - 1));
        final jitter = (baseDelay * 0.2 * (DateTime.now().millisecond % 100) / 100).toInt();
        final delay = baseDelay + jitter;

        debugPrint('[RealtimeStream] Retry in ${delay}ms (attempt $retryCount/$maxRetries)');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }
}
