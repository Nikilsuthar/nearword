// Live test against a REAL Firebase Realtime Database. Skipped unless the
// NEARWORD_RTDB_URL environment variable is set, e.g.
//   NEARWORD_RTDB_URL=https://xxx-default-rtdb.firebaseio.com flutter test test/rtdb_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nearword/core/services/rtdb_client.dart';
import 'package:nearword/core/utils/seeded.dart';
import 'package:nearword/data/models/battle.dart';
import 'package:nearword/features/battle/battle_backend.dart';
import 'package:nearword/features/battle/battle_ranking.dart';

void main() {
  final url = Platform.environment['NEARWORD_RTDB_URL'];
  final skip = url == null ? 'set NEARWORD_RTDB_URL to run' : null;

  test('two players race through a real database', () async {
    final host = RtdbBattleBackend(
      RtdbClient(url!),
      pollInterval: const Duration(milliseconds: 300),
    );
    final guest = RtdbBattleBackend(
      RtdbClient(url),
      pollInterval: const Duration(milliseconds: 300),
    );
    final code = Seeded.randomCode(5);
    final seen = <BattleRoom?>[];

    try {
      await host.createRoom(
        BattleRoom(code: code, hostId: 'host1', durationSec: 120),
        const BattlePlayer(id: 'host1', name: 'Host', avatar: 1),
      );

      // Guest sees the room, joins, and watches it.
      final found = await guest.fetchRoom(code);
      expect(found, isNotNull);
      expect(found!.hostId, 'host1');
      expect(found.status, RoomStatus.lobby);
      await guest.savePlayer(
        code,
        const BattlePlayer(id: 'guest1', name: 'Guest', avatar: 2),
      );
      final sub = host.watchRoom(code).listen(seen.add);

      // Host starts; guest plays and reports progress.
      await host.patchRoom(code, {'status': 'playing', 'startedAt': 123});
      await guest.savePlayer(
        code,
        const BattlePlayer(
          id: 'guest1',
          name: 'Guest',
          avatar: 2,
          bestRank: 250,
          guesses: 4,
        ),
      );
      await host.savePlayer(
        code,
        const BattlePlayer(
          id: 'host1',
          name: 'Host',
          avatar: 1,
          bestRank: 1,
          guesses: 6,
          solved: true,
          solvedMs: 45000,
          done: true,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));

      final room = (await guest.fetchRoom(code))!;
      expect(room.status, RoomStatus.playing);
      expect(room.players.length, 2);
      final order = BattleRanking.standings(room.players.values);
      expect(order.map((p) => p.id), ['host1', 'guest1']);
      expect(order.first.solved, isTrue);

      // The host's live stream saw the guest's progress.
      expect(
        seen.any((r) => r?.players['guest1']?.bestRank == 250),
        isTrue,
      );

      await host.patchRoom(code, {'status': 'finished'});
      expect((await guest.fetchRoom(code))!.status, RoomStatus.finished);

      await guest.removePlayer(code, 'guest1');
      expect((await host.fetchRoom(code))!.players.keys, ['host1']);
      await sub.cancel();
    } finally {
      // Clean up the test room.
      await http.delete(Uri.parse('$url/rooms/$code.json'));
      host.dispose();
      guest.dispose();
    }
    expect(await RtdbBattleBackend(RtdbClient(url)).fetchRoom(code), isNull);
  }, skip: skip);

  test('rules block junk: bad room codes and root access', () async {
    final bad = await http.put(
      Uri.parse('$url/rooms/not-a-valid-code.json'),
      body: '{"host":"x"}',
    );
    expect(bad.statusCode, anyOf(400, 401, 403));
    final root = await http.get(Uri.parse('$url/.json'));
    expect(root.statusCode, anyOf(401, 403));
    final listAll = await http.get(Uri.parse('$url/rooms.json'));
    expect(listAll.statusCode, anyOf(401, 403));
  }, skip: skip);
}
