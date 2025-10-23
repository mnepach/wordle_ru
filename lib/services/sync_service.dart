import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/game_stats.dart';
import 'stats_service.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userId;
  StreamSubscription<DatabaseEvent>? _statsSubscription;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  Timer? _autoSyncTimer;
  DateTime? _lastSyncTime;

  // -------------------- ИНИЦИАЛИЗАЦИЯ --------------------
  Future<void> initialize() async {
    try {
      _updateStatus(SyncStatus.syncing);

      _userId = await _getOrCreateUserId();
      await _checkConnection();
      await _loadFromCloud();

      _subscribeToChanges();
      _startAutoSync();

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('Ошибка инициализации синхронизации: $e');
      _updateStatus(SyncStatus.offline);
    }
  }

  // -------------------- СОЗДАНИЕ / ПОЛУЧЕНИЕ ПОЛЬЗОВАТЕЛЯ --------------------
  Future<String> _getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cloud_user_id');

    if (userId == null) {
      try {
        final userCredential = await _auth.signInAnonymously();
        userId = userCredential.user?.uid;

        if (userId != null) {
          await prefs.setString('cloud_user_id', userId);
        }
      } catch (e) {
        userId = const Uuid().v4();
        await prefs.setString('cloud_user_id', userId);
      }
    } else {
      try {
        if (_auth.currentUser == null) {
          await _auth.signInAnonymously();
        }
      } catch (e) {
        print('Не удалось восстановить сессию: $e');
      }
    }

    return userId!;
  }

  // -------------------- ФУНКЦИЯ БЕЗОПАСНОСТИ ДЛЯ ПУТЕЙ --------------------
  String _sanitizeKey(String input) {
    // Заменяет все недопустимые символы на подчёркивания
    return input.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  // -------------------- ПРОВЕРКА СОЕДИНЕНИЯ --------------------
  Future<void> _checkConnection() async {
    try {
      final connectedRef = _database.ref('.info/connected');
      final snapshot = await connectedRef.get();

      if (snapshot.value != true) {
        throw Exception('Нет подключения к Firebase');
      }
    } catch (e) {
      throw Exception('Ошибка подключения: $e');
    }
  }

  // -------------------- ЗАГРУЗКА ИЗ ОБЛАКА --------------------
  Future<void> _loadFromCloud() async {
    if (_userId == null) return;

    try {
      final ref = _database.ref('users/${_sanitizeKey(_userId!)}/stats');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value is Map) {
        final cloudData = Map<String, dynamic>.from(snapshot.value as Map);
        final cloudStats = GameStats.fromJson(cloudData);

        final localStats = await StatsService.loadStats();

        if (cloudStats.lastSyncTime.isAfter(localStats.lastSyncTime)) {
          final mergedStats = localStats.mergeWith(cloudStats);
          await StatsService.saveStats(mergedStats);
        } else if (localStats.lastSyncTime.isAfter(cloudStats.lastSyncTime)) {
          await _uploadToCloud(localStats);
        }
      } else {
        final localStats = await StatsService.loadStats();
        await _uploadToCloud(localStats);
      }

      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('Ошибка загрузки из облака: $e');
      throw e;
    }
  }

  // -------------------- ВЫГРУЗКА В ОБЛАКО --------------------
  Future<void> _uploadToCloud(GameStats stats) async {
    if (_userId == null) return;

    try {
      final ref = _database.ref('users/${_sanitizeKey(_userId!)}/stats');
      final updatedStats = stats.copyWith(lastSyncTime: DateTime.now());
      await ref.set(updatedStats.toJson());
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('Ошибка загрузки в облако: $e');
      throw e;
    }
  }

  // -------------------- ПОДПИСКА НА ОБНОВЛЕНИЯ --------------------
  void _subscribeToChanges() {
    if (_userId == null) return;

    final ref = _database.ref('users/${_sanitizeKey(_userId!)}/stats');

    _statsSubscription = ref.onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        try {
          final cloudData = Map<String, dynamic>.from(event.snapshot.value as Map);
          final cloudStats = GameStats.fromJson(cloudData);
          final localStats = await StatsService.loadStats();

          if (cloudStats.lastSyncTime.isAfter(localStats.lastSyncTime)) {
            await StatsService.saveStats(cloudStats);
            _updateStatus(SyncStatus.synced);
          }
        } catch (e) {
          print('Ошибка обработки изменений: $e');
        }
      }
    }, onError: (error) {
      print('Ошибка подписки: $error');
      _updateStatus(SyncStatus.error);
    });
  }

  // -------------------- СИНХРОНИЗАЦИЯ ПОСЛЕ ИГРЫ --------------------
  Future<void> syncAfterGame() async {
    if (_userId == null) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      final stats = await StatsService.loadStats();
      await _uploadToCloud(stats);
      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('Ошибка синхронизации: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  // -------------------- ПРИНУДИТЕЛЬНАЯ СИНХРОНИЗАЦИЯ --------------------
  Future<void> forceSync() async {
    try {
      _updateStatus(SyncStatus.syncing);
      await _loadFromCloud();
      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('Ошибка принудительной синхронизации: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  // -------------------- АВТОСИНХРОНИЗАЦИЯ --------------------
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentStatus != SyncStatus.syncing) {
        await forceSync();
      }
    });
  }

  // -------------------- ОБНОВЛЕНИЕ СТАТУСА --------------------
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  // -------------------- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ --------------------
  Future<String?> getUserId() async => _userId;

  DateTime? getLastSyncTime() => _lastSyncTime;

  Future<void> reset() async {
    await dispose();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloud_user_id');
    await initialize();
  }

  Future<void> dispose() async {
    _autoSyncTimer?.cancel();
    await _statsSubscription?.cancel();
    await _syncStatusController.close();
  }

  Future<bool> isCloudAvailable() async {
    try {
      await _checkConnection();
      return true;
    } catch (_) {
      return false;
    }
  }

  String getSyncInfo() {
    switch (_currentStatus) {
      case SyncStatus.idle:
        return 'Ожидание';
      case SyncStatus.syncing:
        return 'Синхронизация...';
      case SyncStatus.synced:
        if (_lastSyncTime != null) {
          final diff = DateTime.now().difference(_lastSyncTime!);
          if (diff.inSeconds < 60) {
            return 'Синхронизировано (только что)';
          } else if (diff.inMinutes < 60) {
            return 'Синхронизировано (${diff.inMinutes} мин назад)';
          } else {
            return 'Синхронизировано (${diff.inHours} ч назад)';
          }
        }
        return 'Синхронизировано';
      case SyncStatus.error:
        return 'Ошибка синхронизации';
      case SyncStatus.offline:
        return 'Оффлайн режим';
    }
  }
}
