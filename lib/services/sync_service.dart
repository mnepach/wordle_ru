import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/game_stats.dart';
import 'stats_service.dart';
import 'firebase_rest_service.dart';

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

  FirebaseDatabase? _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userId;
  StreamSubscription<DatabaseEvent>? _statsSubscription;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  Timer? _autoSyncTimer;
  DateTime? _lastSyncTime;

  // Определяем платформу
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _useRestApi => _isWindows || kIsWeb;

  // -------------------- ИНИЦИАЛИЗАЦИЯ --------------------
  Future<void> initialize() async {
    try {
      _updateStatus(SyncStatus.syncing);

      if (!_useRestApi) {
        _database = FirebaseDatabase.instanceFor(
          app: _auth.app,
          databaseURL: 'https://wordle-ru-f1f08-default-rtdb.firebaseio.com',
        );
      }

      _userId = await _getOrCreateUserId();

      if (_userId == null || _userId!.isEmpty) {
        throw Exception('Не удалось получить User ID');
      }

      await _checkConnection();
      await _loadFromCloud();

      if (!_useRestApi) {
        _subscribeToChanges();
      }

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

    if (userId == null || userId.isEmpty) {
      try {
        final userCredential = await _auth.signInAnonymously();
        userId = userCredential.user?.uid;

        if (userId != null && userId.isNotEmpty) {
          final safeUserId = _sanitizeFirebaseUid(userId);
          await prefs.setString('cloud_user_id', safeUserId);
          await prefs.setString('original_firebase_uid', userId);
          print('Создан новый пользователь Firebase: $safeUserId');
          return safeUserId;
        } else {
          throw Exception('Firebase вернул пустой UID');
        }
      } catch (e) {
        print('Ошибка создания Firebase пользователя: $e');
        userId = _generateSafeUserId();
        await prefs.setString('cloud_user_id', userId);
        print('Создан локальный ID: $userId');
      }
    } else {
      print('Используем существующий ID: $userId');

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

  String _sanitizeFirebaseUid(String uid) {
    final sanitized = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (sanitized.isEmpty) {
      return _generateSafeUserId();
    }
    return 'u$sanitized';
  }

  String _generateSafeUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString().split('').reversed.join();
    return 'u${timestamp}x$random';
  }

  // -------------------- ПРОВЕРКА СОЕДИНЕНИЯ --------------------
  Future<void> _checkConnection() async {
    try {
      if (_useRestApi) {
        final connected = await FirebaseRestService.checkConnection();
        if (!connected) {
          throw Exception('Нет подключения к Firebase');
        }
        print('REST API подключение успешно');
      } else {
        final connectedRef = _database!.ref('.info/connected');
        final snapshot = await connectedRef.get().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Timeout при подключении к Firebase'),
        );

        if (snapshot.value != true) {
          throw Exception('Нет подключения к Firebase');
        }
        print('Firebase Database подключение успешно');
      }
    } catch (e) {
      throw Exception('Ошибка подключения: $e');
    }
  }

  // -------------------- ЗАГРУЗКА ИЗ ОБЛАКА --------------------
  Future<void> _loadFromCloud() async {
    if (_userId == null || _userId!.isEmpty) {
      throw Exception('User ID не инициализирован');
    }

    try {
      print('Загружаем данные для пользователя: $_userId');

      Map<String, dynamic>? cloudData;

      if (_useRestApi) {
        cloudData = await FirebaseRestService.getData(_userId!);
      } else {
        final ref = _database!.ref('users/$_userId/stats');
        final snapshot = await ref.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Timeout при загрузке данных'),
        );

        if (snapshot.exists && snapshot.value is Map) {
          cloudData = Map<String, dynamic>.from(snapshot.value as Map);
        }
      }

      if (cloudData != null) {
        print('Найдены данные в облаке');
        final cloudStats = GameStats.fromJson(cloudData);
        final localStats = await StatsService.loadStats();

        if (cloudStats.lastSyncTime.isAfter(localStats.lastSyncTime)) {
          print('Облачные данные новее, применяем их');
          final mergedStats = localStats.mergeWith(cloudStats);
          await StatsService.saveStats(mergedStats);
        } else if (localStats.lastSyncTime.isAfter(cloudStats.lastSyncTime)) {
          print('Локальные данные новее, загружаем в облако');
          await _uploadToCloud(localStats);
        } else {
          print('Данные синхронизированы');
        }
      } else {
        print('Данных в облаке нет, загружаем локальные');
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
    if (_userId == null || _userId!.isEmpty) {
      throw Exception('User ID не инициализирован');
    }

    try {
      print('Загружаем данные в облако для пользователя: $_userId');

      final updatedStats = stats.copyWith(lastSyncTime: DateTime.now());
      bool success;

      if (_useRestApi) {
        success = await FirebaseRestService.setData(_userId!, updatedStats);
      } else {
        final ref = _database!.ref('users/$_userId/stats');
        await ref.set(updatedStats.toJson()).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Timeout при загрузке данных'),
        );
        success = true;
      }

      if (success) {
        _lastSyncTime = DateTime.now();
        print('Данные успешно загружены в облако');
      } else {
        throw Exception('Не удалось сохранить данные');
      }
    } catch (e) {
      print('Ошибка загрузки в облако: $e');
      throw e;
    }
  }

  // -------------------- ПОДПИСКА НА ОБНОВЛЕНИЯ (только для Android/iOS) --------------------
  void _subscribeToChanges() {
    if (_userId == null || _userId!.isEmpty || _database == null) {
      print('Не удалось подписаться на изменения');
      return;
    }

    final path = 'users/$_userId/stats';
    print('Подписываемся на изменения в пути: $path');

    final ref = _database!.ref(path);

    _statsSubscription = ref.onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        try {
          print('Получены изменения из облака');
          final cloudData = Map<String, dynamic>.from(event.snapshot.value as Map);
          final cloudStats = GameStats.fromJson(cloudData);
          final localStats = await StatsService.loadStats();

          if (cloudStats.lastSyncTime.isAfter(localStats.lastSyncTime)) {
            print('Применяем изменения из облака');
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
    await prefs.remove('original_firebase_uid');
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