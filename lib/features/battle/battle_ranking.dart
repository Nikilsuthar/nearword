import '../../data/models/battle.dart';

/// Pure scoring logic for battles ("who is nearest?").
class BattleRanking {
  BattleRanking._();

  /// Order of standings, best first:
  ///  1. players who solved it, fastest first;
  ///  2. everyone else by closest rank reached, then fewest guesses;
  ///  3. players who have not guessed yet, by name (stable).
  static List<BattlePlayer> standings(Iterable<BattlePlayer> players) {
    final list = players.toList();
    list.sort((a, b) {
      if (a.solved != b.solved) return a.solved ? -1 : 1;
      if (a.solved && b.solved) {
        final t = a.solvedMs.compareTo(b.solvedMs);
        if (t != 0) return t;
        final g = a.guesses.compareTo(b.guesses);
        if (g != 0) return g;
        return a.id.compareTo(b.id);
      }
      final r = a.bestRank.compareTo(b.bestRank);
      if (r != 0) return r;
      final g = a.guesses.compareTo(b.guesses);
      if (g != 0) return g;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  /// 1-based place of [playerId], or 0 if absent.
  static int placeOf(String playerId, Iterable<BattlePlayer> players) {
    final order = standings(players);
    final i = order.indexWhere((p) => p.id == playerId);
    return i < 0 ? 0 : i + 1;
  }

  /// Whether the round is over, given everyone's state and the time elapsed
  /// since the start. Pure so every client reaches the same verdict.
  static bool isRoundOver({
    required Iterable<BattlePlayer> players,
    required int elapsedMs,
    required int durationSec,
    required int graceSec,
  }) {
    final list = players.toList();
    if (list.isEmpty) return true;
    if (elapsedMs >= durationSec * 1000) return true;
    if (list.every((p) => p.done)) return true;
    final solvedTimes = [
      for (final p in list)
        if (p.solved) p.solvedMs,
    ];
    if (solvedTimes.isNotEmpty) {
      solvedTimes.sort();
      // Everyone else gets a last-chance window after the first solver.
      if (elapsedMs >= solvedTimes.first + graceSec * 1000) return true;
    }
    return false;
  }
}
