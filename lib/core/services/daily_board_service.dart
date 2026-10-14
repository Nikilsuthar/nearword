import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/puzzle.dart';
import '../constants/backend_config.dart';
import 'firebase_auth_service.dart';
import 'rtdb_client.dart';
import 'settings_service.dart';
import 'storage_service.dart';

/// One row of the daily leaderboard.
class DailyEntry {
  const DailyEntry({
    required this.uid,
    required this.name,
    required this.guesses,
    required this.seconds,
    required this.solved,
    required this.best,
    required this.score,
  });

  final String uid;
  final String name;
  final int guesses;
  final int seconds;
  final bool solved;

  /// Closest rank reached (1 when solved).
  final int best;

  /// Lower is better.
  final int score;

  factory DailyEntry.fromJson(String uid, Map<dynamic, dynamic> j) =>
      DailyEntry(
        uid: uid,
        name: (j['name'] as String?) ?? 'Player',
        guesses: (j['guesses'] as num?)?.toInt() ?? 0,
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
        solved: j['solved'] as bool? ?? false,
        best: (j['best'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 1 << 40,
      );
}

/// Daily tournament: everyone who plays today's word (for their word style and
/// level) is ranked by guesses, then time. Solvers come first; players who
/// gave up are ranked by how close they got.
class DailyBoardService extends GetxService {
  DailyBoardService(
    this._storage,
    this._settings, {
    FirebaseAuthService? auth,
    RtdbClient Function()? clientFactory,
  })  : _auth = auth,
        _clientFactory = clientFactory;

  final StorageService _storage;
  final SettingsService _settings;
  final FirebaseAuthService? _auth;
  final RtdbClient Function()? _clientFactory;

  static const _pendingKey = 'daily_pending';

  bool get enabled => BackendConfig.online;

  String get myId => _auth?.uid.value ?? _settings.playerId;

  RtdbClient _client() =>
      _clientFactory?.call() ??
      RtdbClient(BackendConfig.databaseUrl, tokenProvider: _auth?.idToken);

  static String path(String day, WordSet set, Difficulty level) =>
      'daily/$day/${set.code}${level.code}';

  /// Lower is better. Solvers: guesses then seconds. Others: closest rank.
  static int scoreFor({
    required bool solved,
    required int guesses,
    required int seconds,
    required int best,
  }) {
    if (solved) return guesses * 10000 + seconds.clamp(0, 9999);
    return 10000000 + best.clamp(1, 99999) * 100 + guesses.clamp(0, 99);
  }

  /// Posts the player's result. Queued for later if the network fails.
  Future<bool> submit({
    required String day,
    required WordSet set,
    required Difficulty level,
    required bool solved,
    required int guesses,
    required int seconds,
    required int best,
  }) async {
    if (!enabled) return false;
    final name = _settings.nickname.value.isEmpty
        ? 'Player'
        : _settings.nickname.value;
    final row = {
      'name': name.length > 20 ? name.substring(0, 20) : name,
      'guesses': guesses,
      'seconds': seconds,
      'solved': solved,
      'best': best,
      'score': scoreFor(
        solved: solved,
        guesses: guesses,
        seconds: seconds,
        best: best,
      ),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final p = '${path(day, set, level)}/$myId';
    try {
      await _client().put(p, row);
      return true;
    } catch (e) {
      debugPrint('Daily submit failed, queued: $e');
      _enqueue(p, row);
      return false;
    }
  }

  void _enqueue(String p, Map<String, Object> row) {
    final list = _pending()..removeWhere((e) => e['path'] == p);
    list.add({'path': p, 'row': row});
    _storage.setSetting(_pendingKey, [for (final e in list) jsonEncode(e)]);
  }

  List<Map<String, dynamic>> _pending() => [
        for (final s in (_storage.getSetting<List<dynamic>>(_pendingKey) ?? []))
          jsonDecode(s as String) as Map<String, dynamic>,
      ];

  /// Retries results that could not be sent earlier.
  Future<void> flushPending() async {
    if (!enabled) return;
    final list = _pending();
    if (list.isEmpty) return;
    final left = <Map<String, dynamic>>[];
    for (final e in list) {
      try {
        await _client().put(e['path'] as String, e['row']);
      } catch (_) {
        left.add(e);
      }
    }
    _storage.setSetting(_pendingKey, [for (final e in left) jsonEncode(e)]);
  }

  /// Best [limit] results for a day, best first.
  Future<List<DailyEntry>> top(
    String day,
    WordSet set,
    Difficulty level, {
    int limit = 100,
  }) async {
    final data = await _client().get(
      path(day, set, level),
      query: {'orderBy': '"score"', 'limitToFirst': '$limit'},
    );
    final out = <DailyEntry>[];
    if (data is Map) {
      data.forEach((k, v) {
        if (v is Map) out.add(DailyEntry.fromJson('$k', v));
      });
    }
    out.sort((a, b) {
      final c = a.score.compareTo(b.score);
      return c != 0 ? c : a.uid.compareTo(b.uid);
    });
    return out;
  }
}
