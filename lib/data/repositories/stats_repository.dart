import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/streak_calculator.dart';
import '../models/achievement.dart';
import '../models/category.dart';
import '../models/player_stats.dart';
import '../models/puzzle.dart';

/// Coins and achievements granted by one finished game.
class RewardSummary {
  const RewardSummary({this.coins = 0, this.achievements = const []});

  final int coins;
  final List<Achievement> achievements;
}

/// Owns lifetime stats, streaks, coins, achievements and category unlocks.
/// Pass [clock] in tests to control "today".
class StatsRepository extends GetxService {
  StatsRepository(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final StorageService _storage;
  final DateTime Function() _clock;

  late PlayerStats stats;

  /// Reactive mirrors for the UI header chips.
  final RxInt coins = 0.obs;
  final RxInt streak = 0.obs;

  StatsRepository init() {
    stats = _storage.loadStats();
    _publish();
    return this;
  }

  // --- Daily login -----------------------------------------------------------

  /// Grants the daily login bonus once per local day. Returns coins granted
  /// (0 if already claimed today).
  int claimDailyLogin() {
    final today = DateHelper.dayKey(_clock());
    if (stats.lastLoginDay == today) return 0;
    stats.lastLoginDay = today;
    stats.coins += AppConstants.dailyLoginCoins;
    _save();
    return AppConstants.dailyLoginCoins;
  }

  // --- Results ------------------------------------------------------------------

  static int winReward(Difficulty difficulty, int guessCount) {
    final base = switch (difficulty) {
      Difficulty.easy => AppConstants.winCoinsEasy,
      Difficulty.medium => AppConstants.winCoinsMedium,
      Difficulty.hard => AppConstants.winCoinsHard,
    };
    final bonus = guessCount < AppConstants.fastWinGuesses
        ? AppConstants.fastWinBonusCoins
        : 0;
    return base + bonus;
  }

  /// Records a finished game exactly once. Call only on the playing -> finished
  /// transition.
  RewardSummary recordResult({
    required bool won,
    required String categoryId,
    required Difficulty difficulty,
    required int guessCount,
    required int seconds,
    PuzzleMode mode = PuzzleMode.category,
    bool battleWinner = false,
  }) {
    var earned = 0;
    stats.gamesPlayed++;
    if (mode == PuzzleMode.battle || mode == PuzzleMode.challenge) {
      stats.battlesPlayed++;
    }

    if (won) {
      stats.wins++;
      stats.totalWinGuesses += guessCount;
      final bucket = PlayerStats.bucketFor(guessCount);
      stats.distribution[bucket] = (stats.distribution[bucket] ?? 0) + 1;
      if (mode == PuzzleMode.category) stats.winCategories.add(categoryId);
      if (mode == PuzzleMode.daily) stats.dailyWins++;
      if ((mode == PuzzleMode.battle || mode == PuzzleMode.challenge) &&
          battleWinner) {
        stats.battleWins++;
      }
      if (stats.bestGuessCount == null || guessCount < stats.bestGuessCount!) {
        stats.bestGuessCount = guessCount;
      }
      if (stats.fastestWinSeconds == null ||
          seconds < stats.fastestWinSeconds!) {
        stats.fastestWinSeconds = seconds;
      }

      final next = StreakCalculator.registerWin(
        StreakState(
          current: stats.currentStreak,
          max: stats.maxStreak,
          lastDay: stats.lastWinDay,
        ),
        _clock(),
      );
      stats.currentStreak = next.current;
      stats.maxStreak = next.max;
      stats.lastWinDay = next.lastDay;

      earned += winReward(difficulty, guessCount);
      if (mode == PuzzleMode.daily) earned += AppConstants.dailyWinBonusCoins;
      stats.coins += earned;
    }

    final unlocked = _evaluateAchievements();
    for (final a in unlocked) {
      earned += a.rewardCoins;
      stats.coins += a.rewardCoins;
    }
    _save();
    return RewardSummary(coins: earned, achievements: unlocked);
  }

  List<Achievement> _evaluateAchievements() {
    final now = _clock().millisecondsSinceEpoch;
    final unlocked = <Achievement>[];
    for (final a in AchievementCatalog.all) {
      if (stats.achievements.containsKey(a.id)) continue;
      if (a.isUnlocked(stats)) {
        stats.achievements[a.id] = now;
        unlocked.add(a);
      }
    }
    return unlocked;
  }

  // --- Coins & unlocks --------------------------------------------------------------

  bool spendCoins(int amount) {
    if (stats.coins < amount) return false;
    stats.coins -= amount;
    _save();
    return true;
  }

  void addCoins(int amount) {
    stats.coins += amount;
    _save();
  }

  /// Pro Pass (Phase 5) unlocks everything and removes hint limits.
  bool get hasPro => _storage.proPass;

  bool isCategoryUnlocked(Category category) {
    if (!category.premium || hasPro) return true;
    if (stats.unlockedCategories.contains(category.id)) return true;
    final expiry = stats.tempUnlocks[category.id];
    return expiry != null && expiry > _clock().millisecondsSinceEpoch;
  }

  /// Rewarded-ad unlock that lasts [AppConstants.categoryAdUnlockDuration].
  void unlockCategoryTemporarily(Category category) {
    stats.tempUnlocks[category.id] = _clock()
        .add(AppConstants.categoryAdUnlockDuration)
        .millisecondsSinceEpoch;
    _save();
  }

  /// Permanently unlocks a premium category for [AppConstants.premiumCategoryCost].
  bool unlockCategory(Category category) {
    if (isCategoryUnlocked(category)) return true;
    if (!spendCoins(AppConstants.premiumCategoryCost)) return false;
    stats.unlockedCategories.add(category.id);
    _save();
    return true;
  }

  Set<String> lockedCategoryIds(Iterable<Category> categories) => {
        for (final c in categories)
          if (!isCategoryUnlocked(c)) c.id,
      };

  // --- Derived -----------------------------------------------------------------------

  /// Current streak as it should be shown today (0 if it has lapsed).
  int get displayStreak => StreakCalculator.displayStreak(
        StreakState(
          current: stats.currentStreak,
          max: stats.maxStreak,
          lastDay: stats.lastWinDay,
        ),
        _clock(),
      );

  void _save() {
    _publish();
    _storage.saveStats(stats);
  }

  void _publish() {
    coins.value = stats.coins;
    streak.value = displayStreak;
  }
}
