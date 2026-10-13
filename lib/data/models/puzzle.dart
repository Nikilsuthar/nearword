enum Difficulty { easy, medium, hard }

enum PuzzleMode { daily, random, category, battle }

/// A playable puzzle. The id fully determines the secret word, so a puzzle can
/// be re-created anywhere from its id alone (daily, friend challenges and
/// battle rooms all rely on this):
///
///   daily-2026-10-13   rnd-481516   cat-animals-481516   battle-K7Q2X
class Puzzle {
  const Puzzle({
    required this.id,
    required this.mode,
    required this.category,
    required this.difficulty,
    required this.secret,
    this.number,
  });

  final String id;
  final PuzzleMode mode;

  /// Category id for category puzzles, otherwise the mode name.
  final String category;
  final Difficulty difficulty;
  final String secret;

  /// Day number for daily puzzles.
  final int? number;

  String get label => switch (mode) {
        PuzzleMode.daily => 'Daily #$number',
        PuzzleMode.random => 'Quick play',
        PuzzleMode.category => 'Category',
        PuzzleMode.battle => 'Battle',
      };
}
