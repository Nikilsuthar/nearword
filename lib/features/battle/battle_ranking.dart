import '../../data/models/battle.dart';

/// Pure scoring logic for battles and challenges ("who is nearest?").
class BattleRanking {
  BattleRanking._();

  /// Order of standings, best first:
  ///  1. players who solved it. Live battle: fastest first. Challenge
  ///     ([fewestGuessesFirst]): fewest guesses first, then fastest;
  ///  2. everyone else by closest rank reached, then fewest guesses;
  ///  3. players who have not guessed yet, by id (stable).
  static List<BattlePlayer> standings(
    Iterable<BattlePlayer> players, {
    bool fewestGuessesFirst = false,
  }) {
    final list = players.toList();
    list.sort((a, b) {
      if (a.solved != b.solved) return a.solved ? -1 : 1;
      if (a.solved && b.solved) {
        final byTime = a.solvedMs.compareTo(b.solvedMs);
        final byGuess = a.guesses.compareTo(b.guesses);
        final first = fewestGuessesFirst ? byGuess : byTime;
        if (first != 0) return first;
        final second = fewestGuessesFirst ? byTime : byGuess;
        if (second != 0) return second;
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
  static int placeOf(
    String playerId,
    Iterable<BattlePlayer> players, {
    bool fewestGuessesFirst = false,
  }) {
    final order = standings(players, fewestGuessesFirst: fewestGuessesFirst);
    final i = order.indexWhere((p) => p.id == playerId);
    return i < 0 ? 0 : i + 1;
  }

  /// Whether a LIVE round is over, given everyone's state and the time elapsed
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

/// Coin rules for rooms (live battles and challenges).
///
///  * Every player puts [stake] coins into the pot when they join.
///  * Someone found the word: the best solver takes the WHOLE pot.
///  * Nobody found it: the player who got nearest takes 50% of the pot, every
///    other player gets back 50% of their own stake (they lose the other
///    half). Whatever is left over is simply gone.
class RoomEconomy {
  RoomEconomy._();

  static RoomResult settle({
    required List<BattlePlayer> roster,
    required int stake,
    required bool challenge,
  }) {
    if (roster.isEmpty) return const RoomResult(kind: 'none');
    final pot = stake * roster.length;
    final order = BattleRanking.standings(roster, fewestGuessesFirst: challenge);

    if (order.first.solved) {
      return RoomResult(
        kind: 'solved',
        winnerId: order.first.id,
        payouts: {if (pot > 0) order.first.id: pot},
      );
    }

    final half = stake ~/ 2;
    if (!order.first.hasGuessed) {
      return RoomResult(
        kind: 'none',
        payouts: {if (half > 0) for (final p in roster) p.id: half},
      );
    }
    final nearest = order.first;
    return RoomResult(
      kind: 'nearest',
      winnerId: nearest.id,
      payouts: {
        for (final p in roster)
          if (p.id == nearest.id ? pot ~/ 2 > 0 : half > 0)
            p.id: p.id == nearest.id ? pot ~/ 2 : half,
      },
    );
  }
}
