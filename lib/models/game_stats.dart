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

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'guessDistribution': guessDistribution,
      'lastPlayedDate': lastPlayedDate?.toIso8601String(),
      'deviceId': deviceId,
      'lastSyncTime': lastSyncTime.toIso8601String(),
    };
  }

  // Создание из JSON
  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      gamesPlayed: json['gamesPlayed'] ?? 0,
      gamesWon: json['gamesWon'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      maxStreak: json['maxStreak'] ?? 0,
      guessDistribution: Map<int, int>.from(
        (json['guessDistribution'] as Map<dynamic, dynamic>?)?.map(
              (k, v) => MapEntry(int.parse(k.toString()), v as int),
        ) ??
            {},
      ),
      lastPlayedDate: json['lastPlayedDate'] != null
          ? DateTime.parse(json['lastPlayedDate'])
          : null,
      deviceId: json['deviceId'] ?? '',
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'])
          : DateTime.now(),
    );
  }

  // Слияние статистики с другого устройства
  GameStats mergeWith(GameStats other) {
    return GameStats(
      gamesPlayed: gamesPlayed + other.gamesPlayed,
      gamesWon: gamesWon + other.gamesWon,
      currentStreak: lastPlayedDate != null &&
          other.lastPlayedDate != null &&
          lastPlayedDate!.isAfter(other.lastPlayedDate!)
          ? currentStreak
          : other.currentStreak,
      maxStreak: maxStreak > other.maxStreak ? maxStreak : other.maxStreak,
      guessDistribution: _mergeDistributions(guessDistribution, other.guessDistribution),
      lastPlayedDate: lastPlayedDate != null &&
          other.lastPlayedDate != null &&
          lastPlayedDate!.isAfter(other.lastPlayedDate!)
          ? lastPlayedDate
          : other.lastPlayedDate,
      deviceId: deviceId,
      lastSyncTime: DateTime.now(),
    );
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