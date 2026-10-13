import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/data/models/category.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/data/repositories/stats_repository.dart';
import 'package:nearword/core/utils/share_text.dart';
import 'package:nearword/data/models/game_result.dart';

void main() {
  late Directory tmp;
  late StorageService storage;
  late DateTime now;
  late StatsRepository repo;

  RewardSummary win({
    int guesses = 12,
    int seconds = 100,
    String cat = 'animals',
  }) => repo.recordResult(
    won: true,
    categoryId: cat,
    difficulty: Difficulty.easy,
    guessCount: guesses,
    seconds: seconds,
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nearword_stats');
    Hive.init(tmp.path);
    storage = await StorageService().init(useFlutter: false);
    now = DateTime(2026, 5, 10, 12);
    repo = StatsRepository(storage, clock: () => now).init();
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('win updates counters, distribution and coins', () {
    final r = win(guesses: 12);
    expect(repo.stats.wins, 1);
    expect(repo.stats.averageGuesses, 12);
    expect(repo.stats.distribution['11-20'], 1);
    // easy win (10) + first_win achievement (10)
    expect(r.coins, 20);
    expect(repo.coins.value, 20);
  });

  test('fast win under 10 guesses earns bonus and Sharp Mind', () {
    final r = win(guesses: 8);
    expect(
      r.achievements.map((a) => a.id),
      containsAll(['first_win', 'under_10']),
    );
    expect(StatsRepository.winReward(Difficulty.easy, 8), 15);
  });

  test('achievements unlock only once', () {
    win();
    final second = win();
    expect(second.achievements, isEmpty);
  });

  test('give up counts as played, not won', () {
    repo.recordResult(
      won: false,
      categoryId: 'animals',
      difficulty: Difficulty.easy,
      guessCount: 30,
      seconds: 90,
    );
    expect(repo.stats.gamesPlayed, 1);
    expect(repo.stats.wins, 0);
    expect(repo.stats.winRate, 0);
    expect(repo.stats.currentStreak, 0);
  });

  test('7-day streak unlocks Week Warrior', () {
    for (var i = 0; i < 7; i++) {
      now = DateTime(2026, 5, 10 + i, 12);
      win();
    }
    expect(repo.stats.currentStreak, 7);
    expect(repo.stats.achievements.containsKey('streak_7'), isTrue);
  });

  test('daily login is granted once per day', () {
    expect(repo.claimDailyLogin(), 20);
    expect(repo.claimDailyLogin(), 0);
    now = DateTime(2026, 5, 11, 8);
    expect(repo.claimDailyLogin(), 20);
  });

  test('premium category unlock spends coins and persists', () {
    const cat = Category(
      id: 'clothing',
      name: 'Clothing',
      icon: 'x',
      premium: true,
    );
    expect(repo.isCategoryUnlocked(cat), isFalse);
    expect(repo.unlockCategory(cat), isFalse); // 0 coins
    repo.addCoins(150);
    expect(repo.unlockCategory(cat), isTrue);
    expect(repo.coins.value, 50);

    final reloaded = StatsRepository(storage, clock: () => now).init();
    expect(reloaded.isCategoryUnlocked(cat), isTrue);
    expect(reloaded.stats.coins, 50);
  });

  test('stats survive a reload', () {
    win(guesses: 4, seconds: 30);
    final reloaded = StatsRepository(storage, clock: () => now).init();
    expect(reloaded.stats.wins, 1);
    expect(reloaded.stats.bestGuessCount, 4);
    expect(reloaded.stats.fastestWinSeconds, 30);
  });

  test('share text never contains the secret word', () {
    const result = GameResult(
      puzzleId: 'a-001',
      mode: PuzzleMode.category,
      title: 'Animals',
      difficulty: Difficulty.easy,
      won: true,
      secretWord: 'dog',
      guessCount: 4,
      seconds: 30,
      hintsUsed: 0,
      guessRanks: [5000, 900, 40, 1],
    );
    final text = ShareText.build(result);
    expect(text, contains('🟥🟨🟩🟩'));
    expect(text.toLowerCase(), isNot(contains('dog')));
  });
}
