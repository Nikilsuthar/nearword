import 'achievement.dart';
import 'puzzle.dart';

/// Everything the Result screen needs. Built by GameController when a game ends.
class GameResult {
  const GameResult({
    required this.puzzleId,
    required this.mode,
    required this.title,
    required this.difficulty,
    required this.won,
    required this.secretWord,
    required this.guessCount,
    required this.seconds,
    required this.hintsUsed,
    required this.guessRanks,
    this.closestWords = const [],
    this.coinsEarned = 0,
    this.newAchievements = const [],
    this.alreadyRecorded = false,
  });

  final String puzzleId;
  final PuzzleMode mode;

  /// "Daily #42", "Animals", "Quick play", "Battle" ...
  final String title;
  final Difficulty difficulty;
  final bool won;
  final String secretWord;
  final int guessCount;
  final int seconds;
  final int hintsUsed;

  /// Ranks of every guess in the order they were made (used for the share grid).
  final List<int> guessRanks;

  /// The words nearest to the secret (rank 2, 3, ...), shown after the game.
  final List<String> closestWords;

  /// Coins granted for this game (win reward + achievement rewards).
  final int coinsEarned;
  final List<Achievement> newAchievements;

  /// True when a finished game is re-opened: no rewards are given again.
  final bool alreadyRecorded;
}
