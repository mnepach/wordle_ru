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

  // -------------------- ИНИЦИАЛИЗАЦИЯ --------------------
  Future<void> initialize() async {
    try {
      _updateStatus(SyncStatus.syncing);

      // Инициализируем базу данных с правильным URL
      _database = FirebaseDatabase.instanceFor(
        app: _auth.app,
        databaseURL: 'https://wordle-ru-f1f08-default-rtdb.firebaseio.com',
      );

      _userId = await _getOrCreateUserId();

      if (_userId == null || _userId!.isEmpty) {
        throw Exception('Не удалось получить User ID');
      }

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

    if (userId == null || userId.isEmpty) {
      try {
        final userCredential = await _auth.signInAnonymously();
        userId = userCredential.user?.uid;

        if (userId != null && userId.isNotEmpty) {
          // Firebase UID всегда безопасен
          await prefs.setString('cloud_user_id', userId);
          print('Создан новый пользователь Firebase: $userId');
        } else {
          throw Exception('Firebase вернул пустой UID');
        }
      } catch (e) {
        print('Ошибка создания Firebase пользователя: $e');
        // Создаём безопасный ID вручную
        userId = _generateSafeUserId();
        await prefs.setString('cloud_user_id', userId);
        print('Создан локальный ID: $userId');
      }
    } else {
      print('Используем существующий ID: $userId');

      // Проверяем, что ID безопасный
      if (!_isValidFirebasePath(userId)) {
        print('ID содержит недопустимые символы, генерируем новый');
        userId = _generateSafeUserId();
        await prefs.setString('cloud_user_id', userId);
      }

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

  // Генерация безопасного ID (только буквы, цифры, подчёркивания и дефисы)
  String _generateSafeUserId() {
    final uuid = const Uuid().v4().replaceAll('-', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'user_${timestamp}_$uuid';
  }

  // Проверка валидности пути Firebase
  bool _isValidFirebasePath(String path) {
    // Firebase не допускает: . $ # [ ] /
    final invalidChars = RegExp(r'[.#$\[\]/]');
    return !invalidChars.hasMatch(path) && path.isNotEmpty;
  }

  // Безопасное преобразование строки для Firebase пути
  String _sanitizeForFirebase(String input) {
    if (input.isEmpty) return 'empty';

    // Заменяем все недопустимые символы на подчёркивания
    return input
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll(r'$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('/', '_')
        .replaceAll(' ', '_');
  }

  // -------------------- ПРОВЕРКА СОЕДИНЕНИЯ --------------------
  Future<void> _checkConnection() async {
    if (_database == null) {
      throw Exception('База данных не инициализирована');
    }

    try {
      final connectedRef = _database!.ref('.info/connected');
      final snapshot = await connectedRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Timeout при подключении к Firebase'),
      );

      print('Состояние подключения: ${snapshot.value}');

      if (snapshot.value != true) {
        throw Exception('Нет подключения к Firebase');
      }
    } catch (e) {
      throw Exception('Ошибка подключения: $e');
    }
  }

  // -------------------- ЗАГРУЗКА ИЗ ОБЛАКА --------------------
  Future<void> _loadFromCloud() async {
    if (_userId == null || _userId!.isEmpty || _database == null) {
      throw Exception('User ID или база данных не инициализированы');
    }

    try {
      // Используем безопасный путь
      final safeUserId = _sanitizeForFirebase(_userId!);
      final path = 'users/$safeUserId/stats';
      print('Загружаем данные из пути: $path');

      final ref = _database!.ref(path);
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout при загрузке данных'),
      );

      if (snapshot.exists && snapshot.value is Map) {
        print('Найдены данные в облаке');
        final cloudData = Map<String, dynamic>.from(snapshot.value as Map);
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
    if (_userId == null || _userId!.isEmpty || _database == null) {
      throw Exception('User ID или база данных не инициализированы');
    }

    try {
      final safeUserId = _sanitizeForFirebase(_userId!);
      final path = 'users/$safeUserId/stats';
      print('Загружаем данные в путь: $path');

      final ref = _database!.ref(path);
      final updatedStats = stats.copyWith(lastSyncTime: DateTime.now());

      await ref.set(updatedStats.toJson()).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout при загрузке данных'),
      );

      _lastSyncTime = DateTime.now();
      print('Данные успешно загружены в облако');
    } catch (e) {
      print('Ошибка загрузки в облако: $e');
      throw e;
    }
  }

  // -------------------- ПОДПИСКА НА ОБНОВЛЕНИЯ --------------------
  void _subscribeToChanges() {
    if (_userId == null || _userId!.isEmpty || _database == null) {
      print('Не удалось подписаться на изменения: нет User ID или базы данных');
      return;
    }

    final safeUserId = _sanitizeForFirebase(_userId!);
    final path = 'users/$safeUserId/stats';
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
    if (_userId == null || _database == null) {
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