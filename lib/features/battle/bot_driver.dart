import 'dart:async';
import 'dart:math';

import '../../data/models/battle.dart';
import 'battle_backend.dart';

/// Simulated opponents for practice battles. Each bot walks its rank down
/// (20000 -> ... -> 1) with random pauses, and some bots never quite make it.
class BotDriver {
  BotDriver(this.backend, this.code, {Random? random})
      : _random = random ?? Random();

  final BattleBackend backend;
  final String code;
  final Random _random;
  final List<Timer> _timers = [];
  final List<BattlePlayer> _bots = [];

  static const _names = [
    'Nova',
    'Pixel',
    'Echo',
    'Mango',
    'Zephyr',
    'Juno',
    'Ember',
    'Riff',
  ];

  /// Adds [count] bots to the lobby.
  Future<void> join(int count) async {
    final names = [..._names]..shuffle(_random);
    for (var i = 0; i < count; i++) {
      final bot = BattlePlayer(
        id: 'bot${i + 1}',
        name: names[i],
        avatar: _random.nextInt(8),
        isBot: true,
        seen: DateTime.now().millisecondsSinceEpoch,
      );
      _bots.add(bot);
      await backend.savePlayer(code, bot);
    }
  }

  /// Starts every bot's simulated round of [durationSec] seconds.
  void start(int durationSec) {
    for (var i = 0; i < _bots.length; i++) {
      _play(i, durationSec);
    }
  }

  void _play(int i, int durationSec) {
    var bot = _bots[i];
    final skill = 0.35 + _random.nextDouble() * 0.4; // lower = better
    final willSolve = _random.nextDouble() < 0.65;
    final solveAfter =
        (durationSec * (0.35 + _random.nextDouble() * 0.55)).round();
    var rank = 8000 + _random.nextInt(20000);
    var elapsed = 0;

    void step() {
      if (bot.done) return;
      elapsed += 3 + _random.nextInt(5);
      if (elapsed >= durationSec) return;
      final improve = _random.nextDouble() < 0.7;
      if (improve) {
        rank = max(2, (rank * (skill + _random.nextDouble() * 0.3)).round());
      }
      final solves = willSolve && elapsed >= solveAfter;
      bot = bot.copyWith(
        bestRank: solves ? 1 : min(bot.bestRank, rank),
        guesses: bot.guesses + 1,
        solved: solves,
        solvedMs: solves ? elapsed * 1000 : 0,
        done: solves,
        seen: DateTime.now().millisecondsSinceEpoch,
      );
      backend.savePlayer(code, bot);
      if (!solves) {
        _timers.add(Timer(Duration(seconds: 3 + _random.nextInt(5)), step));
      }
    }

    _timers.add(Timer(Duration(seconds: 2 + _random.nextInt(4)), step));
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}
