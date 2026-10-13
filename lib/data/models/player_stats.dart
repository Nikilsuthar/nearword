/// Lifetime player data: stats, streak, coins and unlocks. Persisted as JSON.
class PlayerStats {
  PlayerStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.totalWinGuesses = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastWinDay,
    this.lastLoginDay,
    this.coins = 0,
    this.bestGuessCount,
    this.fastestWinSeconds,
    this.dailyWins = 0,
    this.battleWins = 0,
    this.battlesPlayed = 0,
    Map<String, int>? distribution,
    Set<String>? winCategories,
    Map<String, int>? achievements,
    Set<String>? unlockedCategories,
    Map<String, int>? tempUnlocks,
  }) : distribution = distribution ?? {},
       winCategories = winCategories ?? {},
       achievements = achievements ?? {},
       unlockedCategories = unlockedCategories ?? {},
       tempUnlocks = tempUnlocks ?? {};

  /// Wins + give-ups.
  int gamesPlayed;
  int wins;
  int totalWinGuesses;
  int currentStreak;
  int maxStreak;
  String? lastWinDay;
  String? lastLoginDay;
  int coins;
  int? bestGuessCount;
  int? fastestWinSeconds;
  int dailyWins;
  int battleWins;
  int battlesPlayed;

  /// Bucket label -> number of wins (see [bucketFor]).
  Map<String, int> distribution;
  Set<String> winCategories;

  /// Achievement id -> unlock time (epoch ms).
  Map<String, int> achievements;

  /// Premium categories unlocked permanently with coins.
  Set<String> unlockedCategories;

  /// Category id -> expiry (epoch ms) for 24-hour rewarded-ad unlocks.
  Map<String, int> tempUnlocks;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
  double get averageGuesses => wins == 0 ? 0 : totalWinGuesses / wins;

  static const List<String> buckets = ['1-5', '6-10', '11-20', '21-40', '41+'];

  static String bucketFor(int guesses) {
    if (guesses <= 5) return buckets[0];
    if (guesses <= 10) return buckets[1];
    if (guesses <= 20) return buckets[2];
    if (guesses <= 40) return buckets[3];
    return buckets[4];
  }

  Map<String, dynamic> toJson() => {
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'totalWinGuesses': totalWinGuesses,
    'currentStreak': currentStreak,
    'maxStreak': maxStreak,
    'lastWinDay': lastWinDay,
    'lastLoginDay': lastLoginDay,
    'coins': coins,
    'bestGuessCount': bestGuessCount,
    'fastestWinSeconds': fastestWinSeconds,
    'dailyWins': dailyWins,
    'battleWins': battleWins,
    'battlesPlayed': battlesPlayed,
    'distribution': distribution,
    'winCategories': winCategories.toList(),
    'achievements': achievements,
    'unlockedCategories': unlockedCategories.toList(),
    'tempUnlocks': tempUnlocks,
  };

  factory PlayerStats.fromJson(Map<dynamic, dynamic> j) => PlayerStats(
    gamesPlayed: j['gamesPlayed'] as int? ?? 0,
    wins: j['wins'] as int? ?? 0,
    totalWinGuesses: j['totalWinGuesses'] as int? ?? 0,
    currentStreak: j['currentStreak'] as int? ?? 0,
    maxStreak: j['maxStreak'] as int? ?? 0,
    lastWinDay: j['lastWinDay'] as String?,
    lastLoginDay: j['lastLoginDay'] as String?,
    coins: j['coins'] as int? ?? 0,
    bestGuessCount: j['bestGuessCount'] as int?,
    fastestWinSeconds: j['fastestWinSeconds'] as int?,
    dailyWins: j['dailyWins'] as int? ?? 0,
    battleWins: j['battleWins'] as int? ?? 0,
    battlesPlayed: j['battlesPlayed'] as int? ?? 0,
    distribution: ((j['distribution'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    winCategories: ((j['winCategories'] as List?) ?? []).cast<String>().toSet(),
    achievements: ((j['achievements'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    unlockedCategories: ((j['unlockedCategories'] as List?) ?? [])
        .cast<String>()
        .toSet(),
    tempUnlocks: ((j['tempUnlocks'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
  );
}
