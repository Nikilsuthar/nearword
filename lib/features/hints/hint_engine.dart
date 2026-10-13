import 'dart:math';

enum HintType { betterWord, firstLetter, wordLength }

/// Pure hint logic (no GetX / Flutter) so it can be unit tested.
class HintEngine {
  HintEngine._();

  /// Rank aimed for when the player has no guesses yet.
  static const int _openingBestRank = 2000;

  /// Picks an unguessed word that is clearly closer than [bestRank] without
  /// giving the answer away: it aims for ~40% of the current best rank.
  /// Returns null when nothing better than the current best exists.
  static String? pickBetterWord(
    Map<String, int> rankings,
    Set<String> guessed,
    int? bestRank,
  ) {
    final upper = (bestRank ?? _openingBestRank) - 1;
    if (upper < 2) return null;
    final target = max(2, (upper * 0.4).round());

    String? best;
    var bestDistance = 1 << 30;
    for (final e in rankings.entries) {
      final rank = e.value;
      if (rank < 2 || rank > upper || guessed.contains(e.key)) continue;
      final distance = (rank - target).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = e.key;
      }
    }
    return best;
  }
}
