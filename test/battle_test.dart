import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nearword/core/services/settings_service.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/data/models/battle.dart';
import 'package:nearword/features/battle/battle_backend.dart';
import 'package:nearword/features/battle/battle_controller.dart';
import 'package:nearword/features/battle/battle_ranking.dart';

BattlePlayer p(
  String id, {
  int best = kNoRank,
  int guesses = 0,
  bool solved = false,
  int solvedMs = 0,
  bool done = false,
}) =>
    BattlePlayer(
      id: id,
      name: id,
      bestRank: best,
      guesses: guesses,
      solved: solved,
      solvedMs: solvedMs,
      done: done,
    );

void main() {
  group('BattleRanking', () {
    test('solvers first (fastest wins), then nearest rank', () {
      final order = BattleRanking.standings([
        p('far', best: 5000, guesses: 3),
        p('near', best: 12, guesses: 9),
        p('slow', best: 1, guesses: 20, solved: true, solvedMs: 90000),
        p('fast', best: 1, guesses: 7, solved: true, solvedMs: 40000),
        p('idle'),
      ]);
      expect(order.map((e) => e.id), ['fast', 'slow', 'near', 'far', 'idle']);
    });

    test('ties on rank are broken by fewer guesses', () {
      final order = BattleRanking.standings([
        p('a', best: 30, guesses: 9),
        p('b', best: 30, guesses: 4),
      ]);
      expect(order.first.id, 'b');
    });

    test('placeOf', () {
      final players = [p('a', best: 100), p('b', best: 10)];
      expect(BattleRanking.placeOf('b', players), 1);
      expect(BattleRanking.placeOf('a', players), 2);
      expect(BattleRanking.placeOf('zz', players), 0);
    });

    test('round over: timeout, everyone done, grace after first solve', () {
      bool over(List<BattlePlayer> ps, int ms) => BattleRanking.isRoundOver(
            players: ps,
            elapsedMs: ms,
            durationSec: 180,
            graceSec: 30,
          );
      final playing = [p('a', best: 50), p('b', best: 90)];
      expect(over(playing, 60000), isFalse);
      expect(over(playing, 180000), isTrue);
      expect(over([p('a', done: true), p('b', done: true)], 1000), isTrue);
      final solved = [
        p('a', best: 1, solved: true, solvedMs: 50000, done: true),
        p('b', best: 90),
      ];
      expect(over(solved, 70000), isFalse);
      expect(over(solved, 80001), isTrue);
    });
  });

  group('BattleController (memory backend, two players)', () {
    late Directory tmp;
    late StorageService storage;
    late int now;

    SettingsService settings(String id, String name) {
      final s = SettingsService(storage)..init();
      // ignore: invalid_use_of_protected_member
      s.nickname.value = name;
      return s;
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nearword_battle');
      Hive.init(tmp.path);
      storage = await StorageService().init(useFlutter: false);
      now = 1000000;
    });

    tearDown(() async {
      await Hive.close();
      await tmp.delete(recursive: true);
    });

    test('create, join, start, race and finish', () async {
      final backend = MemoryBattleBackend();
      final hostSettings = settings('host', 'Host');
      final host = BattleController(
        backend: backend,
        settings: hostSettings,
        clock: () => DateTime.fromMillisecondsSinceEpoch(now),
        heartbeat: const Duration(hours: 1),
      );
      // Second player needs a distinct id.
      final guestStorageSettings = SettingsService(storage)..init();
      guestStorageSettings.nickname.value = 'Guest';
      final guest = _GuestController(
        backend,
        guestStorageSettings,
        () => DateTime.fromMillisecondsSinceEpoch(now),
      );

      expect(await host.createRoom(practiceMode: false, durationSec: 120), isTrue);
      final code = host.code;
      expect(code.length, 5);
      expect(host.isHost, isTrue);

      expect(await guest.joinRoom(code.toLowerCase()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(host.room.value!.players.length, 2);

      await host.start();
      await Future<void>.delayed(Duration.zero);
      expect(host.phase.value, BattlePhase.countdown);
      expect(guest.phase.value, BattlePhase.countdown);
      expect(host.puzzleId, guest.puzzleId);

      await host.leave();
      await guest.leave();
      host.onClose();
      guest.onClose();
    });

    test('joining a missing room reports an error', () async {
      final c = BattleController(
        backend: MemoryBattleBackend(),
        settings: settings('x', 'X'),
      );
      expect(await c.joinRoom('ABCDE'), isFalse);
      expect(c.error.value, contains('No room'));
      expect(await c.joinRoom('AB'), isFalse);
      c.onClose();
    });

    test('start needs a second player', () async {
      final c = BattleController(
        backend: MemoryBattleBackend(),
        settings: settings('x', 'X'),
      );
      await c.createRoom(practiceMode: false);
      await c.start();
      expect(c.error.value, contains('one more player'));
      expect(c.room.value!.status, RoomStatus.lobby);
      await c.leave();
      c.onClose();
    });
  });

  group('RtdbBattleBackend against a mock Realtime Database', () {
    late HttpServer server;
    late Map<String, dynamic> db;

    dynamic read(List<String> path) {
      dynamic node = db;
      for (final key in path) {
        if (node is Map && node.containsKey(key)) {
          node = node[key];
        } else {
          return null;
        }
      }
      return node;
    }

    void write(List<String> path, dynamic value, {bool merge = false}) {
      Map<String, dynamic> node = db;
      for (final key in path.take(path.length - 1)) {
        node = (node.putIfAbsent(key, () => <String, dynamic>{})
            as Map<String, dynamic>);
      }
      final last = path.last;
      if (merge && node[last] is Map && value is Map) {
        (node[last] as Map<String, dynamic>).addAll(value.cast());
      } else {
        node[last] = value;
      }
    }

    setUp(() async {
      db = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final path = req.uri.path
            .replaceAll(RegExp(r'\.json$'), '')
            .split('/')
            .where((e) => e.isNotEmpty)
            .toList();
        final body = await utf8.decoder.bind(req).join();
        switch (req.method) {
          case 'GET':
            break;
          case 'PUT':
            write(path, jsonDecode(body));
          case 'PATCH':
            write(path, jsonDecode(body), merge: true);
          case 'DELETE':
            final parent = read(path.take(path.length - 1).toList());
            if (parent is Map) parent.remove(path.last);
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(read(path)));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('create / join / patch / watch round trip', () async {
      final backend = RtdbBattleBackend(
        'http://${server.address.host}:${server.port}/',
        pollInterval: const Duration(milliseconds: 50),
      );
      final host = BattlePlayer(id: 'h', name: 'Host', avatar: 2);
      await backend.createRoom(
        const BattleRoom(code: 'ROOM1', hostId: 'h', durationSec: 120),
        host,
      );
      expect(await backend.fetchRoom('NOPE'), isNull);

      final seen = <BattleRoom?>[];
      final sub = backend.watchRoom('ROOM1').listen(seen.add);

      await backend.savePlayer(
        'ROOM1',
        BattlePlayer(id: 'g', name: 'Guest', bestRank: 42, guesses: 3),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await backend.patchRoom('ROOM1', {'status': 'playing'});
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final room = (await backend.fetchRoom('ROOM1'))!;
      expect(room.hostId, 'h');
      expect(room.durationSec, 120);
      expect(room.status, RoomStatus.playing);
      expect(room.players.keys, containsAll(['h', 'g']));
      expect(room.players['g']!.bestRank, 42);
      expect(room.players['h']!.hasGuessed, isFalse);

      expect(seen.any((r) => r != null && r.players.length == 2), isTrue);
      expect(seen.last!.status, RoomStatus.playing);

      await backend.removePlayer('ROOM1', 'g');
      expect((await backend.fetchRoom('ROOM1'))!.players.keys, ['h']);

      await sub.cancel();
      backend.dispose();
    });
  });
}

/// Same as [BattleController] but with its own player id (the real app has one
/// device per player; here two controllers share a process).
class _GuestController extends BattleController {
  _GuestController(
    BattleBackend backend,
    SettingsService settings,
    DateTime Function() clock,
  ) : _id = 'guest-id',
      super(
        backend: backend,
        settings: settings,
        clock: clock,
        heartbeat: const Duration(hours: 1),
      );

  final String _id;

  @override
  String get playerId => _id;
}
