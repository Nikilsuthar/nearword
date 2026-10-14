import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/backend_config.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/rtdb_client.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/seeded.dart';
import '../../data/models/battle.dart';
import '../../data/models/puzzle.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import 'battle_backend.dart';
import 'battle_ranking.dart';
import 'bot_driver.dart';

enum BattlePhase { idle, lobby, countdown, playing, over }

/// What a game screen needs from the room it is part of.
abstract class BattleLink {
  /// Milliseconds left in the round / until the challenge closes.
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

/// Runs live battles and challenges: rooms, coin stakes, timers, standings and
/// payouts. Error strings are translation keys.
class BattleController extends GetxController implements BattleLink {
  BattleController({
    BattleBackend? backend,
    SettingsService? settings,
    StorageService? storage,
    StatsRepository? stats,
    PuzzleRepository? repository,
    FirebaseAuthService? auth,
    DateTime Function()? clock,
    this.heartbeat = const Duration(seconds: 4),
    this.countdownSeconds = AppConstants.battleCountdownSeconds,
  })  : _injected = backend,
        _settings = settings ?? Get.find<SettingsService>(),
        _storage = storage ?? Get.find<StorageService>(),
        _stats = stats ?? Get.find<StatsRepository>(),
        _repo = repository ?? Get.find<PuzzleRepository>(),
        _auth = auth ??
            (Get.isRegistered<FirebaseAuthService>()
                ? Get.find<FirebaseAuthService>()
                : null),
        _clock = clock ?? DateTime.now;

  final BattleBackend? _injected;
  final SettingsService _settings;
  final StorageService _storage;
  final StatsRepository _stats;
  final PuzzleRepository _repo;
  final FirebaseAuthService? _auth;
  final DateTime Function() _clock;
  final Duration heartbeat;
  final int countdownSeconds;

  BattleBackend? _backend;
  StreamSubscription<BattleRoom?>? _sub;
  BotDriver? _bots;
  Timer? _ticker;
  Timer? _heartbeat;
  Timer? _countdownTimer;

  final Rxn<BattleRoom> room = Rxn<BattleRoom>();
  final Rx<BattlePhase> phase = BattlePhase.idle.obs;

  /// Translation key of the last problem (null = none).
  final RxnString error = RxnString();
  final RxBool connectionLost = false.obs;
  final RxBool busy = false.obs;
  final RxInt countdown = 0.obs;
  final RxBool practice = false.obs;

  /// Coins I received from the finished room (null until settled).
  final RxnInt myPayout = RxnInt();

  @override
  final RxInt remainingMs = 0.obs;
  @override
  final RxBool over = false.obs;

  int _startLocalMs = 0;
  int _endedSeenMs = 0;
  bool _finalizing = false;
  BattlePlayer? _me;

  // --- Identity & derived values ----------------------------------------------

  String get playerId => _auth?.uid.value ?? _settings.playerId;
  String get code => room.value?.code ?? '';
  bool get isHost => room.value?.hostId == playerId;
  bool get isChallenge => room.value?.isChallenge ?? false;
  bool get online => BackendConfig.online;

  Puzzle? get puzzle => room.value == null ? null : _repo.puzzleById(puzzleId);

  String get puzzleId {
    final r = room.value!;
    return r.isChallenge
        ? PuzzleRepository.challengeIdFor(r.code, r.wordSet, r.level)
        : PuzzleRepository.battleIdFor(r.code, r.wordSet, r.level);
  }

  List<BattlePlayer> get standings => BattleRanking.standings(
        _rosterPlayers(),
        fewestGuessesFirst: isChallenge,
      );

  int get myPlace => BattleRanking.placeOf(
        playerId,
        _rosterPlayers(),
        fewestGuessesFirst: isChallenge,
      );

  BattlePlayer? get me => room.value?.players[playerId] ?? _me;

  /// Players that count: everyone in the room (lobby) or the roster.
  List<BattlePlayer> _rosterPlayers() {
    final r = room.value;
    if (r == null) return const [];
    if (r.roster.isEmpty) return r.players.values.toList();
    return [
      for (final id in r.roster)
        if (r.players[id] != null) r.players[id]!,
    ];
  }

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
    if (practiceMode) return MemoryBattleBackend();
    return RtdbBattleBackend(
      RtdbClient(BackendConfig.databaseUrl, tokenProvider: _auth?.idToken),
    );
  }

  BattlePlayer _newMe({int stake = 0}) => BattlePlayer(
        id: playerId,
        name: _settings.nickname.value.isEmpty
            ? 'Player'
            : _settings.nickname.value,
        avatar: Seeded.hash(playerId) % 8,
        seen: _clock().millisecondsSinceEpoch,
        stake: stake,
      );

  // --- Coins ---------------------------------------------------------------------

  /// Takes [stake] coins out of the balance and records them as escrow.
  bool _lockStake(String code, int stake, RoomKind kind) {
    if (stake <= 0) return true;
    if (!_stats.spendCoins(stake)) return false;
    _storage.setEscrow(code, {
      'stake': stake,
      'kind': kind.name,
      'ts': _clock().millisecondsSinceEpoch,
    });
    return true;
  }

  void _refundStake(String code) {
    final info = _storage.escrows()[code];
    if (info == null) return;
    _stats.addCoins((info['stake'] as num).toInt());
    _storage.clearEscrow(code);
  }

  /// Pays out a finished room exactly once.
  void _applyPayout(BattleRoom r) {
    final result = r.result;
    if (result == null || _storage.isRoomPaid(r.code)) return;
    _storage.markRoomPaid(r.code);
    final amount = result.payouts[playerId] ?? 0;
    if (amount > 0) _stats.addCoins(amount);
    _storage.clearEscrow(r.code);
    myPayout.value = amount;
  }

  // --- Creating & joining ---------------------------------------------------------

  /// Creates a live battle room.
  Future<bool> createRoom({
    required bool practiceMode,
    int durationSec = 180,
    Difficulty? level,
    WordSet? wordSet,
    int stake = 0,
  }) =>
      _create(
        kind: RoomKind.live,
        practiceMode: practiceMode,
        durationSec: durationSec,
        level: level,
        wordSet: wordSet,
        stake: practiceMode ? 0 : stake,
      );

  /// Creates a challenge: a code friends can play any time before [windowSec]
  /// runs out.
  Future<bool> createChallenge({
    required int windowSec,
    Difficulty? level,
    WordSet? wordSet,
    int stake = 0,
  }) =>
      _create(
        kind: RoomKind.challenge,
        practiceMode: false,
        durationSec: windowSec,
        level: level,
        wordSet: wordSet,
        stake: stake,
      );

  Future<bool> _create({
    required RoomKind kind,
    required bool practiceMode,
    required int durationSec,
    required Difficulty? level,
    required WordSet? wordSet,
    required int stake,
  }) async {
    if (busy.value) return false;
    busy.value = true;
    error.value = null;
    String? lockedCode;
    try {
      await _reset();
      practice.value = practiceMode;
      final lvl = level ?? _settings.level.value;
      final set = wordSet ?? _settings.wordSet.value;
      final code = _repo.newRoomCode(
        (c) => kind == RoomKind.live
            ? PuzzleRepository.battleIdFor(c, set, lvl)
            : PuzzleRepository.challengeIdFor(c, set, lvl),
      );
      if (!_lockStake(code, stake, kind)) {
        error.value = 'err_no_coins';
        return false;
      }
      lockedCode = stake > 0 ? code : null;
      _backend = _createBackend(practiceMode: practiceMode);
      final now = _clock().millisecondsSinceEpoch;
      final newRoom = BattleRoom(
        code: code,
        hostId: playerId,
        kind: kind,
        status: kind == RoomKind.challenge
            ? RoomStatus.playing
            : RoomStatus.lobby,
        durationSec: durationSec,
        startedAt: kind == RoomKind.challenge ? now : 0,
        createdAt: now,
        level: lvl,
        wordSet: set,
        stake: stake,
      );
      _me = _newMe(stake: stake);
      await _backend!.createRoom(newRoom, _me!);
      room.value = newRoom.copyWith(players: {playerId: _me!});
      _attach(code);
      if (practiceMode) {
        _bots = BotDriver(_backend!, code);
        await _bots!.join(3);
      }
      return true;
    } catch (e) {
      if (lockedCode != null) _refundStake(lockedCode);
      error.value = 'err_create';
      debugPrint('create failed: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Joins a live room or a challenge by its code.
  Future<bool> joinRoom(String rawCode) async {
    if (busy.value) return false;
    final code = Seeded.normalizeCode(rawCode);
    if (code.length < 5) {
      error.value = 'err_code_short';
      return false;
    }
    busy.value = true;
    error.value = null;
    var locked = false;
    try {
      await _reset();
      practice.value = false;
      _backend = _createBackend(practiceMode: false);
      final found = await _backend!.fetchRoom(code);
      if (found == null) {
        error.value = 'err_no_room';
        return false;
      }
      final already = found.players.containsKey(playerId);
      final now = _clock().millisecondsSinceEpoch;
      if (found.status == RoomStatus.finished && !already) {
        error.value = 'err_room_over';
        return false;
      }
      if (found.isChallenge && now >= found.deadline && !already) {
        error.value = 'err_room_over';
        return false;
      }
      if (!found.isChallenge && found.status != RoomStatus.lobby && !already) {
        error.value = 'err_started';
        return false;
      }
      if (found.players.length >= AppConstants.battleMaxPlayers && !already) {
        error.value = 'err_full';
        return false;
      }
      if (!already) {
        if (!_lockStake(code, found.stake, found.kind)) {
          error.value = 'err_no_coins';
          return false;
        }
        locked = found.stake > 0;
      }
      _me = already ? found.players[playerId] : _newMe(stake: found.stake);
      await _backend!.savePlayer(code, _me!);
      room.value = found.copyWith(players: {...found.players, playerId: _me!});
      _attach(code);
      return true;
    } catch (e) {
      if (locked) _refundStake(code);
      error.value = 'err_join';
      debugPrint('join failed: $e');
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
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _sendHeartbeat() {
    final mine = me;
    if (mine == null || _backend == null || code.isEmpty) return;
    _push(mine.copyWith(seen: _clock().millisecondsSinceEpoch));
  }

  void _onRoom(BattleRoom? r) {
    connectionLost.value = false;
    if (r == null) {
      // The host closed the room.
      if (phase.value == BattlePhase.lobby ||
          phase.value == BattlePhase.countdown) {
        _refundStake(code);
        error.value = 'err_room_closed';
        _stopTimers();
        phase.value = BattlePhase.idle;
      }
      return;
    }
    room.value = r;
    if (r.status == RoomStatus.finished) {
      _applyPayout(r);
      _finishLocally();
      return;
    }
    if (r.isChallenge) return;
    if (r.status == RoomStatus.playing && phase.value == BattlePhase.lobby) {
      _beginCountdown();
    }
  }

  // --- Live round -------------------------------------------------------------------

  /// Host only: starts the round for everyone.
  Future<void> start() async {
    final r = room.value;
    if (r == null || !isHost || r.status != RoomStatus.lobby || r.isChallenge) {
      return;
    }
    final present = livePlayers;
    if (present.length < 2) {
      error.value = 'err_need_player';
      return;
    }
    error.value = null;
    final roster = [for (final p in present) p.id];
    try {
      await _backend!.patchRoom(r.code, {
        'status': RoomStatus.playing.name,
        'startedAt': _clock().millisecondsSinceEpoch,
        'pot': r.stake * roster.length,
        'roster': {for (final id in roster) id: true},
      });
      // Show it immediately on the host without waiting for the next poll.
      _onRoom(r.copyWith(
        status: RoomStatus.playing,
        pot: r.stake * roster.length,
        roster: roster,
      ));
    } catch (e) {
      error.value = 'err_start';
    }
  }

  void _beginCountdown() {
    phase.value = BattlePhase.countdown;
    countdown.value = countdownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      countdown.value--;
      if (countdown.value <= 0) {
        t.cancel();
        beginPlaying();
      }
    });
  }

  /// Starts this player's own clock (live: after the countdown; challenge: when
  /// the player taps Play).
  void beginPlaying() {
    final r = room.value;
    if (r == null || over.value) return;
    _startLocalMs = _clock().millisecondsSinceEpoch;
    remainingMs.value = r.isChallenge
        ? max(0, r.deadline - _startLocalMs)
        : r.durationSec * 1000;
    phase.value = BattlePhase.playing;
    if (!r.isChallenge) _bots?.start(r.durationSec);
  }

  int get elapsedMs => _clock().millisecondsSinceEpoch - _startLocalMs;

  void _tick() {
    final r = room.value;
    if (r == null) return;
    final now = _clock().millisecondsSinceEpoch;

    if (r.isChallenge) {
      final left = max(0, r.deadline - now);
      remainingMs.value = left;
      if (left == 0 && r.status != RoomStatus.finished) _maybeFinalize(r);
      return;
    }
    if (phase.value != BattlePhase.playing) return;
    remainingMs.value = max(0, r.durationSec * 1000 - elapsedMs);
    final overNow = BattleRanking.isRoundOver(
      players: _liveRoster(r),
      elapsedMs: elapsedMs,
      durationSec: r.durationSec,
      graceSec: AppConstants.battleGraceSeconds,
    );
    if (overNow) _maybeFinalize(r);
  }

  List<BattlePlayer> _liveRoster(BattleRoom r) {
    final now = _clock().millisecondsSinceEpoch;
    return [
      for (final p in _rosterPlayers())
        if (p.isBot || p.done || now - p.seen < 45000) p,
    ];
  }

  /// The host closes the room; if the host vanished anyone does after a grace
  /// period. Settlement is computed once and stored in the room.
  Future<void> _maybeFinalize(BattleRoom r) async {
    if (_finalizing || r.status == RoomStatus.finished) return;
    final now = _clock().millisecondsSinceEpoch;
    if (_endedSeenMs == 0) _endedSeenMs = now;
    if (!isHost && now - _endedSeenMs < 8000) return;
    _finalizing = true;
    try {
      // Someone else may have finished it already.
      final fresh = await _backend?.fetchRoom(r.code) ?? r;
      if (fresh.status == RoomStatus.finished && fresh.result != null) {
        _onRoom(fresh);
        return;
      }
      final players = fresh.isChallenge
          ? fresh.players.values.toList()
          : [
              for (final id in fresh.roster)
                if (fresh.players[id] != null) fresh.players[id]!,
            ];
      final roster = players.isEmpty ? fresh.players.values.toList() : players;
      final result = RoomEconomy.settle(
        roster: roster,
        stake: fresh.stake,
        challenge: fresh.isChallenge,
      );
      final pot = fresh.stake * roster.length;
      await _backend?.patchRoom(r.code, {
        'status': RoomStatus.finished.name,
        'pot': pot,
        'result': result.toJson(),
        if (fresh.isChallenge) 'roster': {for (final p in roster) p.id: true},
      });
      _onRoom(fresh.copyWith(
        status: RoomStatus.finished,
        pot: pot,
        result: result,
        roster: [for (final p in roster) p.id],
      ));
    } catch (e) {
      debugPrint('finalize failed: $e');
    } finally {
      _finalizing = false;
    }
  }

  /// Challenge creator: close the challenge now instead of waiting.
  Future<void> endChallengeNow() async {
    final r = room.value;
    if (r == null || !isHost || !r.isChallenge) return;
    await _maybeFinalize(r);
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
    final r = room.value;
    final inLobby =
        phase.value == BattlePhase.lobby && !(r?.isChallenge ?? false);
    final wasHost = isHost;
    await _reset();
    if (b != null && c.isNotEmpty && inLobby) {
      // Leaving before the start gives the stake back.
      _refundStake(c);
      try {
        if (wasHost) {
          await b.deleteRoom(c);
        } else {
          await b.removePlayer(c, playerId);
        }
      } catch (_) {}
    }
  }

  // --- Recovery -----------------------------------------------------------------------

  /// Settles rooms whose result arrived while the app was closed and returns
  /// stakes of rooms that disappeared. Safe to call at any time.
  Future<void> reconcile() async {
    if (!BackendConfig.online) return;
    final pending = _storage.escrows();
    if (pending.isEmpty) return;
    final backend = _createBackend(practiceMode: false);
    try {
      for (final e in pending.entries) {
        final code = e.key;
        final ts = (e.value['ts'] as num?)?.toInt() ?? 0;
        final now = _clock().millisecondsSinceEpoch;
        try {
          final r = await backend.fetchRoom(code);
          if (r == null) {
            _refundStake(code);
          } else if (r.status == RoomStatus.finished && r.result != null) {
            _applyPayout(r);
          } else if (r.isChallenge && now >= r.deadline) {
            // Deadline passed: settle it ourselves.
            final players = r.players.values.toList();
            final result = RoomEconomy.settle(
              roster: players,
              stake: r.stake,
              challenge: true,
            );
            await backend.patchRoom(code, {
              'status': RoomStatus.finished.name,
              'pot': r.stake * players.length,
              'result': result.toJson(),
              'roster': {for (final p in players) p.id: true},
            });
            _applyPayout(r.copyWith(
              status: RoomStatus.finished,
              result: result,
              roster: [for (final p in players) p.id],
            ));
          } else if (!r.isChallenge && now - ts > 3 * 3600 * 1000) {
            _refundStake(code); // abandoned live room
          }
        } catch (_) {
          // Offline: try again next time.
        }
      }
    } finally {
      if (_injected == null) backend.dispose();
    }
  }

  // --- Cleanup -------------------------------------------------------------------------

  void _stopTimers() {
    _ticker?.cancel();
    _heartbeat?.cancel();
    _countdownTimer?.cancel();
    _bots?.dispose();
    _bots = null;
  }

  Future<void> _reset() async {
    // Not awaited: cancelling a local subscription completes synchronously
    // for our streams, and awaiting here delays the state reset below.
    _sub?.cancel();
    _sub = null;
    _stopTimers();
    if (_injected == null) _backend?.dispose();
    _backend = null;
    room.value = null;
    _me = null;
    over.value = false;
    remainingMs.value = 0;
    phase.value = BattlePhase.idle;
    connectionLost.value = false;
    myPayout.value = null;
    _endedSeenMs = 0;
    _finalizing = false;
  }

  @override
  void onClose() {
    _reset();
    super.onClose();
  }
}
