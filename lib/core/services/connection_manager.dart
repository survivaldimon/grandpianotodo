import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';

/// Состояние соединения приложения
/// Используем AppConnectionState чтобы избежать конфликта с Flutter ConnectionState
enum AppConnectionState {
  /// Соединение установлено и работает
  connected,

  /// Идёт подключение / восстановление
  connecting,

  /// Нет соединения с интернетом
  offline,

  /// Есть интернет, но сервер недоступен
  serverUnavailable,
}

/// Централизованный менеджер соединения
/// Работает как в топовых приложениях (Instagram, Telegram, WhatsApp)
///
/// Функции:
/// - Мониторинг состояния сети (WiFi/Mobile/Offline)
/// - Автоматическое переподключение при восстановлении сети
/// - Проверка доступности сервера
/// - Уведомление UI о состоянии соединения
class ConnectionManager {
  static ConnectionManager? _instance;
  static ConnectionManager get instance => _instance ??= ConnectionManager._();

  ConnectionManager._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Текущее состояние соединения
  final _stateController = StreamController<AppConnectionState>.broadcast();
  Stream<AppConnectionState> get stateStream => _stateController.stream;

  AppConnectionState _currentState = AppConnectionState.connecting;
  AppConnectionState get currentState => _currentState;

  /// Callback для переподключения всех streams
  void Function()? _onReconnectNeeded;

  /// Флаг инициализации
  bool _isInitialized = false;

  /// Таймер для периодической проверки сервера
  Timer? _healthCheckTimer;

  /// Интервал проверки здоровья сервера (30 секунд)
  static const _healthCheckInterval = Duration(seconds: 30);

  /// Таймаут для проверки сервера
  static const _serverCheckTimeout = Duration(seconds: 5);

  /// Инициализация менеджера
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    debugPrint('[ConnectionManager] Initializing...');

    // Проверяем начальное состояние сети
    await _checkInitialConnectivity();

    // Подписываемся на изменения состояния сети
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (e) => debugPrint('[ConnectionManager] Connectivity error: $e'),
    );

    // Запускаем периодическую проверку сервера
    _startHealthCheck();

    debugPrint('[ConnectionManager] Initialized, state: $_currentState');
  }

  /// Установить callback для переподключения
  void setReconnectCallback(void Function() callback) {
    _onReconnectNeeded = callback;
  }

  /// Проверка начального состояния сети
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);

      if (!hasNetwork) {
        _updateState(AppConnectionState.offline);
        return;
      }

      // Есть сеть — проверяем доступность сервера
      _updateState(AppConnectionState.connecting);
      final serverAvailable = await _checkServerAvailability();

      if (serverAvailable) {
        _updateState(AppConnectionState.connected);
      } else {
        _updateState(AppConnectionState.serverUnavailable);
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Initial check error: $e');
      _updateState(AppConnectionState.offline);
    }
  }

  /// Обработка изменения состояния сети
  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    debugPrint('[ConnectionManager] Connectivity changed: $results');

    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      _updateState(AppConnectionState.offline);
      return;
    }

    // Сеть появилась — пробуем подключиться
    if (_currentState == AppConnectionState.offline ||
        _currentState == AppConnectionState.serverUnavailable) {
      _updateState(AppConnectionState.connecting);

      // Небольшая задержка перед проверкой (сеть может быть нестабильной)
      await Future.delayed(const Duration(milliseconds: 500));

      final serverAvailable = await _checkServerAvailability();

      if (serverAvailable) {
        _updateState(AppConnectionState.connected);
        _triggerReconnect();
      } else {
        _updateState(AppConnectionState.serverUnavailable);
        // Повторяем попытку через 3 секунды
        _scheduleRetry();
      }
    }
  }

  /// Проверка доступности сервера Supabase
  Future<bool> _checkServerAvailability() async {
    try {
      final client = SupabaseConfig.client;

      // Проверяем текущую сессию — если есть, значит соединение работает
      final session = client.auth.currentSession;
      if (session != null) {
        // Пробуем обновить сессию как проверку соединения
        await client.auth.refreshSession().timeout(_serverCheckTimeout);
      } else {
        // Если нет сессии — делаем простой health check через REST
        await client.from('profiles').select('id').limit(1).timeout(_serverCheckTimeout);
      }

      return true;
    } catch (e) {
      debugPrint('[ConnectionManager] Server check failed: $e');
      return false;
    }
  }

  /// Периодическая проверка здоровья соединения
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) async {
      if (_currentState == AppConnectionState.connected) {
        final available = await _checkServerAvailability();
        if (!available) {
          _updateState(AppConnectionState.serverUnavailable);
          _scheduleRetry();
        }
      } else if (_currentState == AppConnectionState.serverUnavailable) {
        // Пробуем переподключиться
        final available = await _checkServerAvailability();
        if (available) {
          _updateState(AppConnectionState.connected);
          _triggerReconnect();
        }
      }
    });
  }

  /// Отложенная повторная попытка подключения
  void _scheduleRetry() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (_currentState != AppConnectionState.connected) {
        final available = await _checkServerAvailability();
        if (available) {
          _updateState(AppConnectionState.connected);
          _triggerReconnect();
        }
      }
    });
  }

  /// Обновление состояния
  void _updateState(AppConnectionState newState) {
    if (_currentState == newState) return;

    debugPrint('[ConnectionManager] State: $_currentState -> $newState');
    _currentState = newState;

    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Инициировать переподключение всех streams
  void _triggerReconnect() {
    debugPrint('[ConnectionManager] Triggering reconnect...');

    // Обновляем сессию Supabase
    _refreshSupabaseSession();

    // Вызываем callback для переподключения
    _onReconnectNeeded?.call();
  }

  /// Обновление сессии Supabase
  Future<void> _refreshSupabaseSession() async {
    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        await SupabaseConfig.client.auth.refreshSession();
        debugPrint('[ConnectionManager] Session refreshed');
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Session refresh failed: $e');
    }
  }

  /// Принудительная проверка и переподключение
  Future<void> forceReconnect() async {
    debugPrint('[ConnectionManager] Force reconnect requested');

    _updateState(AppConnectionState.connecting);

    final results = await _connectivity.checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      _updateState(AppConnectionState.offline);
      return;
    }

    final serverAvailable = await _checkServerAvailability();

    if (serverAvailable) {
      _updateState(AppConnectionState.connected);
      _triggerReconnect();
    } else {
      _updateState(AppConnectionState.serverUnavailable);
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _connectivitySubscription?.cancel();
    _healthCheckTimer?.cancel();
    _stateController.close();
    _isInitialized = false;
    _instance = null;
    debugPrint('[ConnectionManager] Disposed');
  }
}

/// Провайдер состояния соединения (для мониторинга)
final connectionStateProvider = StreamProvider<AppConnectionState>((ref) {
  return ConnectionManager.instance.stateStream;
});

/// Провайдер: есть ли соединение
final isConnectedProvider = Provider<bool>((ref) {
  final asyncState = ref.watch(connectionStateProvider);
  final state = asyncState.valueOrNull ?? ConnectionManager.instance.currentState;
  return state == AppConnectionState.connected;
});
