import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/game_stats.dart';
import 'sync_service.dart';

class StatsService {
  static const String _statsKey = 'game_stats_v1';
  static const String _deviceIdKey = 'device_id_v1';
  static GameStats? _cachedStats;

  // Получить уникальный ID устройства
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString().split('').reversed.join();
    String platform = 'unknown';

    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else if (Platform.isWindows) {
      platform = 'windows';
    } else if (Platform.isMacOS) {
      platform = 'macos';
    } else if (Platform.isLinux) {
      platform = 'linux';
    }

    return '$platform-$random';
  }

  // Загрузить статистику
  static Future<GameStats> loadStats() async {
    if (_cachedStats != null) return _cachedStats!;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();
    final statsJson = prefs.getString(_statsKey);

    if (statsJson != null) {
      try {
        final decoded = json.decode(statsJson);
        _cachedStats = GameStats.fromJson(decoded);
        print('📊 Загружена статистика: ${_cachedStats!.gamesPlayed} игр');
        return _cachedStats!;
      } catch (e) {
        print('❌ Ошибка загрузки статистики: $e');
      }
    }

    _cachedStats = GameStats(deviceId: deviceId);
    print('📊 Создана новая статистика');
    return _cachedStats!;
  }

  // Сохранить статистику
  static Future<void> saveStats(GameStats stats) async {
    _cachedStats = stats;
    final prefs = await SharedPreferences.getInstance();
    final statsJson = json.encode(stats.toJson());
    await prefs.setString(_statsKey, statsJson);
    print('💾 Статистика сохранена локально');
  }

  // Записать результат игры (с ручной синхронизацией)
  static Future<void> recordGame({
    required bool won,
    required int attempts,
  }) async {
    final stats = await loadStats();
    stats.recordGame(won: won, attempts: attempts);
    await saveStats(stats);

    print('🎮 Результат игры записан: ${won ? "победа" : "поражение"} за $attempts попыток');

    // Синхронизация происходит ТОЛЬКО при нажатии "Новая игра"
    // Здесь ничего не делаем
  }

  // Ручная синхронизация - вызывается при нажатии "Новая игра"
  static Future<void> syncNow() async {
    try {
      print('🔄 Начинаем синхронизацию при новой игре...');
      await SyncService().syncAfterGame();
      print('✅ Синхронизация завершена');
    } catch (e) {
      print('⚠️ Ошибка синхронизации: $e');
      // Продолжаем работу даже если синхронизация не удалась
    }
  }

  // Сброс статистики
  static Future<void> resetStats() async {
    final deviceId = await _getDeviceId();
    final newStats = GameStats(deviceId: deviceId);
    await saveStats(newStats);

    // Синхронизируем сброс с облаком
    try {
      await SyncService().syncAfterGame();
    } catch (e) {
      print('❌ Ошибка синхронизации после сброса: $e');
    }
  }

  // Получить информацию о платформе
  static String getPlatformInfo() {
    if (kIsWeb) {
      return 'Web';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }

  // Принудительно обновить кэш из локального хранилища
  static Future<void> refreshCache() async {
    _cachedStats = null;
    await loadStats();
  }
}