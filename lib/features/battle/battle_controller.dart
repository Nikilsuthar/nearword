import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/backend_config.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/seeded.dart';
import '../../data/models/battle.dart';
import '../../data/repositories/puzzle_repository.dart';
import 'battle_backend.dart';
import 'battle_ranking.dart';
import 'bot_driver.dart';

enum BattlePhase { idle, lobby, countdown, playing, over }

/// What a game screen needs from the battle it is part of.
abstract class BattleLink {
  /// Milliseconds left in the round (0 when over).
  RxInt get remainingMs;

  /// True once the whole round is finished for everyone.
  RxBool get over;

  void report({
    required int bestRank,
    required int guesses,
    required bool solved,
    required bool done,
  });
}

class BattleController extends GetxController implements BattleLink {
  BattleController({
    BattleBackend? backend,
    SettingsService? settings,
    DateTime Function()? clock,
    this.heartbeat = const Duration(seconds: 4),
  })  : _injected = backend,
        _settings = settings ?? Get.find<SettingsService>(),
        _clock = clock ?? DateTime.now;

  final BattleBackend? _injected;
  final SettingsService _settings;
  final DateTime Function() _clock;
  final Duration heartbeat;

  BattleBackend? _backend;
  StreamSubscription<BattleRoom?>? _sub;
  BotDriver? _bots;
  Timer? _ticker;
  Timer? _heartbeat;
  Timer? _countdownTimer;

  final Rxn<BattleRoom> room = Rxn<BattleRoom>();
  final Rx<BattlePhase> phase = BattlePhase.idle.obs;
  final RxnString error = RxnString();
  final RxBool connectionLost = false.obs;
  final RxBool busy = false.obs;
  final RxInt countdown = 0.obs;
  final RxBool practice = false.obs;

  @override
  final RxInt remainingMs = 0.obs;
  @override
  final RxBool over = false.obs;

  int _startLocalMs = 0;
  BattlePlayer? _me;

  String get playerId => _settings.playerId;
  String get code => room.value?.code ?? '';
  bool get isHost => room.value?.hostId == playerId;
  String get puzzleId => PuzzleRepository.battleIdFor(code);
  bool get online => BackendConfig.online;

  List<BattlePlayer> get standings =>
      BattleRanking.standings(room.value?.players.values ?? const []);

  int get myPlace => BattleRanking.placeOf(playerId, standings);
  BattlePlayer? get me => room.value?.players[playerId] ?? _me;

  /// Lobby players that are still heartbeating (bots always count).
  List<BattlePlayer> get livePlayers {
    final now = _clock().millisecondsSinceEpoch;
    return [
      for (final p in room.value?.players.values ?? const <BattlePlayer>[])
        if (p.isBot || p.done || now - p.seen < 45000) p,
    ];
  }

  BattleBackend _createBackend({required bool practiceMode}) {
    if (_injected != null) return _injected;
    return practiceMode
        ? MemoryBattleBackend()
        : RtdbBattleBackend(BackendConfig.databaseUrl);
  }

  BattlePlayer _newMe() => BattlePlayer(
        id: playerId,
        name: _settings.nickname.value.isEmpty
            ? 'Player'
            : _settings.nickname.value,
        avatar: Seeded.hash(playerId) % 8,
        seen: _clock().millisecondsSinceEpoch,
      );

  // --- Lobby ---------------------------------------------------------------------

  Future<bool> createRoom({required bool practiceMode, int durationSec = 180}) async {
    if (busy.value) return false;
    busy.value = true;
    error.value = null;
    try {
      await _reset();
      practice.value = practiceMode;
      _backend = _createBackend(practiceMode: practiceMode);
      final code = Seeded.randomCode(AppConstants.battleCodeLength);
      final newRoom = BattleRoom(
        code: code,
        hostId: playerId,
        durationSec: durationSec,
      );
      _me = _newMe();
      await _backend!.createRoom(newRoom, _me!);
      room.value = newRoom.copyWith(players: {playerId: _me!});
      _attach(code);
      if (practiceMode) {
        _bots = BotDriver(_backend!, code);
        await _bots!.join(3);
      }
      return true;
    } catch (e) {
      error.value = 'Could not create the room. Check your connection.';
      debugPrint('createRoom failed: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> joinRoom(String rawCode) async {
    if (busy.value) return false;
    final code = Seeded.normalizeCode(rawCode);
    if (code.length != AppConstants.battleCodeLength) {
      error.value = 'Codes have ${AppConstants.battleCodeLength} characters.';
      return false;
    }
    busy.value = true;
    error.value = null;
    try {
      await _reset();
      practice.value = false;
      _backend = _createBackend(practiceMode: false);
      final found = await _backend!.fetchRoom(code);
      if (found == null) {
        error.value = 'No room with code $code.';
        return false;
      }
      if (found.status != RoomStatus.lobby &&
          !found.players.containsKey(playerId)) {
        error.value = 'That battle has already started.';
        return false;
      }
      if (found.players.length >= AppConstants.battleMaxPlayers &&
          !found.players.containsKey(playerId)) {
        error.value = 'That room is full.';
        return false;
      }
      _me = _newMe();
      await _backend!.savePlayer(code, _me!);
      room.value = found.copyWith(players: {...found.players, playerId: _me!});
      _attach(code);
      return true;
    } catch (e) {
      error.value = 'Could not join. Check your connection.';
      debugPrint('joinRoom failed: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  void _attach(String code) {
    phase.value = BattlePhase.lobby;
    _sub = _backend!.watchRoom(code).listen(
      _onRoom,
      onError: (_) => connectionLost.value = true,
    );
    _heartbeat = Timer.periodic(heartbeat, (_) => _sendHeartbeat());
  }

  void _sendHeartbeat() {
    final mine = me;
    if (mine == null || _backend == null || code.isEmpty) return;
    _push(mine.copyWith(seen: _clock().millisecondsSinceEpoch));
  }

  void _onRoom(BattleRoom? r) {
    connectionLost.value = false;
    if (r == null) {
      if (phase.value != BattlePhase.over) {
        error.value = 'The room was closed.';
        phase.value = BattlePhase.idle;
      }
      return;
    }
    room.value = r;
    switch (r.status) {
      case RoomStatus.lobby:
        break;
      case RoomStatus.playing:
        if (phase.value == BattlePhase.lobby) _beginCountdown();
      case RoomStatus.finished:
        _finishLocally();
    }
  }

  // --- Round ---------------------------------------------------------------------------

  /// Host only: starts the round for everyone.
  Future<void> start() async {
    final r = room.value;
    if (r == null || !isHost || r.status != RoomStatus.lobby) return;
    if (livePlayers.length < 2) {
      error.value = 'Wait for at least one more player.';
      return;
    }
    error.value = null;
    try {
      await _backend!.patchRoom(r.code, {
        'status': RoomStatus.playing.name,
        'startedAt': _clock().millisecondsSinceEpoch,
      });
      // Show it immediately on the host without waiting for the next poll.
      _onRoom(r.copyWith(status: RoomStatus.playing));
    } catch (e) {
      error.value = 'Could not start. Please try again.';
    }
  }

  void _beginCountdown() {
    phase.value = BattlePhase.countdown;
    countdown.value = AppConstants.battleCountdownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      countdown.value--;
      if (countdown.value <= 0) {
        t.cancel();
        _beginPlaying();
      }
    });
  }

  void _beginPlaying() {
    final r = room.value;
    if (r == null) return;
    _startLocalMs = _clock().millisecondsSinceEpoch;
    remainingMs.value = r.durationSec * 1000;
    phase.value = BattlePhase.playing;
    _bots?.start(r.durationSec);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  int get elapsedMs => _clock().millisecondsSinceEpoch - _startLocalMs;

  void _tick() {
    final r = room.value;
    if (r == null || phase.value != BattlePhase.playing) return;
    remainingMs.value = (r.durationSec * 1000 - elapsedMs).clamp(0, 1 << 31);
    final overNow = BattleRanking.isRoundOver(
      players: livePlayers,
      elapsedMs: elapsedMs,
      durationSec: r.durationSec,
      graceSec: AppConstants.battleGraceSeconds,
    );
    if (overNow) {
      // Idempotent: whoever notices first closes the round for everyone.
      _backend?.patchRoom(r.code, {'status': RoomStatus.finished.name});
      _finishLocally();
    }
  }

  void _finishLocally() {
    if (phase.value == BattlePhase.over) return;
    phase.value = BattlePhase.over;
    over.value = true;
    remainingMs.value = 0;
    _ticker?.cancel();
    _heartbeat?.cancel(); // nothing left to report once the round is over
    _countdownTimer?.cancel();
    _bots?.dispose();
  }

  @override
  void report({
    required int bestRank,
    required int guesses,
    required bool solved,
    required bool done,
  }) {
    final mine = me ?? _newMe();
    _push(mine.copyWith(
      bestRank: bestRank,
      guesses: guesses,
      solved: solved,
      solvedMs: solved ? elapsedMs : mine.solvedMs,
      done: done,
      seen: _clock().millisecondsSinceEpoch,
    ));
  }

  /// Updates my row locally right away, then syncs.
  void _push(BattlePlayer p) {
    _me = p;
    final r = room.value;
    if (r != null) {
      room.value = r.copyWith(players: {...r.players, p.id: p});
    }
    _backend?.savePlayer(code, p).catchError((Object e) {
      connectionLost.value = true;
    });
  }

  // --- Leaving ------------------------------------------------------------------------

  Future<void> leave() async {
    final c = code;
    final b = _backend;
    final wasLobby = phase.value == BattlePhase.lobby;
    await _reset();
    if (b != null && c.isNotEmpty && wasLobby) {
      try {
        await b.removePlayer(c, playerId);
      } catch (_) {}
    }
  }

  Future<void> _reset() async {
    // Not awaited: cancelling a local subscription completes synchronously
    // for our streams, and awaiting here delays the state reset below.
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _heartbeat?.cancel();
    _countdownTimer?.cancel();
    _bots?.dispose();
    _bots = null;
    if (_injected == null) _backend?.dispose();
    _backend = null;
    room.value = null;
    _me = null;
    over.value = false;
    remainingMs.value = 0;
    phase.value = BattlePhase.idle;
    connectionLost.value = false;
  }

  @override
  void onClose() {
    _reset();
    super.onClose();
  }
}
