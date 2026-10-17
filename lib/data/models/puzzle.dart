/// How hard the secret word is to guess (how familiar the word is).
enum Difficulty {
  easy('e'),
  medium('m'),
  hard('h');

  const Difficulty(this.code);

  /// One-letter code used inside puzzle ids.
  final String code;

  static Difficulty fromCode(String c) =>
      Difficulty.values.firstWhere((d) => d.code == c, orElse: () => medium);
}

/// Which kind of words the secrets are drawn from.
enum WordSet {
  /// General English words.
  regular('r'),

  /// Everyday words an Indian player knows from daily life.
  india('i');

  const WordSet(this.code);

  final String code;

  static WordSet fromCode(String c) =>
      WordSet.values.firstWhere((s) => s.code == c, orElse: () => regular);
}

enum PuzzleMode { daily, random, category, battle, challenge }

/// A playable puzzle. The id fully determines the secret word, so a puzzle can
/// be re-created anywhere from its id alone (daily, friend challenges and
/// battle rooms all rely on this). `<ws>` = word set letter + level letter
/// (e.g. `rm` = regular, medium):
///
///   daily-2026-10-14-rm   rnd-rm-ABC123   cat-animals-rm-ABC123
///   battle-rm-K7Q2X       chal-im-K7Q2X
class Puzzle {
  const Puzzle({
    required this.id,
    required this.mode,
    required this.category,
    required this.difficulty,
    required this.level,
    required this.wordSet,
    required this.secret,
    this.number,
  });

  final String id;
  final PuzzleMode mode;

  /// Category id for category puzzles, otherwise the mode name.
  final String category;

  /// The word's own difficulty.
  final Difficulty difficulty;

  /// The level that was chosen when the puzzle was created (can differ from
  /// [difficulty] when a small pool was widened).
  final Difficulty level;
  final WordSet wordSet;
  final String secret;

  /// Day number for daily puzzles.
  final int? number;
}
