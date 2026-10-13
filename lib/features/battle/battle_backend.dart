import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/models/battle.dart';

/// Storage + sync for battle rooms. Two implementations:
///  * [RtdbBattleBackend] - Firebase Realtime Database over REST (online).
///  * [MemoryBattleBackend] - in-process (practice mode vs bots, and tests).
abstract class BattleBackend {
  bool get isOnline;

  Future<BattleRoom?> fetchRoom(String code);

  /// Creates the room and registers the host as its first player.
  Future<void> createRoom(BattleRoom room, BattlePlayer host);

  Future<void> savePlayer(String code, BattlePlayer player);
  Future<void> removePlayer(String code, String playerId);
  Future<void> patchRoom(String code, Map<String, dynamic> fields);

  /// Emits the room whenever it changes (null if it disappears).
  Stream<BattleRoom?> watchRoom(String code);

  void dispose() {}
}

// -----------------------------------------------------------------------------

class MemoryBattleBackend implements BattleBackend {
  final Map<String, Map<String, dynamic>> _rooms = {};
  final Map<String, StreamController<BattleRoom?>> _streams = {};

  @override
  bool get isOnline => false;

  BattleRoom? _read(String code) {
    final raw = _rooms[code];
    return raw == null ? null : BattleRoom.fromJson(code, raw);
  }

  void _emit(String code) => _streams[code]?.add(_read(code));

  @override
  Future<BattleRoom?> fetchRoom(String code) async => _read(code);

  @override
  Future<void> createRoom(BattleRoom room, BattlePlayer host) async {
    _rooms[room.code] = {
      ...room.toJson(),
      'players': {host.id: host.toJson()},
    };
    _emit(room.code);
  }

  @override
  Future<void> savePlayer(String code, BattlePlayer player) async {
    final room = _rooms[code];
    if (room == null) return;
    (room['players'] as Map<String, dynamic>)[player.id] = player.toJson();
    _emit(code);
  }

  @override
  Future<void> removePlayer(String code, String playerId) async {
    final room = _rooms[code];
    if (room == null) return;
    (room['players'] as Map<String, dynamic>).remove(playerId);
    _emit(code);
  }

  @override
  Future<void> patchRoom(String code, Map<String, dynamic> fields) async {
    _rooms[code]?.addAll(fields);
    _emit(code);
  }

  @override
  Stream<BattleRoom?> watchRoom(String code) {
    final source = _streams.putIfAbsent(
      code,
      () => StreamController<BattleRoom?>.broadcast(),
    );
    StreamSubscription<BattleRoom?>? inner;
    late StreamController<BattleRoom?> out;
    out = StreamController<BattleRoom?>(
      onListen: () {
        // Replay the current value, then forward every change.
        out.add(_read(code));
        inner = source.stream.listen(out.add);
      },
      onCancel: () async {
        await inner?.cancel();
        inner = null;
      },
    );
    return out.stream;
  }

  @override
  void dispose() {
    for (final c in _streams.values) {
      c.close();
    }
    _streams.clear();
  }
}

// -----------------------------------------------------------------------------

/// Firebase Realtime Database through its REST API: no SDK or
/// google-services.json needed, just the database URL.
class RtdbBattleBackend implements BattleBackend {
  RtdbBattleBackend(
    String databaseUrl, {
    http.Client? client,
    this.pollInterval = const Duration(milliseconds: 1200),
  })  : _base = databaseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _base;
  final http.Client _client;
  final Duration pollInterval;
  static const _timeout = Duration(seconds: 8);

  @override
  bool get isOnline => true;

  Uri _uri(String path) => Uri.parse('$_base/rooms/$path.json');

  Future<dynamic> _get(String path) async {
    final res = await _client.get(_uri(path)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('GET $path -> ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  Future<void> _send(String method, String path, Object body) async {
    final req = http.Request(method, _uri(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    final res = await http.Response.fromStream(
      await _client.send(req).timeout(_timeout),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('$method $path -> ${res.statusCode}');
    }
  }

  @override
  Future<BattleRoom?> fetchRoom(String code) async {
    final data = await _get(code);
    return data is Map ? BattleRoom.fromJson(code, data) : null;
  }

  @override
  Future<void> createRoom(BattleRoom room, BattlePlayer host) => _send(
        'PUT',
        room.code,
        {
          ...room.toJson(),
          'players': {host.id: host.toJson()},
        },
      );

  @override
  Future<void> savePlayer(String code, BattlePlayer player) =>
      _send('PUT', '$code/players/${player.id}', player.toJson());

  @override
  Future<void> removePlayer(String code, String playerId) async {
    final res = await _client
        .delete(_uri('$code/players/$playerId'))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('DELETE -> ${res.statusCode}');
    }
  }

  @override
  Future<void> patchRoom(String code, Map<String, dynamic> fields) =>
      _send('PATCH', code, fields);

  @override
  Stream<BattleRoom?> watchRoom(String code) {
    Timer? timer;
    String? last;
    late StreamController<BattleRoom?> controller;

    Future<void> poll() async {
      try {
        final raw = await _get(code);
        final encoded = jsonEncode(raw);
        if (encoded != last && !controller.isClosed) {
          last = encoded;
          controller.add(raw is Map ? BattleRoom.fromJson(code, raw) : null);
        }
      } catch (e, st) {
        debugPrint('Battle poll failed: $e');
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<BattleRoom?>(
      onListen: () {
        poll();
        timer = Timer.periodic(pollInterval, (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        return controller.close();
      },
    );
    return controller.stream;
  }

  @override
  void dispose() => _client.close();
}
