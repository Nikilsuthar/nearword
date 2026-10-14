import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/data/models/game_result.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/data/models/saved_game.dart';
import 'package:nearword/data/repositories/puzzle_repository.dart';
import 'package:nearword/data/repositories/stats_repository.dart';
import 'package:nearword/features/game/game_controller.dart';
import 'package:nearword/features/hints/hint_engine.dart';
import 'package:nearword/l10n/app_translations.dart';

/// Engine with a tiny hand-made ranking so the tests are deterministic.
class _FakeEngine extends SemanticEngine {
  static const words = {
    'dog': 1,
    'cat': 5,
    'lion': 400,
    'car': 5000,
    'berry': 900,
  };

  @override
  Ranking rank(String secret) {
    final byRank = words.keys.toList()
      ..sort((a, b) => words[a]!.compareTo(words[b]!));
    return Ranking(Map.of(words), byRank);
  }
}

class _FakeRepo extends PuzzleRepository {
  _FakeRepo(super.engine);

  static const puzzle = Puzzle(
    id: 'rnd-rm-TEST01',
    mode: PuzzleMode.random,
    category: 'random',
    difficulty: Difficulty.easy,
    level: Difficulty.easy,
    wordSet: WordSet.regular,
    secret: 'dog',
  );

  @override
  Puzzle? puzzleById(String id) => id == puzzle.id ? puzzle : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late StorageService storage;
  late StatsRepository stats;
  late GameController c;
  GameResult? finished;

  Future<GameController> makeController() async {
    final ctrl = GameController(
      initialPuzzleId: 'rnd-rm-TEST01',
      repository: _FakeRepo(_FakeEngine()),
      engine: _FakeEngine(),
      storage: storage,
      stats: stats,
      onFinished: (r) => finished = r,
      resultDelay: Duration.zero,
    );
    await ctrl.loadPuzzle('rnd-rm-TEST01');
    return ctrl;
  }

  setUp(() async {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en');
    tmp = await Directory.systemTemp.createTemp('nearword_test');
    Hive.init(tmp.path);
    storage = await StorageService().init(useFlutter: false);
    stats = StatsRepository(storage).init();
    finished = null;
    c = await makeController();
  });

  tearDown(() async {
    c.onClose();
    Get.reset();
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('empty input is ignored', () {
    expect(c.submitGuess('   '), GuessResult.ignored);
    expect(c.guesses, isEmpty);
  });

  test('unknown word shows message and is not added', () {
    expect(c.submitGuess('zzzz'), GuessResult.unknown);
    expect(c.message.value, 'Word not in our list.');
    expect(c.guesses, isEmpty);
  });

  test('accepted guesses stay sorted by rank and latest is tracked', () {
    c.submitGuess('lion');
    c.submitGuess('car');
    c.submitGuess('cat');
    expect(c.guesses.map((g) => g.word), ['cat', 'lion', 'car']);
    expect(c.latest.value!.word, 'cat');
    expect(c.guessCount, 3);
  });

  test('duplicate guess highlights existing entry and shakes', () {
    c.submitGuess('cat');
    final tick = c.shakeTick.value;
    expect(c.submitGuess('CAT'), GuessResult.duplicate);
    expect(c.guesses.length, 1);
    expect(c.highlightedWord.value, 'cat');
    expect(c.shakeTick.value, tick + 1);
  });

  test('plural input resolves to singular vocabulary word', () {
    expect(c.submitGuess('berries'), GuessResult.accepted);
    expect(c.guesses.single.word, 'berry');
  });

  test('guessing the secret wins and reveals it', () {
    expect(c.submitGuess('dog'), GuessResult.won);
    expect(c.status.value, GameStatus.won);
    expect(c.secretWord.value, 'dog');
    expect(c.submitGuess('cat'), GuessResult.ignored); // game over
  });

  test('win records stats, coins and emits a result', () async {
    c.submitGuess('lion');
    c.submitGuess('cat');
    c.submitGuess('dog');
    await Future<void>.delayed(Duration.zero);

    expect(stats.stats.wins, 1);
    expect(stats.stats.gamesPlayed, 1);
    expect(stats.stats.currentStreak, 1);
    expect(finished, isNotNull);
    expect(finished!.won, isTrue);
    expect(finished!.guessRanks, [400, 5, 1]);
    expect(finished!.coinsEarned, greaterThan(0));
    expect(finished!.newAchievements.map((a) => a.id), contains('first_win'));
  });

  test('give up reveals the secret', () {
    c.giveUp();
    expect(c.status.value, GameStatus.gaveUp);
    expect(c.secretWord.value, 'dog');
  });

  test('give up counts as played but not won, and gives no coins', () async {
    c.submitGuess('cat');
    c.giveUp();
    await Future<void>.delayed(Duration.zero);
    expect(stats.stats.gamesPlayed, 1);
    expect(stats.stats.wins, 0);
    expect(stats.stats.coins, 0);
    expect(finished!.won, isFalse);
  });

  test('re-opening a finished game does not record it twice', () async {
    c.submitGuess('dog');
    final resumed = await makeController();
    await Future<void>.delayed(Duration.zero);
    expect(stats.stats.wins, 1);
    expect(finished!.alreadyRecorded, isTrue);
    resumed.onClose();
  });

  test(
    'first-letter and length hints reveal info once and are saved',
    () async {
      expect(c.applyHint(HintType.firstLetter), isTrue);
      expect(c.applyHint(HintType.firstLetter), isFalse); // already used
      expect(c.applyHint(HintType.wordLength), isTrue);
      expect(c.hintSummary, 'Starts with "D" · 3 letters');
      expect(c.hintsUsed.value, 2);

      final resumed = await makeController();
      expect(resumed.hintSummary, 'Starts with "D" · 3 letters');
      expect(resumed.hintsUsed.value, 2);
      resumed.onClose();
    },
  );

  test('better-word hint adds a closer guess', () {
    c.submitGuess('car'); // rank 5000
    expect(c.applyHint(HintType.betterWord), isTrue);
    expect(c.guesses.length, 2);
    expect(c.bestRank!, lessThan(5000));
    expect(c.hintsUsed.value, 1);
  });

  test('better-word hint unavailable when no closer word exists', () {
    c.submitGuess('cat'); // rank 5; the only closer word would be the secret
    expect(c.canApplyHint(HintType.betterWord), isFalse);
  });

  test('hints are not applicable after the game ends', () {
    c.giveUp();
    expect(c.canApplyHint(HintType.firstLetter), isFalse);
  });

  test('progress is saved and restored', () async {
    c.submitGuess('cat');
    c.submitGuess('lion'); // each accepted guess is persisted immediately

    final resumed = await makeController();
    expect(resumed.guesses.map((g) => g.word), ['cat', 'lion']);
    expect(resumed.status.value, GameStatus.playing);
    resumed.onClose();
  });
}
