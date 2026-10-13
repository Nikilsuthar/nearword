enum RoomStatus { lobby, playing, finished }

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
  });

  final String id;
  final String name;

  /// Index into the avatar colour palette.
  final int avatar;

  /// Closest rank this player has reached so far (1 = solved).
  final int bestRank;
  final int guesses;
  final bool solved;

  /// Milliseconds after the start at which the player solved the word.
  final int solvedMs;

  /// Solved, gave up, or ran out of time.
  final bool done;
  final bool isBot;

  /// Last heartbeat (epoch ms, sender clock).
  final int seen;

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
    );
  }
}

class BattleRoom {
  const BattleRoom({
    required this.code,
    required this.hostId,
    this.status = RoomStatus.lobby,
    this.durationSec = 180,
    this.startedAt = 0,
    this.players = const {},
  });

  final String code;
  final String hostId;
  final RoomStatus status;
  final int durationSec;

  /// Epoch ms (host clock) at which the round starts; 0 while in the lobby.
  final int startedAt;
  final Map<String, BattlePlayer> players;

  BattleRoom copyWith({
    RoomStatus? status,
    int? startedAt,
    int? durationSec,
    Map<String, BattlePlayer>? players,
  }) =>
      BattleRoom(
        code: code,
        hostId: hostId,
        status: status ?? this.status,
        durationSec: durationSec ?? this.durationSec,
        startedAt: startedAt ?? this.startedAt,
        players: players ?? this.players,
      );

  /// Room fields without the players (players are written separately so
  /// concurrent updates never overwrite each other).
  Map<String, dynamic> toJson() => {
        'host': hostId,
        'status': status.name,
        'duration': durationSec,
        'startedAt': startedAt,
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
    return BattleRoom(
      code: code,
      hostId: (json['host'] as String?) ?? '',
      status: RoomStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RoomStatus.lobby,
      ),
      durationSec: (json['duration'] as num?)?.toInt() ?? 180,
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      players: players,
    );
  }
}
