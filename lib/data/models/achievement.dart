import 'player_stats.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardCoins,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final int rewardCoins;

  /// Predicate evaluated against stats *after* a result has been recorded.
  final bool Function(PlayerStats stats) isUnlocked;
}

class AchievementCatalog {
  AchievementCatalog._();

  static final List<Achievement> all = [
    Achievement(
      id: 'first_win',
      title: 'First Win',
      description: 'Solve your first puzzle.',
      rewardCoins: 10,
      isUnlocked: (s) => s.wins >= 1,
    ),
    Achievement(
      id: 'under_10',
      title: 'Sharp Mind',
      description: 'Solve a puzzle in fewer than 10 guesses.',
      rewardCoins: 25,
      isUnlocked: (s) => s.bestGuessCount != null && s.bestGuessCount! < 10,
    ),
    Achievement(
      id: 'under_5',
      title: 'Mind Reader',
      description: 'Solve a puzzle in 5 guesses or fewer.',
      rewardCoins: 50,
      isUnlocked: (s) => s.bestGuessCount != null && s.bestGuessCount! <= 5,
    ),
    Achievement(
      id: 'speedster',
      title: 'Speedster',
      description: 'Solve a puzzle in under 60 seconds.',
      rewardCoins: 25,
      isUnlocked: (s) =>
          s.fastestWinSeconds != null && s.fastestWinSeconds! < 60,
    ),
    Achievement(
      id: 'streak_3',
      title: 'On a Roll',
      description: 'Reach a 3-day streak.',
      rewardCoins: 15,
      isUnlocked: (s) => s.maxStreak >= 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Reach a 7-day streak.',
      rewardCoins: 50,
      isUnlocked: (s) => s.maxStreak >= 7,
    ),
    Achievement(
      id: 'wins_10',
      title: 'Veteran',
      description: 'Win 10 puzzles.',
      rewardCoins: 30,
      isUnlocked: (s) => s.wins >= 10,
    ),
    Achievement(
      id: 'wins_25',
      title: 'Word Master',
      description: 'Win 25 puzzles.',
      rewardCoins: 75,
      isUnlocked: (s) => s.wins >= 25,
    ),
    Achievement(
      id: 'explorer',
      title: 'Explorer',
      description: 'Win in 4 different categories.',
      rewardCoins: 30,
      isUnlocked: (s) => s.winCategories.length >= 4,
    ),
    Achievement(
      id: 'daily_3',
      title: 'Daily Habit',
      description: 'Solve 3 daily puzzles.',
      rewardCoins: 30,
      isUnlocked: (s) => s.dailyWins >= 3,
    ),
    Achievement(
      id: 'daily_10',
      title: 'Daily Devotee',
      description: 'Solve 10 daily puzzles.',
      rewardCoins: 75,
      isUnlocked: (s) => s.dailyWins >= 10,
    ),
    Achievement(
      id: 'battle_first',
      title: 'Battle Ready',
      description: 'Finish your first battle.',
      rewardCoins: 15,
      isUnlocked: (s) => s.battlesPlayed >= 1,
    ),
    Achievement(
      id: 'battle_win',
      title: 'Nearest of All',
      description: 'Win a battle.',
      rewardCoins: 40,
      isUnlocked: (s) => s.battleWins >= 1,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
