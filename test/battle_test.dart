import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:nearword/core/constants/backend_config.dart';
import 'package:nearword/core/services/daily_board_service.dart';
import 'package:nearword/core/services/firebase_auth_service.dart';
import 'package:nearword/core/services/rtdb_client.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/core/services/settings_service.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/data/models/battle.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/data/repositories/puzzle_repository.dart';
import 'package:nearword/data/repositories/stats_repository.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  group('BattleRanking', () {
    test('live: solvers first (fastest wins), then nearest rank', () {
      final order = BattleRanking.standings([
        p('far', best: 5000, guesses: 3),
        p('near', best: 12, guesses: 9),
        p('slow', best: 1, guesses: 20, solved: true, solvedMs: 90000),
        p('fast', best: 1, guesses: 7, solved: true, solvedMs: 40000),
        p('idle'),
      ]);
      expect(order.map((e) => e.id), ['fast', 'slow', 'near', 'far', 'idle']);
    });

    test('challenge: fewest guesses wins, time breaks ties', () {
      final order = BattleRanking.standings([
        p('a', best: 1, guesses: 12, solved: true, solvedMs: 20000),
        p('b', best: 1, guesses: 5, solved: true, solvedMs: 90000),
        p('c', best: 1, guesses: 5, solved: true, solvedMs: 30000),
      ], fewestGuessesFirst: true);
      expect(order.map((e) => e.id), ['c', 'b', 'a']);
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

  // ---------------------------------------------------------------------------
  group('RoomEconomy (coins)', () {
    test('a solver takes the whole pot', () {
      final r = RoomEconomy.settle(
        roster: [
          p('a', best: 20, guesses: 5),
          p('b', best: 1, guesses: 9, solved: true, solvedMs: 50000),
          p('c', best: 500, guesses: 2),
        ],
        stake: 10,
        challenge: false,
      );
      expect(r.kind, 'solved');
      expect(r.winnerId, 'b');
      expect(r.payouts, {'b': 30});
    });

    test('nobody solves: nearest gets 50% of the pot, others 50% of stake', () {
      final r = RoomEconomy.settle(
        roster: [
          p('a', best: 20, guesses: 5),
          p('b', best: 400, guesses: 9),
          p('c', best: 3000, guesses: 2),
        ],
        stake: 10,
        challenge: false,
      );
      expect(r.kind, 'nearest');
      expect(r.winnerId, 'a');
      // pot = 30 -> nearest 15; the other two get back 5 each.
      expect(r.payouts, {'a': 15, 'b': 5, 'c': 5});
    });

    test('two players: nearest breaks even, the other loses half', () {
      final r = RoomEconomy.settle(
        roster: [p('a', best: 10, guesses: 4), p('b', best: 900, guesses: 6)],
        stake: 20,
        challenge: false,
      );
      expect(r.payouts, {'a': 20, 'b': 10});
    });

    test('nobody guessed anything: everyone gets 50% back', () {
      final r = RoomEconomy.settle(
        roster: [p('a'), p('b')],
        stake: 10,
        challenge: false,
      );
      expect(r.kind, 'none');
      expect(r.payouts, {'a': 5, 'b': 5});
    });

    test('free rooms pay nothing; odd stakes round down', () {
      expect(
        RoomEconomy.settle(
          roster: [p('a', best: 1, solved: true), p('b')],
          stake: 0,
          challenge: false,
        ).payouts,
        isEmpty,
      );
      final odd = RoomEconomy.settle(
        roster: [p('a', best: 10, guesses: 1), p('b', best: 20, guesses: 1)],
        stake: 25,
        challenge: false,
      );
      expect(odd.payouts, {'a': 25, 'b': 12});
    });

    test('challenge winner is the one with the fewest guesses', () {
      final r = RoomEconomy.settle(
        roster: [
          p('a', best: 1, guesses: 12, solved: true, solvedMs: 10000),
          p('b', best: 1, guesses: 4, solved: true, solvedMs: 99000),
        ],
        stake: 50,
        challenge: true,
      );
      expect(r.winnerId, 'b');
      expect(r.payouts, {'b': 100});
    });

    test('result survives a JSON round trip', () {
      const r = RoomResult(
        kind: 'nearest',
        winnerId: 'a',
        payouts: {'a': 15, 'b': 5},
      );
      final back = RoomResult.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back!.kind, 'nearest');
      expect(back.winnerId, 'a');
      expect(back.payouts, {'a': 15, 'b': 5});
    });

    test('room model round trip keeps level, style, stake, roster', () {
      final room = BattleRoom(
        code: 'ABCDE',
        hostId: 'h',
        kind: RoomKind.challenge,
        status: RoomStatus.playing,
        durationSec: 3600,
        startedAt: 1000,
        createdAt: 900,
        level: Difficulty.hard,
        wordSet: WordSet.india,
        stake: 50,
        pot: 100,
        roster: const ['h', 'g'],
      );
      final back = BattleRoom.fromJson('ABCDE', jsonDecode(jsonEncode(room.toJson())));
      expect(back.kind, RoomKind.challenge);
      expect(back.level, Difficulty.hard);
      expect(back.wordSet, WordSet.india);
      expect(back.stake, 50);
      expect(back.pot, 100);
      expect(back.roster.toSet(), {'h', 'g'});
      expect(back.deadline, 1000 + 3600 * 1000);
    });
  });

  // ---------------------------------------------------------------------------
  group('BattleController with coins (two phones, in-memory backend)', () {
    late Directory tmp;
    late SemanticEngine engine;
    late PuzzleRepository repo;
    late MemoryBattleBackend backend;
    late _Phone host;
    late _Phone guest;

    setUpAll(() async {
      engine = await SemanticEngine().init();
    });

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nearword_battle');
      Hive.init(tmp.path);
      repo = PuzzleRepository(engine);
      backend = MemoryBattleBackend();
      host = await _Phone.create('h_', 'host', 'Host', repo, backend, 100);
      guest = await _Phone.create('g_', 'guest', 'Guest', repo, backend, 100);
    });

    tearDown(() async {
      host.dispose();
      guest.dispose();
      await Hive.close();
      await tmp.delete(recursive: true);
    });

    test('creating a staked room locks the coins; leaving the lobby refunds',
        () async {
      expect(
        await host.battle.createRoom(
          practiceMode: false,
          stake: 30,
          level: Difficulty.easy,
          wordSet: WordSet.india,
        ),
        isTrue,
      );
      expect(host.stats.stats.coins, 70);
      expect(host.battle.room.value!.stake, 30);
      expect(host.battle.room.value!.level, Difficulty.easy);
      expect(host.battle.room.value!.wordSet, WordSet.india);
      expect(host.storage.escrows().keys, [host.battle.code]);

      await host.battle.leave();
      expect(host.stats.stats.coins, 100);
      expect(host.storage.escrows(), isEmpty);
      expect(await backend.fetchRoom(host.battle.code), isNull);
    });

    test('a player without enough coins cannot join or create', () async {
      await host.battle.createRoom(practiceMode: false, stake: 50);
      final code = host.battle.code;
      guest.stats.stats.coins = 20;
      expect(await guest.battle.joinRoom(code), isFalse);
      expect(guest.battle.error.value, 'err_no_coins');
      expect(guest.stats.stats.coins, 20);
      expect(guest.storage.escrows(), isEmpty);
      expect(await guest.battle.createRoom(practiceMode: false, stake: 50), isFalse);
      expect(guest.battle.error.value, 'err_no_coins');
    });

    test('practice rooms never use coins', () async {
      await host.battle.createRoom(practiceMode: true, stake: 100);
      expect(host.stats.stats.coins, 100);
      expect(host.battle.room.value!.stake, 0);
      await host.battle.leave();
    });

    test('live round: solver wins the pot, payouts applied once', () async {
      await host.battle.createRoom(
        practiceMode: false,
        stake: 20,
        durationSec: 120,
      );
      final code = host.battle.code;
      expect(await guest.battle.joinRoom(code.toLowerCase()), isTrue);
      expect(guest.stats.stats.coins, 80);
      await _settle();
      expect(host.battle.room.value!.players.length, 2);

      await host.battle.start();
      await _until(() => host.battle.phase.value == BattlePhase.playing &&
          guest.battle.phase.value == BattlePhase.playing);
      final room = host.battle.room.value!;
      expect(room.pot, 40);
      expect(room.roster.toSet(), {'host', 'guest'});
      expect(host.battle.puzzleId, guest.battle.puzzleId);

      host.battle.report(bestRank: 40, guesses: 6, solved: false, done: true);
      guest.battle.report(bestRank: 1, guesses: 9, solved: true, done: true);

      // Everyone is done -> the host closes the room and both settle.
      await _until(() =>
          host.battle.myPayout.value != null &&
          guest.battle.myPayout.value != null);
      expect(guest.stats.stats.coins, 80 + 40); // won the whole pot
      expect(host.stats.stats.coins, 80); // lost the stake
      expect(host.battle.myPayout.value, 0);
      expect(guest.battle.myPlace, 1);
      expect(guest.storage.escrows(), isEmpty);

      // Receiving the same result again must not pay twice.
      final finished = (await backend.fetchRoom(code))!;
      expect(finished.status, RoomStatus.finished);
      guest.battle.room.value = finished;
      await backend.patchRoom(code, {'status': 'finished'});
      await _settle();
      expect(guest.stats.stats.coins, 120);
    });

    test('live round: nobody solves -> nearest gets half the pot', () async {
      await host.battle.createRoom(practiceMode: false, stake: 20, durationSec: 120);
      await guest.battle.joinRoom(host.battle.code);
      await _settle();
      await host.battle.start();
      await _until(() => guest.battle.phase.value == BattlePhase.playing);

      host.battle.report(bestRank: 800, guesses: 6, solved: false, done: true);
      guest.battle.report(bestRank: 15, guesses: 9, solved: false, done: true);
      await _until(() =>
          host.battle.myPayout.value != null &&
          guest.battle.myPayout.value != null);
      // pot 40: nearest (guest) 20, other gets half of their stake back: 10.
      expect(guest.stats.stats.coins, 80 + 20);
      expect(host.stats.stats.coins, 80 + 10);
    });

    test('challenge: friends play later, fewest guesses wins, host can close',
        () async {
      expect(
        await host.battle.createChallenge(
          windowSec: 3600,
          stake: 10,
          level: Difficulty.medium,
          wordSet: WordSet.regular,
        ),
        isTrue,
      );
      final code = host.battle.code;
      expect(host.battle.isChallenge, isTrue);
      expect(host.battle.puzzleId, startsWith('chal-rm-'));
      await guest.battle.joinRoom(code);
      expect(guest.stats.stats.coins, 90);
      expect(guest.battle.isChallenge, isTrue);

      host.battle.beginPlaying();
      guest.battle.beginPlaying();
      host.battle.report(bestRank: 1, guesses: 12, solved: true, done: true);
      guest.battle.report(bestRank: 1, guesses: 5, solved: true, done: true);
      await _settle();

      await host.battle.endChallengeNow();
      await _until(() =>
          host.battle.myPayout.value != null &&
          guest.battle.myPayout.value != null);
      expect(guest.stats.stats.coins, 90 + 20);
      expect(host.stats.stats.coins, 90);
      expect(host.battle.room.value!.result!.winnerId, 'guest');
    });

    test('reconcile returns the stake of a room that vanished', () async {
      await host.battle.createRoom(practiceMode: false, stake: 40);
      final code = host.battle.code;
      expect(host.stats.stats.coins, 60);
      await backend.deleteRoom(code);
      BackendConfig.urlOverride = 'https://example.invalid'; // "online" gate
      addTearDown(() => BackendConfig.urlOverride = '');
      await host.battle.reconcile();
      expect(host.stats.stats.coins, 100);
      expect(host.storage.escrows(), isEmpty);
    });

    test('a full or unknown room is reported, nothing is charged', () async {
      expect(await guest.battle.joinRoom('ZZZZZ'), isFalse);
      expect(guest.battle.error.value, 'err_no_room');
      expect(await guest.battle.joinRoom('AB'), isFalse);
      expect(guest.battle.error.value, 'err_code_short');
      expect(guest.stats.stats.coins, 100);
    });

    test('start needs a second player', () async {
      await host.battle.createRoom(practiceMode: false);
      await host.battle.start();
      expect(host.battle.error.value, 'err_need_player');
      expect(host.battle.room.value!.status, RoomStatus.lobby);
    });
  });

  // ---------------------------------------------------------------------------
  group('online pieces against a mock Realtime Database', () {
    late HttpServer server;
    late Map<String, dynamic> db;
    late List<Uri> requests;
    var authRequired = false;

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

    String url() => 'http://${server.address.host}:${server.port}';

    setUp(() async {
      HttpOverrides.global = null; // the test binding blocks real sockets
      db = {};
      requests = [];
      authRequired = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        requests.add(req.uri);
        final path = req.uri.path
            .replaceAll(RegExp(r'\.json$'), '')
            .split('/')
            .where((e) => e.isNotEmpty)
            .toList();
        final body = await utf8.decoder.bind(req).join();
        if (authRequired && req.uri.queryParameters['auth'] != 'TOKEN123') {
          req.response.statusCode = 401;
          await req.response.close();
          return;
        }
        dynamic result;
        switch (req.method) {
          case 'GET':
            result = read(path);
            final q = req.uri.queryParameters;
            if (result is Map && q['orderBy'] == '"score"') {
              final entries = result.entries.toList()
                ..sort((a, b) => ((a.value as Map)['score'] as num)
                    .compareTo((b.value as Map)['score'] as num));
              final limit = int.tryParse(q['limitToFirst'] ?? '') ?? entries.length;
              result = {for (final e in entries.take(limit)) e.key: e.value};
            }
          case 'PUT':
            write(path, jsonDecode(body));
            result = read(path);
          case 'PATCH':
            write(path, jsonDecode(body), merge: true);
            result = read(path);
          case 'DELETE':
            final parent = read(path.take(path.length - 1).toList());
            if (parent is Map) parent.remove(path.last);
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(result));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('RtdbBattleBackend: create / join / patch / watch / delete', () async {
      final backend = RtdbBattleBackend(
        RtdbClient('${url()}/'),
        pollInterval: const Duration(milliseconds: 50),
      );
      const host = BattlePlayer(id: 'h', name: 'Host', avatar: 2, stake: 10);
      await backend.createRoom(
        const BattleRoom(
          code: 'ROOM1',
          hostId: 'h',
          durationSec: 120,
          level: Difficulty.hard,
          wordSet: WordSet.india,
          stake: 10,
        ),
        host,
      );
      expect(await backend.fetchRoom('NOPE'), isNull);

      final seen = <BattleRoom?>[];
      final sub = backend.watchRoom('ROOM1').listen(seen.add);
      await backend.savePlayer(
        'ROOM1',
        const BattlePlayer(id: 'g', name: 'Guest', bestRank: 42, guesses: 3),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await backend.patchRoom('ROOM1', {'status': 'playing'});
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final room = (await backend.fetchRoom('ROOM1'))!;
      expect(room.level, Difficulty.hard);
      expect(room.wordSet, WordSet.india);
      expect(room.stake, 10);
      expect(room.status, RoomStatus.playing);
      expect(room.players.keys, containsAll(['h', 'g']));
      expect(room.players['g']!.bestRank, 42);
      expect(room.players['h']!.stake, 10);
      expect(seen.any((r) => r != null && r.players.length == 2), isTrue);

      await backend.removePlayer('ROOM1', 'g');
      expect((await backend.fetchRoom('ROOM1'))!.players.keys, ['h']);
      await backend.deleteRoom('ROOM1');
      expect(await backend.fetchRoom('ROOM1'), isNull);
      await sub.cancel();
      backend.dispose();
    });

    test('RtdbClient sends the auth token and surfaces 401', () async {
      authRequired = true;
      final withToken = RtdbClient(url(), tokenProvider: () async => 'TOKEN123');
      await withToken.put('rooms/AAAAA', {'host': 'x', 'status': 'lobby'});
      expect((await withToken.get('rooms/AAAAA'))['host'], 'x');
      final noToken = RtdbClient(url());
      expect(() => noToken.get('rooms/AAAAA'), throwsA(isA<http.ClientException>()));
      expect(requests.any((u) => u.queryParameters['auth'] == 'TOKEN123'), isTrue);
    });

    test('FirebaseAuthService: signs in anonymously, refreshes, survives errors',
        () async {
      final tmp = await Directory.systemTemp.createTemp('nearword_auth');
      Hive.init(tmp.path);
      final storage = await StorageService(namePrefix: 'a_').init(useFlutter: false);
      BackendConfig.keyOverride = 'KEY';

      var signUps = 0;
      var refreshes = 0;
      var failSignUp = false;
      final client = _FakeAuthClient((req) {
        if (req.url.path.contains('accounts:signUp')) {
          if (failSignUp) return http.Response('{"error":{"message":"CONFIGURATION_NOT_FOUND"}}', 400);
          signUps++;
          return http.Response(
            jsonEncode({
              'idToken': 'ID$signUps',
              'refreshToken': 'REFRESH',
              'expiresIn': '3600',
              'localId': 'UID42',
            }),
            200,
          );
        }
        refreshes++;
        return http.Response(
          jsonEncode({
            'id_token': 'IDR$refreshes',
            'refresh_token': 'REFRESH',
            'expires_in': '3600',
            'user_id': 'UID42',
          }),
          200,
        );
      });

      final auth = FirebaseAuthService(storage, client: client).init();
      expect(auth.signedIn, isFalse);
      expect(await auth.idToken(), 'ID1');
      expect(auth.uid.value, 'UID42');
      expect(await auth.idToken(), 'ID1', reason: 'cached while fresh');
      expect(signUps, 1);

      // A new app launch reuses the saved refresh token.
      final again = FirebaseAuthService(storage, client: client).init();
      expect(again.uid.value, 'UID42');
      expect(await again.idToken(), 'IDR1');
      expect(signUps, 1);

      // Authentication not enabled on the project: stays signed out, no crash.
      final tmp2 = await Directory.systemTemp.createTemp('nearword_auth2');
      Hive.init(tmp2.path);
      final storage2 =
          await StorageService(namePrefix: 'b_').init(useFlutter: false);
      failSignUp = true;
      final off = FirebaseAuthService(storage2, client: client).init();
      expect(await off.idToken(), isNull);
      expect(off.signedIn, isFalse);

      // No API key at all -> open mode.
      BackendConfig.keyOverride = '';
      expect(await auth.idToken(), isNull.or(isA<String>()));
      await Hive.close();
      await tmp.delete(recursive: true);
      await tmp2.delete(recursive: true);
    });

    test('DailyBoardService: ranks solvers first, queues offline results',
        () async {
      final tmp = await Directory.systemTemp.createTemp('nearword_daily');
      Hive.init(tmp.path);
      final storage = await StorageService(namePrefix: 'd_').init(useFlutter: false);
      final settings = SettingsService(storage).init();
      settings.nickname.value = 'Me';
      BackendConfig.urlOverride = url();
      addTearDown(() => BackendConfig.urlOverride = '');

      final board = DailyBoardService(
        storage,
        settings,
        clientFactory: () => RtdbClient(url()),
      );
      expect(board.enabled, isTrue);

      // Three players finish the same daily puzzle.
      Future<void> put(String uid, String name, bool solved, int g, int s, int best) {
        final row = {
          'name': name,
          'guesses': g,
          'seconds': s,
          'solved': solved,
          'best': best,
          'score': DailyBoardService.scoreFor(
            solved: solved,
            guesses: g,
            seconds: s,
            best: best,
          ),
        };
        return RtdbClient(url()).put('daily/2026-10-14/rm/$uid', row);
      }

      await put('u1', 'Slow', true, 14, 300, 1);
      await put('u2', 'Fast', true, 14, 120, 1);
      await put('u3', 'Gave up', false, 20, 400, 25);
      final ok = await board.submit(
        day: '2026-10-14',
        set: WordSet.regular,
        level: Difficulty.medium,
        solved: true,
        guesses: 6,
        seconds: 200,
        best: 1,
      );
      expect(ok, isTrue);

      final top = await board.top('2026-10-14', WordSet.regular, Difficulty.medium);
      expect(top.map((e) => e.name), ['Me', 'Fast', 'Slow', 'Gave up']);
      expect(top.first.uid, settings.playerId);
      expect(top.last.solved, isFalse);

      // Another word style / level is a separate board.
      expect(await board.top('2026-10-14', WordSet.india, Difficulty.easy), isEmpty);

      // Offline: the result is queued, then sent when the network is back.
      await server.close(force: true);
      final offline = await board.submit(
        day: '2026-10-15',
        set: WordSet.regular,
        level: Difficulty.medium,
        solved: false,
        guesses: 3,
        seconds: 50,
        best: 777,
      );
      expect(offline, isFalse);
      expect(storage.getSetting<List<dynamic>>('daily_pending'), hasLength(1));

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      db = {};
      server.listen((req) async {
        final path = req.uri.path
            .replaceAll(RegExp(r'\.json$'), '')
            .split('/')
            .where((e) => e.isNotEmpty)
            .toList();
        final body = await utf8.decoder.bind(req).join();
        if (req.method == 'PUT') write(path, jsonDecode(body));
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(read(path)));
        await req.response.close();
      });
      BackendConfig.urlOverride = url();
      final board2 = DailyBoardService(
        storage,
        settings,
        clientFactory: () => RtdbClient(url()),
      );
      await board2.flushPending();
      expect(storage.getSetting<List<dynamic>>('daily_pending'), isEmpty);
      expect(read(['daily', '2026-10-15', 'rm', settings.playerId, 'best']), 777);
      await Hive.close();
      await tmp.delete(recursive: true);
    });
  });

  test('daily score ordering', () {
    int s(bool solved, int g, int t, int best) => DailyBoardService.scoreFor(
          solved: solved,
          guesses: g,
          seconds: t,
          best: best,
        );
    expect(s(true, 5, 100, 1), lessThan(s(true, 6, 10, 1)));
    expect(s(true, 5, 90, 1), lessThan(s(true, 5, 100, 1)));
    expect(s(true, 99, 9999, 1), lessThan(s(false, 1, 1, 2)));
    expect(s(false, 9, 1, 10), lessThan(s(false, 2, 1, 500)));
  });
}

/// One simulated phone: its own storage, coins, settings and controller.
class _Phone {
  _Phone(this.storage, this.stats, this.battle);

  final StorageService storage;
  final StatsRepository stats;
  final BattleController battle;

  static Future<_Phone> create(
    String prefix,
    String id,
    String name,
    PuzzleRepository repo,
    BattleBackend backend,
    int coins,
  ) async {
    final storage = await StorageService(namePrefix: prefix).init(useFlutter: false);
    final settings = SettingsService(storage).init();
    settings.nickname.value = name;
    final stats = StatsRepository(storage).init()..stats.coins = coins;
    final battle = _PhoneController(
      id,
      backend: backend,
      settings: settings,
      storage: storage,
      stats: stats,
      repository: repo,
      heartbeat: const Duration(hours: 1),
      countdownSeconds: 1,
    );
    return _Phone(storage, stats, battle);
  }

  void dispose() => battle.onClose();
}

class _PhoneController extends BattleController {
  _PhoneController(
    this._id, {
    required super.backend,
    required super.settings,
    required super.storage,
    required super.stats,
    required super.repository,
    required super.heartbeat,
    required super.countdownSeconds,
  });

  final String _id;

  @override
  String get playerId => _id;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 80));

Future<void> _until(bool Function() cond, {int seconds = 10}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('condition not met in ${seconds}s');
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }
}

class _FakeAuthClient extends http.BaseClient {
  _FakeAuthClient(this._handler);

  final http.Response Function(http.Request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = _handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
