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
class PuzzleRepository extends GetxService {
  PuzzleRepository(this.engine, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SemanticEngine engine;
  final DateTime Function() _clock;

  List<Category> get categories => engine.categories;

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // --- Ids -----------------------------------------------------------------

  static String dailyIdFor(DateTime date) => 'daily-${DateHelper.dayKey(date)}';

  String get todaysDailyId => dailyIdFor(_clock());

  int dailyNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(AppConstants.dailyEpoch).inDays + 1;
  }

  String randomId({Random? random}) =>
      'rnd-${Seeded.randomCode(6, random ?? Random())}';

  String randomCategoryId(String categoryId, {Random? random}) =>
      'cat-$categoryId-${Seeded.randomCode(6, random ?? Random())}';

  static String battleIdFor(String code) => 'battle-$code';

  // --- Resolution ---------------------------------------------------------------

  /// Rebuilds a puzzle from its id (null if the id is malformed).
  Puzzle? puzzleById(String id) {
    final secrets = engine.secrets;
    if (secrets.isEmpty) return null;

    if (id.startsWith('daily-')) {
      final date = DateTime.tryParse(id.substring(6));
      if (date == null) return null;
      // Daily words avoid the hardest tier so everyone gets a fair puzzle.
      final pool = secrets.where((s) => s.difficulty != Difficulty.hard).toList();
      final pick = Seeded.pick(pool, 'nearword-daily-${id.substring(6)}');
      return Puzzle(
        id: id,
        mode: PuzzleMode.daily,
        category: 'daily',
        difficulty: pick.difficulty,
        secret: pick.word,
        number: dailyNumber(date),
      );
    }
    if (id.startsWith('rnd-')) {
      final pick = Seeded.pick(secrets, id);
      return Puzzle(
        id: id,
        mode: PuzzleMode.random,
        category: 'random',
        difficulty: pick.difficulty,
        secret: pick.word,
      );
    }
    if (id.startsWith('cat-')) {
      final parts = id.split('-');
      if (parts.length < 3) return null;
      final words = engine.categoryWords[parts[1]];
      if (words == null || words.isEmpty) return null;
      final word = Seeded.pick(words, id);
      return Puzzle(
        id: id,
        mode: PuzzleMode.category,
        category: parts[1],
        difficulty: engine.secretByWord[word]!.difficulty,
        secret: word,
      );
    }
    if (id.startsWith('battle-')) {
      // Battles use easy/medium words only so rounds are winnable.
      final pool = secrets.where((s) => s.difficulty != Difficulty.hard).toList();
      final pick = Seeded.pick(pool, id);
      return Puzzle(
        id: id,
        mode: PuzzleMode.battle,
        category: 'battle',
        difficulty: pick.difficulty,
        secret: pick.word,
      );
    }
    return null;
  }

  /// Number of themed puzzles available in a category.
  int sizeOf(String categoryId) => engine.categoryWords[categoryId]?.length ?? 0;
}
