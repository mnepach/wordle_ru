import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  FirebaseDatabase? _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userId;
  StreamSubscription<DatabaseEvent>? _statsSubscription;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  DateTime? _lastSyncTime;

  Future<void> initialize() async {
    try {
      _updateStatus(SyncStatus.syncing);

      _database = FirebaseDatabase.instance;
      _database!.databaseURL = 'https://wordle-ru-f1f08-default-rtdb.firebaseio.com';

      _userId = await _getOrCreateUserId();

      if (_userId == null || _userId!.isEmpty) {
        print('❌ Облачная синхронизация недоступна (ошибка аутентификации)');
        _updateStatus(SyncStatus.offline);
        return;
      }

      print('✅ Sync Service инициализирован. User ID: $_userId');

      _subscribeToChanges();
      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('❌ Ошибка инициализации синхронизации: $e');
      _updateStatus(SyncStatus.offline);
    }
  }

  Future<String?> _getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cloud_user_id');

    if (userId == null || userId.isEmpty || userId.startsWith('local_')) {
      try {
        final userCredential = await _auth.signInAnonymously();
        userId = userCredential.user?.uid;

        if (userId != null && userId.isNotEmpty) {
          await prefs.setString('cloud_user_id', userId);
          print('✅ Создан/получен новый Firebase User ID: $userId');
          return userId;
        } else {
          throw Exception('Firebase вернул пустой UID');
        }
      } catch (e) {
        print('❌ КРИТИЧЕСКАЯ Ошибка аутентификации Firebase: $e');
        return null;
      }
    }

    return userId.startsWith('local_') ? null : userId;
  }

  void _subscribeToChanges() {
    if (_userId == null || _database == null) return;

    final ref = _database!.ref('users/$_userId/stats');
    print('📡 Подписываемся на: users/$_userId/stats');

    _statsSubscription = ref.onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          print('📥 Получены изменения из облака');
          final data = event.snapshot.value;

          Map<String, dynamic> cloudData;
          if (data is Map) {
            cloudData = Map<String, dynamic>.from(data);
          } else {
            print('⚠️ Неожиданный формат данных: ${data.runtimeType}');
            return;
          }

          final cloudStats = GameStats.fromJson(cloudData);
          final localStats = await StatsService.loadStats();

          // ЛОГИКА СЛИЯНИЯ: Применяем изменения из облака, только если облачные данные новее.
          // Иначе принудительная синхронизация (forceSync) выполнит слияние.
          if (cloudStats.lastSyncTime.isAfter(localStats.lastSyncTime)) {
            print('✅ Применяем более свежие данные из облака');
            await StatsService.saveStats(cloudStats);
            _updateStatus(SyncStatus.synced);
          }
        } catch (e) {
          print('❌ Ошибка обработки изменений: $e');
          print('Stack trace: ${StackTrace.current}');
        }
      }
    }, onError: (error) {
      print('❌ Ошибка подписки: $error');
      _updateStatus(SyncStatus.error);
    });
  }

  Future<void> syncAfterGame() async {
    if (_userId == null || _database == null) {
      print('⚠️ Синхронизация недоступна (offline)');
      _updateStatus(SyncStatus.offline);
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      print('📤 Начинаем синхронизацию после игры...');

      final stats = await StatsService.loadStats();
      final updatedStats = stats.copyWith(lastSyncTime: DateTime.now());

      final ref = _database!.ref('users/$_userId/stats');
      await ref.set(updatedStats.toJson());

      _lastSyncTime = DateTime.now();
      print('✅ Синхронизация завершена');
      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
      print('Stack trace: ${StackTrace.current}');
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  Future<void> forceSync() async {
    if (_userId == null || _database == null) {
      print('⚠️ Принудительная синхронизация недоступна');
      _updateStatus(SyncStatus.offline);
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      print('🔄 Принудительная синхронизация (слияние данных)...');

      final ref = _database!.ref('users/$_userId/stats');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value;
        Map<String, dynamic> cloudData;

        if (data is Map) {
          cloudData = Map<String, dynamic>.from(data);
        } else {
          throw Exception('Неожиданный формат данных: ${data.runtimeType}');
        }

        final cloudStats = GameStats.fromJson(cloudData);
        final localStats = await StatsService.loadStats();

        // СЛИЯНИЕ: Используем mergeWith для объединения локальных и облачных данных
        final mergedStats = localStats.mergeWith(cloudStats);
        await StatsService.saveStats(mergedStats);

        final updatedStats = mergedStats.copyWith(lastSyncTime: DateTime.now());
        await ref.set(updatedStats.toJson());

        _lastSyncTime = DateTime.now();
        print('✅ Принудительная синхронизация завершена');
      } else {
        print('⚠️ Данных в облаке нет, загружаем локальные');
        await syncAfterGame();
      }

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('❌ Ошибка принудительной синхронизации: $e');
      print('Stack trace: ${StackTrace.current}');
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  Future<void> forcePushLocalStats() async {
    if (_userId == null || _database == null) {
      print('⚠️ Принудительная отправка недоступна');
      _updateStatus(SyncStatus.offline);
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      print('⏫ Принудительная отправка локальных данных в облако...');

      final stats = await StatsService.loadStats();
      final updatedStats = stats.copyWith(lastSyncTime: DateTime.now());

      final ref = _database!.ref('users/$_userId/stats');
      await ref.set(updatedStats.toJson());

      _lastSyncTime = DateTime.now();
      print('✅ Отправка завершена');
      _updateStatus(SyncStatus.synced);
    } catch (e) {
      print('❌ Ошибка принудительной отправки: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  Future<String?> getUserId() async => _userId;

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
        return 'Ошибкаизации';
      case SyncStatus.offline:
        return 'Оффлайн режим';
    }
  }

  Future<void> dispose() async {
    await _statsSubscription?.cancel();
    await _syncStatusController.close();
  }
}