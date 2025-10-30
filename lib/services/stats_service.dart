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

  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  static String _getPlatformString() {
    String platform = 'unknown';

    if (kIsWeb) {
      platform = 'Web';
    } else if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    }
    return platform;
  }

  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString().split('').reversed.join();
    String platform = _getPlatformString().toLowerCase();

    return 'local_${platform}_$random';
  }

  static Future<GameStats> loadStats() async {
    if (_cachedStats != null) {
      return _cachedStats!;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_statsKey);
    final deviceId = await _getDeviceId();

    if (jsonString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _cachedStats = GameStats.fromJson(jsonMap);
        return _cachedStats!;
      } catch (e) {
        print('Ошибка декодирования статистики: $e. Создаем новую.');
      }
    }

    _cachedStats = GameStats(deviceId: deviceId);
    return _cachedStats!;
  }

  static Future<void> saveStats(GameStats stats) async {
    _cachedStats = stats;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats.toJson()));
  }

  static Future<void> recordGame({required bool won, required int attempts}) async {
    final stats = await loadStats();
    stats.recordGame(won: won, attempts: attempts);
    await saveStats(stats);
    await syncAfterGame();
  }

  static Future<void> resetStats() async {
    print('🚨 Сброс статистики...');
    final deviceId = await _getDeviceId();

    final newStats = GameStats(deviceId: deviceId);

    await saveStats(newStats);

    await SyncService().forcePushLocalStats();

    print('✅ Статистика сброшена и синхронизирована с облаком.');
  }

  static String getPlatformInfo() {
    return _getPlatformString();
  }

  static Future<void> syncNow() async {
    return SyncService().forceSync();
  }

  static Future<void> syncAfterGame() async {
    return SyncService().syncAfterGame();
  }
}