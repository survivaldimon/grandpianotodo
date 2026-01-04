import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/config/supabase_config.dart';
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

  WidgetRef? _ref;
  String? _currentInstitutionId;
  DateTime? _pausedAt;
  bool _isInitialized = false;

  /// Время в фоне, после которого нужно обновить данные (30 секунд)
  static const _refreshThreshold = Duration(seconds: 30);

  /// Инициализация сервиса
  void initialize(WidgetRef ref) {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _ref = ref;
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
    _ref = null;
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
  Future<void> _handleResume() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;

    // Проверяем, было ли приложение в фоне достаточно долго
    final wasInBackgroundLongEnough = pausedAt != null &&
        DateTime.now().difference(pausedAt) > _refreshThreshold;

    if (!wasInBackgroundLongEnough) {
      debugPrint('[AppLifecycle] Was in background < ${_refreshThreshold.inSeconds}s, skipping refresh');
      return;
    }

    debugPrint('[AppLifecycle] Was in background > ${_refreshThreshold.inSeconds}s, refreshing...');

    // 1. Обновляем сессию Supabase
    await _refreshSupabaseSession();

    // 2. Инвалидируем ключевые провайдеры
    _invalidateProviders();
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

  /// Инвалидация ключевых провайдеров
  void _invalidateProviders() {
    final ref = _ref;
    final institutionId = _currentInstitutionId;

    if (ref == null) {
      debugPrint('[AppLifecycle] No ref available for invalidation');
      return;
    }

    debugPrint('[AppLifecycle] Invalidating providers for institution: $institutionId');

    // Используем отложенную инвалидацию чтобы не блокировать UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doInvalidate(ref, institutionId);
    });
  }

  void _doInvalidate(WidgetRef ref, String? institutionId) {
    // Импортируем провайдеры динамически через invalidate
    // Это работает потому что invalidate принимает ProviderOrFamily

    if (institutionId != null) {
      // Инвалидируем провайдеры, зависящие от institutionId
      // Используем строковые ключи для избежания циклических импортов
      _invalidateInstitutionProviders(ref, institutionId);
    }

    debugPrint('[AppLifecycle] Providers invalidated');
  }

  void _invalidateInstitutionProviders(WidgetRef ref, String institutionId) {
    // Этот метод будет вызван из MainShell с доступом к провайдерам
    _onRefreshNeeded?.call(institutionId);
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
