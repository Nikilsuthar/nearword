import 'puzzle.dart';

enum RoomStatus { lobby, playing, finished }

/// Live battle: everyone plays at the same time. Challenge: a code + deadline,
/// everyone plays whenever they like before the deadline.
enum RoomKind { live, challenge }

/// Rank used for players that have not guessed anything yet.
const int kNoRank = 1 << 30;

class BattlePlayer {
  const BattlePlayer({
    required this.id,
    required this.name,
    this.avatar = 0,
    this.bestRank = kNoRank,
    this.guesses = 0,
    this.solved = false,
    this.solvedMs = 0,
    this.done = false,
    this.isBot = false,
    this.seen = 0,
    this.stake = 0,
  });

  final String id;
  final String name;

  /// Index into the avatar colour palette.
  final int avatar;

  /// Closest rank this player has reached so far (1 = solved).
  final int bestRank;
  final int guesses;
  final bool solved;

  /// Milliseconds after the player's own start at which the word was solved.
  final int solvedMs;

  /// Solved, gave up, or ran out of time.
  final bool done;
  final bool isBot;

  /// Last heartbeat (epoch ms, sender clock).
  final int seen;

  /// Coins this player put into the pot.
  final int stake;

  bool get hasGuessed => bestRank != kNoRank;

  BattlePlayer copyWith({
    String? name,
    int? avatar,
    int? bestRank,
    int? guesses,
    bool? solved,
    int? solvedMs,
    bool? done,
    int? seen,
    int? stake,
  }) =>
      BattlePlayer(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        bestRank: bestRank ?? this.bestRank,
        guesses: guesses ?? this.guesses,
        solved: solved ?? this.solved,
        solvedMs: solvedMs ?? this.solvedMs,
        done: done ?? this.done,
        isBot: isBot,
        seen: seen ?? this.seen,
        stake: stake ?? this.stake,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatar': avatar,
        'best': hasGuessed ? bestRank : 0,
        'guesses': guesses,
        'solved': solved,
        'solvedMs': solvedMs,
        'done': done,
        'bot': isBot,
        'seen': seen,
        'stake': stake,
      };

  factory BattlePlayer.fromJson(String id, Map<dynamic, dynamic> json) {
    final best = (json['best'] as num?)?.toInt() ?? 0;
    return BattlePlayer(
      id: id,
      name: (json['name'] as String?) ?? 'Player',
      avatar: (json['avatar'] as num?)?.toInt() ?? 0,
      bestRank: best <= 0 ? kNoRank : best,
      guesses: (json['guesses'] as num?)?.toInt() ?? 0,
      solved: json['solved'] as bool? ?? false,
      solvedMs: (json['solvedMs'] as num?)?.toInt() ?? 0,
      done: json['done'] as bool? ?? false,
      isBot: json['bot'] as bool? ?? false,
      seen: (json['seen'] as num?)?.toInt() ?? 0,
      stake: (json['stake'] as num?)?.toInt() ?? 0,
    );
  }
}

/// How a finished room paid out.
class RoomResult {
  const RoomResult({
    required this.kind,
    this.winnerId,
    this.payouts = const {},
  });

  /// 'solved' (someone found the word), 'nearest' (nobody did) or 'none'.
  final String kind;
  final String? winnerId;

  /// player id -> coins paid back.
  final Map<String, int> payouts;

  bool get solved => kind == 'solved';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (winnerId != null) 'winner': winnerId,
        'payouts': payouts,
      };

  static RoomResult? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final p = raw['payouts'];
    return RoomResult(
      kind: (raw['kind'] as String?) ?? 'none',
      winnerId: raw['winner'] as String?,
      payouts: {
        if (p is Map)
          for (final e in p.entries) '${e.key}': (e.value as num).toInt(),
      },
    );
  }
}

class BattleRoom {
  const BattleRoom({
    required this.code,
    required this.hostId,
    this.kind = RoomKind.live,
    this.status = RoomStatus.lobby,
    this.durationSec = 180,
    this.startedAt = 0,
    this.createdAt = 0,
    this.level = Difficulty.medium,
    this.wordSet = WordSet.regular,
    this.stake = 0,
    this.pot = 0,
    this.roster = const [],
    this.result,
    this.players = const {},
  });

  final String code;
  final String hostId;
  final RoomKind kind;
  final RoomStatus status;

  /// Live: length of the round. Challenge: length of the play window.
  final int durationSec;

  /// Epoch ms (creator clock) at which the round / window started.
  final int startedAt;
  final int createdAt;
  final Difficulty level;
  final WordSet wordSet;

  /// Coins every player puts in (0 = just for fun).
  final int stake;

  /// Total coins at stake once the round started (stake x players).
  final int pot;

  /// Ids of the players who took part (fixed when the round starts).
  final List<String> roster;
  final RoomResult? result;
  final Map<String, BattlePlayer> players;

  bool get isChallenge => kind == RoomKind.challenge;

  /// Epoch ms at which a challenge closes.
  int get deadline => startedAt + durationSec * 1000;

  BattleRoom copyWith({
    RoomStatus? status,
    int? startedAt,
    int? durationSec,
    int? pot,
    List<String>? roster,
    RoomResult? result,
    Map<String, BattlePlayer>? players,
  }) =>
      BattleRoom(
        code: code,
        hostId: hostId,
        kind: kind,
        status: status ?? this.status,
        durationSec: durationSec ?? this.durationSec,
        startedAt: startedAt ?? this.startedAt,
        createdAt: createdAt,
        level: level,
        wordSet: wordSet,
        stake: stake,
        pot: pot ?? this.pot,
        roster: roster ?? this.roster,
        result: result ?? this.result,
        players: players ?? this.players,
      );

  /// Room fields without the players (players are written separately so
  /// concurrent updates never overwrite each other).
  Map<String, dynamic> toJson() => {
        'host': hostId,
        'kind': kind.name,
        'status': status.name,
        'duration': durationSec,
        'startedAt': startedAt,
        'createdAt': createdAt,
        'level': level.code,
        'set': wordSet.code,
        'stake': stake,
        'pot': pot,
        if (roster.isNotEmpty) 'roster': {for (final id in roster) id: true},
      };

  factory BattleRoom.fromJson(String code, Map<dynamic, dynamic> json) {
    final raw = json['players'];
    final players = <String, BattlePlayer>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          players['$key'] = BattlePlayer.fromJson('$key', value);
        }
      });
    }
    final rosterRaw = json['roster'];
    return BattleRoom(
      code: code,
      hostId: (json['host'] as String?) ?? '',
      kind: RoomKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => RoomKind.live,
      ),
      status: RoomStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RoomStatus.lobby,
      ),
      durationSec: (json['duration'] as num?)?.toInt() ?? 180,
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      level: Difficulty.fromCode('${json['level'] ?? 'm'}'),
      wordSet: WordSet.fromCode('${json['set'] ?? 'r'}'),
      stake: (json['stake'] as num?)?.toInt() ?? 0,
      pot: (json['pot'] as num?)?.toInt() ?? 0,
      roster: [if (rosterRaw is Map) ...rosterRaw.keys.map((e) => '$e')],
      result: RoomResult.fromJson(json['result']),
      players: players,
    );
  }
}
