import 'dart:math';

import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/semantic_engine.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/seeded.dart';
import '../models/category.dart';
import '../models/puzzle.dart';

/// Single access point for puzzles. Puzzle ids are self-describing (see
/// [Puzzle]), so nothing needs to be stored or downloaded: the secret is
/// derived from the id and the ranking is computed by [SemanticEngine].
///
/// Ids carry the word set and level, so two players with different settings
/// can still join the same room/challenge and get the same word.
class PuzzleRepository extends GetxService {
  PuzzleRepository(
    this.engine, {
    DateTime Function()? clock,
    Set<String> Function()? recentSecrets,
  })  : _clock = clock ?? DateTime.now,
        _recent = recentSecrets;

  final SemanticEngine engine;
  final DateTime Function() _clock;
  final Set<String> Function()? _recent;

  /// Daily order per pool: a fixed shuffle, so a word never repeats until the
  /// whole pool has been used.
  final Map<String, List<String>> _dailyOrder = {};

  /// The repository's notion of "now" (injectable for tests).
  DateTime get now => _clock();

  List<Category> get categories => engine.categories;

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // --- Ids -----------------------------------------------------------------

  static String _tag(WordSet s, Difficulty l) => '${s.code}${l.code}';

  static String dailyIdFor(DateTime date, WordSet set, Difficulty level) =>
      'daily-${DateHelper.dayKey(date)}-${_tag(set, level)}';

  String todaysDailyId(WordSet set, Difficulty level) =>
      dailyIdFor(_clock(), set, level);

  int dailyNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(AppConstants.dailyEpoch).inDays + 1;
  }

  /// A fresh random puzzle id. Avoids secrets the player saw recently.
  String randomId(WordSet set, Difficulty level, {Random? random}) =>
      _fresh((code) => 'rnd-${_tag(set, level)}-$code', random);

  String randomCategoryId(
    String categoryId,
    WordSet set,
    Difficulty level, {
    Random? random,
  }) =>
      _fresh((code) => 'cat-$categoryId-${_tag(set, level)}-$code', random);

  /// New room/challenge code whose word is not one the player saw recently.
  /// [idOf] maps a code to the puzzle id it will use.
  String newRoomCode(String Function(String code) idOf, {Random? random}) {
    String? last;
    final recent = _recent?.call() ?? const <String>{};
    for (var i = 0; i < 40; i++) {
      final code = Seeded.randomCode(
        AppConstants.battleCodeLength,
        random ?? Random.secure(),
      );
      last = code;
      final p = puzzleById(idOf(code));
      if (p != null && !recent.contains(p.secret)) return code;
    }
    return last!;
  }

  static String battleIdFor(String code, WordSet set, Difficulty level) =>
      'battle-${_tag(set, level)}-$code';

  static String challengeIdFor(String code, WordSet set, Difficulty level) =>
      'chal-${_tag(set, level)}-$code';

  String _fresh(String Function(String code) make, Random? random) {
    final recent = _recent?.call() ?? const <String>{};
    String? last;
    for (var i = 0; i < 40; i++) {
      final id = make(Seeded.randomCode(6, random ?? Random()));
      last = id;
      final p = puzzleById(id);
      if (p != null && !recent.contains(p.secret)) return id;
    }
    return last!;
  }

  // --- Resolution ---------------------------------------------------------------

  static final _daily = RegExp(r'^daily-(\d{4}-\d{2}-\d{2})-([ri])([emh])$');
  static final _rnd = RegExp(r'^rnd-([ri])([emh])-([A-Z0-9]+)$');
  static final _cat = RegExp(r'^cat-([a-z]+)-([ri])([emh])-([A-Z0-9]+)$');
  static final _battle = RegExp(r'^battle-([ri])([emh])-([A-Z0-9]+)$');
  static final _chal = RegExp(r'^chal-([ri])([emh])-([A-Z0-9]+)$');

  List<String> _dailyOrderFor(WordSet set, Difficulty level) {
    return _dailyOrder.putIfAbsent(_tag(set, level), () {
      final pool = engine.pool(set, level);
      final keyed = {
        for (final w in pool) w: Seeded.hash('nearword-daily|$w'),
      };
      return [...pool]..sort((a, b) {
          final c = keyed[a]!.compareTo(keyed[b]!);
          return c != 0 ? c : a.compareTo(b);
        });
    });
  }

  Puzzle _build(
    String id,
    PuzzleMode mode,
    String category,
    WordSet set,
    Difficulty level,
    String word, {
    int? number,
  }) =>
      Puzzle(
        id: id,
        mode: mode,
        category: category,
        // The word's own tier in this set (it can differ from the chosen
        // level when a small pool was widened).
        difficulty: engine.secretByWord[word]?.tierIn(set) ?? level,
        level: level,
        wordSet: set,
        secret: word,
        number: number,
      );

  /// Rebuilds a puzzle from its id (null if the id is malformed).
  Puzzle? puzzleById(String id) {
    if (engine.secrets.isEmpty) return null;

    var m = _daily.firstMatch(id);
    if (m != null) {
      final date = DateTime.tryParse(m.group(1)!);
      if (date == null) return null;
      final set = WordSet.fromCode(m.group(2)!);
      final level = Difficulty.fromCode(m.group(3)!);
      final order = _dailyOrderFor(set, level);
      final n = dailyNumber(date);
      final word = order[(n - 1) % order.length];
      return _build(id, PuzzleMode.daily, 'daily', set, level, word, number: n);
    }
    m = _rnd.firstMatch(id);
    if (m != null) {
      final set = WordSet.fromCode(m.group(1)!);
      final level = Difficulty.fromCode(m.group(2)!);
      final word = Seeded.pick(engine.pool(set, level), id);
      return _build(id, PuzzleMode.random, 'random', set, level, word);
    }
    m = _cat.firstMatch(id);
    if (m != null) {
      final set = WordSet.fromCode(m.group(2)!);
      final level = Difficulty.fromCode(m.group(3)!);
      final words = engine.categoryPool(m.group(1)!, set, level);
      if (words.isEmpty) return null;
      return _build(id, PuzzleMode.category, m.group(1)!, set, level,
          Seeded.pick(words, id));
    }
    m = _battle.firstMatch(id);
    if (m != null) {
      final set = WordSet.fromCode(m.group(1)!);
      final level = Difficulty.fromCode(m.group(2)!);
      return _build(id, PuzzleMode.battle, 'battle', set, level,
          Seeded.pick(engine.pool(set, level), id));
    }
    m = _chal.firstMatch(id);
    if (m != null) {
      final set = WordSet.fromCode(m.group(1)!);
      final level = Difficulty.fromCode(m.group(2)!);
      return _build(id, PuzzleMode.challenge, 'challenge', set, level,
          Seeded.pick(engine.pool(set, level), id));
    }
    return null;
  }

  /// Number of themed puzzles available in a category.
  int sizeOf(String categoryId, WordSet set, Difficulty level) =>
      engine.categoryPool(categoryId, set, level).length;
}
