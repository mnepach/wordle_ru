class GameStats {
  int gamesPlayed;
  int gamesWon;
  int currentStreak;
  int maxStreak;
  Map<int, int> guessDistribution;
  DateTime? lastPlayedDate;
  String deviceId;
  DateTime lastSyncTime;

  GameStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    Map<int, int>? guessDistribution,
    this.lastPlayedDate,
    required this.deviceId,
    DateTime? lastSyncTime,
  })  : guessDistribution = guessDistribution ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0},
        lastSyncTime = lastSyncTime ?? DateTime.now();

  double get winRate {
    if (gamesPlayed == 0) return 0;
    return (gamesWon / gamesPlayed * 100);
  }

  void recordGame({required bool won, required int attempts}) {
    gamesPlayed++;
    lastPlayedDate = DateTime.now();

    if (won) {
      gamesWon++;
      currentStreak++;
      if (currentStreak > maxStreak) {
        maxStreak = currentStreak;
      }
      if (attempts >= 1 && attempts <= 6) {
        guessDistribution[attempts] = (guessDistribution[attempts] ?? 0) + 1;
      }
    } else {
      currentStreak = 0;
    }
  }

  // Конвертация в JSON для Firebase (массив вместо Map для guessDistribution)
  Map<String, dynamic> toJson() {
    // Преобразуем Map<int, int> в List<int> для Firebase
    final distributionList = [
      guessDistribution[1] ?? 0,
      guessDistribution[2] ?? 0,
      guessDistribution[3] ?? 0,
      guessDistribution[4] ?? 0,
      guessDistribution[5] ?? 0,
      guessDistribution[6] ?? 0,
    ];

    return {
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'guessDistribution': distributionList, // Массив вместо Map
      'lastPlayedDate': lastPlayedDate?.toIso8601String(),
      'deviceId': deviceId,
      'lastSyncTime': lastSyncTime.toIso8601String(),
    };
  }

  // Создание из JSON (поддержка и Map, и List)
  factory GameStats.fromJson(Map<String, dynamic> json) {
    // Обрабатываем guessDistribution - может быть Map или List
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    final distData = json['guessDistribution'];

    if (distData is List) {
      // Если пришёл массив из Firebase
      for (int i = 0; i < distData.length && i < 6; i++) {
        distribution[i + 1] = (distData[i] as num?)?.toInt() ?? 0;
      }
    } else if (distData is Map) {
      // Если пришёл Map (старый формат или локальное хранилище)
      distData.forEach((key, value) {
        final intKey = int.tryParse(key.toString());
        if (intKey != null && intKey >= 1 && intKey <= 6) {
          distribution[intKey] = (value as num?)?.toInt() ?? 0;
        }
      });
    }

    return GameStats(
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      maxStreak: (json['maxStreak'] as num?)?.toInt() ?? 0,
      guessDistribution: distribution,
      lastPlayedDate: json['lastPlayedDate'] != null
          ? DateTime.tryParse(json['lastPlayedDate'].toString())
          : null,
      deviceId: json['deviceId']?.toString() ?? '',
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Слияние статистики с другого устройства
  GameStats mergeWith(GameStats other) {
    return GameStats(
      gamesPlayed: gamesPlayed + other.gamesPlayed,
      gamesWon: gamesWon + other.gamesWon,
      currentStreak: _selectMoreRecent(
        lastPlayedDate,
        currentStreak,
        other.lastPlayedDate,
        other.currentStreak,
      ),
      maxStreak: maxStreak > other.maxStreak ? maxStreak : other.maxStreak,
      guessDistribution: _mergeDistributions(guessDistribution, other.guessDistribution),
      lastPlayedDate: _selectMoreRecentDate(lastPlayedDate, other.lastPlayedDate),
      deviceId: deviceId,
      lastSyncTime: DateTime.now(),
    );
  }

  int _selectMoreRecent(
      DateTime? date1,
      int value1,
      DateTime? date2,
      int value2,
      ) {
    if (date1 == null) return value2;
    if (date2 == null) return value1;
    return date1.isAfter(date2) ? value1 : value2;
  }

  DateTime? _selectMoreRecentDate(DateTime? date1, DateTime? date2) {
    if (date1 == null) return date2;
    if (date2 == null) return date1;
    return date1.isAfter(date2) ? date1 : date2;
  }

  static Map<int, int> _mergeDistributions(Map<int, int> a, Map<int, int> b) {
    final merged = Map<int, int>.from(a);
    b.forEach((key, value) {
      merged[key] = (merged[key] ?? 0) + value;
    });
    return merged;
  }

  GameStats copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? currentStreak,
    int? maxStreak,
    Map<int, int>? guessDistribution,
    DateTime? lastPlayedDate,
    String? deviceId,
    DateTime? lastSyncTime,
  }) {
    return GameStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      guessDistribution: guessDistribution ?? this.guessDistribution,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
      deviceId: deviceId ?? this.deviceId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}