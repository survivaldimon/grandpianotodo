import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Сервис кэширования данных (Telegram/Instagram-style)
///
/// Использует Hive для персистентного хранения.
/// Данные хранятся как JSON строки для простоты (без TypeAdapters).
class CacheService {
  CacheService._();

  static const String _boxName = 'kabinet_cache';
  static const String _metaBoxName = 'kabinet_meta';

  static Box<String>? _cacheBox;
  static Box<String>? _metaBox;

  static bool _initialized = false;

  /// Инициализация Hive
  ///
  /// Вызывать в main() перед runApp()
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      _cacheBox = await Hive.openBox<String>(_boxName);
      _metaBox = await Hive.openBox<String>(_metaBoxName);

      _initialized = true;
      debugPrint('[CacheService] Initialized successfully');
    } catch (e) {
      debugPrint('[CacheService] Initialization failed: $e');
      // Продолжаем без кэша — приложение будет работать через сеть
    }
  }

  /// Проверка готовности кэша
  static bool get isReady => _initialized && _cacheBox != null;

  // === CRUD операции ===

  /// Сохранить данные в кэш
  ///
  /// [key] — ключ из CacheKeys
  /// [data] — данные (должны быть JSON-сериализуемыми)
  /// [ttlMinutes] — время жизни в минутах (по умолчанию 60)
  static Future<void> put<T>(
    String key,
    T data, {
    int ttlMinutes = 60,
  }) async {
    if (!isReady) return;

    try {
      final jsonString = jsonEncode(data);
      await _cacheBox!.put(key, jsonString);

      // Сохраняем метаданные: время записи и TTL
      final meta = {
        'savedAt': DateTime.now().toIso8601String(),
        'ttlMinutes': ttlMinutes,
      };
      await _metaBox!.put(key, jsonEncode(meta));

      debugPrint('[CacheService] Saved: $key (${jsonString.length} chars)');
    } catch (e) {
      debugPrint('[CacheService] Put failed for $key: $e');
    }
  }

  /// Получить данные из кэша
  ///
  /// Возвращает null если:
  /// - Кэш не инициализирован
  /// - Данных нет
  /// - TTL истёк
  /// - Ошибка десериализации
  static T? get<T>(String key) {
    if (!isReady) return null;

    try {
      final jsonString = _cacheBox!.get(key);
      if (jsonString == null) return null;

      // Проверяем TTL
      if (_isExpired(key)) {
        debugPrint('[CacheService] Expired: $key');
        // Удаляем просроченные данные асинхронно
        delete(key);
        return null;
      }

      final decoded = jsonDecode(jsonString);
      debugPrint('[CacheService] Hit: $key');
      return decoded as T;
    } catch (e) {
      debugPrint('[CacheService] Get failed for $key: $e');
      return null;
    }
  }

  /// Получить данные без проверки TTL (stale-while-revalidate)
  ///
  /// Полезно когда хотим показать устаревшие данные пока загружаются свежие
  static T? getStale<T>(String key) {
    if (!isReady) return null;

    try {
      final jsonString = _cacheBox!.get(key);
      if (jsonString == null) return null;

      final decoded = jsonDecode(jsonString);
      debugPrint('[CacheService] Stale hit: $key');
      return decoded as T;
    } catch (e) {
      debugPrint('[CacheService] GetStale failed for $key: $e');
      return null;
    }
  }

  /// Удалить данные из кэша
  static Future<void> delete(String key) async {
    if (!isReady) return;

    try {
      await _cacheBox!.delete(key);
      await _metaBox!.delete(key);
      debugPrint('[CacheService] Deleted: $key');
    } catch (e) {
      debugPrint('[CacheService] Delete failed for $key: $e');
    }
  }

  /// Очистить весь кэш для заведения
  ///
  /// Вызывать при смене заведения или logout
  static Future<void> clearForInstitution(String institutionId) async {
    if (!isReady) return;

    try {
      final keysToDelete = _cacheBox!.keys
          .where((key) => key.toString().contains(institutionId))
          .toList();

      for (final key in keysToDelete) {
        await _cacheBox!.delete(key);
        await _metaBox!.delete(key);
      }

      debugPrint('[CacheService] Cleared ${keysToDelete.length} entries for: $institutionId');
    } catch (e) {
      debugPrint('[CacheService] ClearForInstitution failed: $e');
    }
  }

  /// Полная очистка кэша
  ///
  /// Вызывать при logout или критических ошибках
  static Future<void> clearAll() async {
    if (!isReady) return;

    try {
      await _cacheBox!.clear();
      await _metaBox!.clear();
      debugPrint('[CacheService] Cleared all cache');
    } catch (e) {
      debugPrint('[CacheService] ClearAll failed: $e');
    }
  }

  // === Утилиты ===

  /// Проверка истёк ли TTL для ключа
  static bool _isExpired(String key) {
    try {
      final metaJson = _metaBox!.get(key);
      if (metaJson == null) return true;

      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      final savedAt = DateTime.parse(meta['savedAt'] as String);
      final ttlMinutes = meta['ttlMinutes'] as int? ?? 60;

      final expiresAt = savedAt.add(Duration(minutes: ttlMinutes));
      return DateTime.now().isAfter(expiresAt);
    } catch (e) {
      return true; // При ошибке считаем данные устаревшими
    }
  }

  /// Возраст данных в минутах
  static int? getAgeMinutes(String key) {
    try {
      final metaJson = _metaBox?.get(key);
      if (metaJson == null) return null;

      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      final savedAt = DateTime.parse(meta['savedAt'] as String);

      return DateTime.now().difference(savedAt).inMinutes;
    } catch (e) {
      return null;
    }
  }

  /// Статистика кэша (для отладки)
  static Map<String, dynamic> getStats() {
    if (!isReady) return {'status': 'not_initialized'};

    return {
      'status': 'ready',
      'entries': _cacheBox!.length,
      'keys': _cacheBox!.keys.toList(),
    };
  }
}
