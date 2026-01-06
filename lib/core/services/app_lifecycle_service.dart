import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/services/connection_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Сервис управления жизненным циклом приложения
///
/// Отвечает за:
/// - Отслеживание перехода приложения в фон и обратно
/// - Обновление сессии Supabase при возврате из фона
/// - Уведомление провайдеров о необходимости обновить данные
class AppLifecycleService with WidgetsBindingObserver {
  static AppLifecycleService? _instance;
  static AppLifecycleService get instance => _instance ??= AppLifecycleService._();

  AppLifecycleService._();

  String? _currentInstitutionId;
  DateTime? _pausedAt;
  bool _isInitialized = false;

  /// Время в фоне, после которого нужно обновить сессию (30 секунд)
  static const _refreshThreshold = Duration(seconds: 30);

  /// Инициализация сервиса
  /// ref сохранён для обратной совместимости с существующим API
  void initialize(WidgetRef ref) {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    debugPrint('[AppLifecycle] Initialized');
  }

  /// Установить текущее заведение для инвалидации провайдеров
  void setCurrentInstitution(String? institutionId) {
    _currentInstitutionId = institutionId;
  }

  /// Освобождение ресурсов
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
    _instance = null;
    debugPrint('[AppLifecycle] Disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[AppLifecycle] State changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pausedAt = DateTime.now();
        break;

      case AppLifecycleState.resumed:
        _handleResume();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Ничего не делаем
        break;
    }
  }

  /// Обработка возврата из фона
  /// ВАЖНО: ВСЕГДА переподключаем Realtime при возврате из фона
  /// Это гарантирует что WebSocket соединение работает корректно
  Future<void> _handleResume() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;

    debugPrint('[AppLifecycle] App resumed, reconnecting Realtime...');

    // 1. ВСЕГДА переподключаем Realtime при возврате из фона
    // Это закрывает старые "зависшие" WebSocket соединения и создаёт новые
    await ConnectionManager.instance.reconnectRealtime();

    // 2. Опционально обновляем сессию если в фоне достаточно долго
    if (pausedAt != null) {
      final timeInBackground = DateTime.now().difference(pausedAt);
      if (timeInBackground > _refreshThreshold) {
        debugPrint('[AppLifecycle] Was in background ${timeInBackground.inSeconds}s, refreshing session...');
        await _refreshSupabaseSession();
      }
    }
  }

  /// Обновление сессии Supabase
  Future<void> _refreshSupabaseSession() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;

      if (session == null) {
        debugPrint('[AppLifecycle] No session to refresh');
        return;
      }

      // Проверяем, не истёк ли токен или скоро истечёт
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();
        final difference = expiresAtDate.difference(now);

        // Если токен истёк или истекает в течение 10 минут — обновляем
        if (difference.inMinutes < 10) {
          debugPrint('[AppLifecycle] Token expired or expiring soon, refreshing...');
          await SupabaseConfig.tryRecoverSession();
        } else {
          debugPrint('[AppLifecycle] Token still valid for ${difference.inMinutes} min');
        }
      } else {
        // Нет информации об истечении — обновляем на всякий случай
        await SupabaseConfig.tryRecoverSession();
      }
    } catch (e) {
      debugPrint('[AppLifecycle] Error refreshing session: $e');
    }
  }

  /// Callback для уведомления о необходимости обновить данные
  void Function(String institutionId)? _onRefreshNeeded;

  /// Установить callback для обновления данных
  void setRefreshCallback(void Function(String institutionId) callback) {
    _onRefreshNeeded = callback;
  }

  /// Принудительное обновление данных (для pull-to-refresh)
  Future<void> forceRefresh() async {
    debugPrint('[AppLifecycle] Force refresh requested');
    await _refreshSupabaseSession();

    final institutionId = _currentInstitutionId;
    if (institutionId != null) {
      _onRefreshNeeded?.call(institutionId);
    }
  }
}

/// Провайдер для доступа к AppLifecycleService
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService.instance;
});
