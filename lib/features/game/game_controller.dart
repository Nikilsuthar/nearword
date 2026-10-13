import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/services/semantic_engine.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/word_normalizer.dart';
import '../../data/models/game_result.dart';
import '../../data/models/guess.dart';
import '../../data/models/puzzle.dart';
import '../../data/models/saved_game.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../battle/battle_controller.dart';
import '../hints/hint_engine.dart';

/// Outcome of a call to [GameController.submitGuess].
enum GuessResult { ignored, duplicate, unknown, accepted, won }

class GameController extends GetxController with WidgetsBindingObserver {
  GameController({
    required this.initialPuzzleId,
    PuzzleRepository? repository,
    SemanticEngine? engine,
    StorageService? storage,
    StatsRepository? stats,
    SettingsService? settings,
    this.battle,
    this.onFinished,
    this.resultDelay = const Duration(milliseconds: 900),
  })  : _repo = repository ?? Get.find<PuzzleRepository>(),
        _engine = engine ?? Get.find<SemanticEngine>(),
        _storage = storage ?? Get.find<StorageService>(),
        _stats = stats ?? Get.find<StatsRepository>(),
        _settings = settings ??
            (Get.isRegistered<SettingsService>()
                ? Get.find<SettingsService>()
                : null);

  final String initialPuzzleId;
  final PuzzleRepository _repo;
  final SemanticEngine _engine;
  final StorageService _storage;
  final StatsRepository _stats;
  final SettingsService? _settings;

  /// Set when this game is a round of a multiplayer battle.
  final BattleLink? battle;

  /// Called (after [resultDelay]) when a game ends or a finished game is
  /// re-opened. The binding wires this to the Result screen.
  final void Function(GameResult result)? onFinished;
  final Duration resultDelay;

  bool get isBattle => battle != null;

  // --- Observable state (consumed by the view) -----------------------------
  final Rxn<Puzzle> puzzle = Rxn<Puzzle>();
  final RxBool isLoading = true.obs;
  final RxnString loadError = RxnString();

  /// Always sorted by rank ascending (best guess first).
  final RxList<Guess> guesses = <Guess>[].obs;
  final Rxn<Guess> latest = Rxn<Guess>();
  final Rx<GameStatus> status = GameStatus.playing.obs;
  final RxInt hintsUsed = 0.obs;
  final RxInt elapsedSeconds = 0.obs;

  /// Hint state: letter/length reveals (the "better word" hint becomes a guess).
  final RxBool firstLetterRevealed = false.obs;
  final RxBool lengthRevealed = false.obs;

  /// Transient message shown under the input ("Word not in our list.").
  final RxnString message = RxnString();

  /// Incremented to trigger the input-field shake animation.
  final RxInt shakeTick = 0.obs;

  /// Word of an existing entry to flash after a duplicate guess.
  final RxnString highlightedWord = RxnString();

  /// Revealed only after a win or give-up.
  final RxnString secretWord = RxnString();

  /// List or radar visualisation of the guesses.
  final RxBool radarView = false.obs;

  // --- Input plumbing -------------------------------------------------------
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  Ranking? _ranking;

  /// Guesses in the order they were made (stable even within one millisecond).
  final List<Guess> _history = [];
  Map<String, int> _rankings = {};
  String? _secret;
  Timer? _ticker;
  Timer? _messageTimer;
  Timer? _highlightTimer;
  Timer? _resultTimer;
  Worker? _battleWorker;

  /// "Daily #42", the category name, "Quick play" ...
  String get title {
    final p = puzzle.value;
    if (p == null) return '';
    return p.mode == PuzzleMode.category
        ? (_repo.categoryById(p.category)?.name ?? p.label)
        : p.label;
  }

  int get guessCount => guesses.length;
  bool get isPlaying => status.value == GameStatus.playing;
  bool get hasWon => status.value == GameStatus.won;
  Ranking? get ranking => _ranking;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final link = battle;
    if (link != null) {
      // The round ends for everyone when the clock runs out or someone wins
      // and the grace period is over.
      _battleWorker = ever<bool>(link.over, (isOver) {
        if (isOver && isPlaying && !isLoading.value) _finish(GameStatus.gaveUp);
      });
    }
    loadPuzzle(initialPuzzleId);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _persist();
    _stopTimers();
    _battleWorker?.dispose();
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isPlaying && !isLoading.value) {
        _startTicker();
      }
    } else {
      _ticker?.cancel();
      _persist();
    }
  }

  // --- Loading ----------------------------------------------------------------

  /// Derives the secret from the puzzle id, ranks the vocabulary against it and
  /// restores any saved progress so the player can resume.
  Future<void> loadPuzzle(String puzzleId) async {
    _stopTimers();
    isLoading.value = true;
    loadError.value = null;
    guesses.clear();
    _history.clear();
    latest.value = null;
    message.value = null;
    secretWord.value = null;
    highlightedWord.value = null;
    status.value = GameStatus.playing;
    hintsUsed.value = 0;
    elapsedSeconds.value = 0;
    firstLetterRevealed.value = false;
    lengthRevealed.value = false;
    textController.clear();

    try {
      final meta = _repo.puzzleById(puzzleId);
      if (meta == null) throw StateError('Unknown puzzle $puzzleId');
      // Let the loading state paint before the (CPU heavy) ranking.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final ranking = _engine.rank(meta.secret);

      puzzle.value = meta;
      _ranking = ranking;
      _secret = ranking.secret;
      _rankings = ranking.byWord;

      final saved = isBattle ? null : _storage.loadGame(puzzleId);
      if (saved != null) {
        guesses.assignAll(saved.guesses);
        _history.addAll(
          saved.guesses.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        );
        _sortGuesses();
        hintsUsed.value = saved.hintsUsed;
        elapsedSeconds.value = saved.elapsedSeconds;
        status.value = saved.status;
        firstLetterRevealed.value = saved.firstLetterHint;
        lengthRevealed.value = saved.lengthHint;
        if (guesses.isNotEmpty) {
          latest.value = guesses.reduce(
            (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
          );
        }
        if (saved.status != GameStatus.playing) {
          secretWord.value = _secret;
        }
      }
      isLoading.value = false;
      if (!isPlaying) _emitResult(recorded: false);
      if (isPlaying) {
        _startTicker();
        focusNode.requestFocus();
      }
    } catch (e) {
      isLoading.value = false;
      loadError.value = 'Could not load this puzzle. Please try again.';
    }
  }

  // --- Guessing -----------------------------------------------------------------

  /// Submits the text currently in the input field.
  GuessResult submit() {
    final result = submitGuess(textController.text);
    if (result != GuessResult.ignored) textController.clear();
    if (isPlaying) focusNode.requestFocus(); // keep the keyboard open
    return result;
  }

  GuessResult submitGuess(String input) {
    if (!isPlaying || isLoading.value) return GuessResult.ignored;
    if (input.trim().isEmpty) return GuessResult.ignored;

    // Resolve the input to a vocabulary word (exact form first, then singular).
    String? word;
    for (final candidate in WordNormalizer.candidates(input)) {
      if (_rankings.containsKey(candidate)) {
        word = candidate;
        break;
      }
    }
    if (word == null) {
      _flashMessage('Word not in our list.');
      shakeTick.value++;
      _settings?.bad();
      return GuessResult.unknown;
    }

    // Already guessed -> highlight the existing entry and shake.
    final existing = guesses.firstWhereOrNull((g) => g.word == word);
    if (existing != null) {
      _highlight(existing.word);
      _flashMessage('You already guessed "$word".');
      shakeTick.value++;
      _settings?.bad();
      return GuessResult.duplicate;
    }

    final guess = Guess(
      word: word,
      rank: _rankings[word]!,
      timestamp: DateTime.now(),
    );
    guesses.add(guess);
    _history.add(guess);
    _sortGuesses();
    latest.value = guess;
    message.value = null;

    if (guess.rank == 1) {
      _settings?.win();
      _finish(GameStatus.won);
      return GuessResult.won;
    }
    _settings?.good();
    _reportBattle();
    _persist();
    return GuessResult.accepted;
  }

  void _sortGuesses() => guesses.sort((a, b) => a.rank.compareTo(b.rank));

  void _reportBattle({bool done = false}) {
    battle?.report(
      bestRank: bestRank ?? 0,
      guesses: guessCount,
      solved: hasWon,
      done: done || hasWon,
    );
  }

  // --- Hints -----------------------------------------------------------------

  int? get bestRank => guesses.isEmpty ? null : guesses.first.rank;

  /// Text shown under the app bar once letter/length hints were used.
  String? get hintSummary {
    final secret = _secret;
    if (secret == null) return null;
    final parts = <String>[
      if (firstLetterRevealed.value) 'Starts with "${secret[0].toUpperCase()}"',
      if (lengthRevealed.value) '${secret.length} letters',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Whether [type] would reveal something new right now. Check this BEFORE
  /// charging the player. Hints are disabled in battles to keep them fair.
  bool canApplyHint(HintType type) {
    if (isBattle) return false;
    if (!isPlaying || isLoading.value || loadError.value != null) return false;
    switch (type) {
      case HintType.firstLetter:
        return !firstLetterRevealed.value;
      case HintType.wordLength:
        return !lengthRevealed.value;
      case HintType.betterWord:
        return HintEngine.pickBetterWord(
              _rankings,
              guesses.map((g) => g.word).toSet(),
              bestRank,
            ) !=
            null;
    }
  }

  /// Applies a hint (payment is handled by HintsController). Returns false if
  /// it could not be applied.
  bool applyHint(HintType type) {
    if (!canApplyHint(type)) return false;
    switch (type) {
      case HintType.firstLetter:
        firstLetterRevealed.value = true;
      case HintType.wordLength:
        lengthRevealed.value = true;
      case HintType.betterWord:
        final word = HintEngine.pickBetterWord(
          _rankings,
          guesses.map((g) => g.word).toSet(),
          bestRank,
        )!;
        final guess = Guess(
          word: word,
          rank: _rankings[word]!,
          timestamp: DateTime.now(),
        );
        guesses.add(guess);
        _history.add(guess);
        _sortGuesses();
        latest.value = guess;
        _highlight(word);
    }
    hintsUsed.value++;
    _persist();
    return true;
  }

  // --- Finishing -------------------------------------------------------------------

  /// Reveals the secret word. The view must ask for confirmation first.
  void giveUp() {
    if (!isPlaying) return;
    _finish(GameStatus.gaveUp);
  }

  void _finish(GameStatus result) {
    status.value = result;
    secretWord.value = _secret;
    _ticker?.cancel();
    _persist();
    _reportBattle(done: true);
    _emitResult(recorded: true);
  }

  /// Builds the [GameResult] (recording stats/coins when [recorded]) and hands
  /// it to [onFinished].
  void _emitResult({required bool recorded}) {
    final p = puzzle.value;
    if (p == null) return;

    var summary = const RewardSummary();
    if (recorded) {
      final link = battle;
      summary = _stats.recordResult(
        won: hasWon,
        categoryId: p.category,
        difficulty: p.difficulty,
        guessCount: guessCount,
        seconds: elapsedSeconds.value,
        mode: p.mode,
        battleWinner: link is BattleController && hasWon && link.myPlace == 1,
      );
    }

    final chronological = _history.toList();
    final byRank = _ranking?.byRank ?? const <String>[];
    final result = GameResult(
      puzzleId: p.id,
      mode: p.mode,
      title: title,
      difficulty: p.difficulty,
      won: hasWon,
      secretWord: secretWord.value ?? '',
      guessCount: guessCount,
      seconds: elapsedSeconds.value,
      hintsUsed: hintsUsed.value,
      guessRanks: chronological.map((g) => g.rank).toList(),
      closestWords: byRank.length > 1
          ? byRank.sublist(1, byRank.length < 31 ? byRank.length : 31)
          : const [],
      coinsEarned: summary.coins,
      newAchievements: summary.achievements,
      alreadyRecorded: !recorded,
    );
    final callback = onFinished;
    if (callback != null) {
      _resultTimer = Timer(resultDelay, () => callback(result));
    }
  }

  // --- Timer & persistence -----------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
      if (elapsedSeconds.value % 5 == 0) _persist();
    });
  }

  void _persist() {
    final p = puzzle.value;
    if (p == null || isLoading.value || isBattle) return;
    if (guesses.isEmpty &&
        hintsUsed.value == 0 &&
        status.value == GameStatus.playing) {
      return;
    }
    _storage.saveGame(
      SavedGame(
        puzzleId: p.id,
        guesses: guesses.toList(),
        hintsUsed: hintsUsed.value,
        elapsedSeconds: elapsedSeconds.value,
        status: status.value,
        firstLetterHint: firstLetterRevealed.value,
        lengthHint: lengthRevealed.value,
      ),
    );
  }

  void _flashMessage(String text) {
    message.value = text;
    _messageTimer?.cancel();
    _messageTimer = Timer(
      const Duration(seconds: 2),
      () => message.value = null,
    );
  }

  void _highlight(String word) {
    highlightedWord.value = word;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(
      const Duration(milliseconds: 1600),
      () => highlightedWord.value = null,
    );
  }

  void _stopTimers() {
    _ticker?.cancel();
    _messageTimer?.cancel();
    _highlightTimer?.cancel();
    _resultTimer?.cancel();
  }
}
