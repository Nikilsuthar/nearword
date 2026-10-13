import '../../core/constants/app_constants.dart';
import '../../data/models/game_result.dart';

/// Builds the spoiler-free, Wordle-style share text: one colored square per
/// guess (in the order they were made) and never the secret word.
class ShareText {
  ShareText._();

  static const int _perRow = 10;

  static String square(int rank) {
    if (rank <= AppConstants.greenMaxRank) return '🟩';
    if (rank <= AppConstants.yellowMaxRank) return '🟨';
    return '🟥';
  }

  static String build(GameResult r) {
    final buffer = StringBuffer()
      ..writeln(
        '${AppConstants.appName} · ${r.title} · ${r.won ? '${r.guessCount} guesses' : 'gave up after ${r.guessCount}'}',
      );

    final squares = r.guessRanks.map(square).toList();
    for (var i = 0; i < squares.length; i += _perRow) {
      final end = i + _perRow > squares.length ? squares.length : i + _perRow;
      buffer.writeln(squares.sublist(i, end).join());
    }
    if (r.won) buffer.writeln('🏆');
    return buffer.toString().trimRight();
  }
}
