import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/player_stats.dart';
import '../../data/models/saved_game.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around Hive. Values are stored as JSON-friendly maps, so no
/// code generation / type adapters are needed.
class StorageService extends GetxService {
  /// Prefix for the box names (tests use it to simulate several phones).
  StorageService({this.namePrefix = ''});

  final String namePrefix;

  late Box<dynamic> _settings;
  late Box<dynamic> _games;

  /// Bumped whenever progress changes (game saved, stats updated) so screens
  /// like Home / Categories can refresh with `ever(storage.revision, ...)`.
  final RxInt revision = 0.obs;

  void touch() => revision.value++;

  /// Call once at startup. Pass [useFlutter] = false in unit tests after
  /// calling `Hive.init(tempDir)` yourself.
  Future<StorageService> init({bool useFlutter = true}) async {
    if (useFlutter) await Hive.initFlutter();
    _settings = await Hive.openBox('$namePrefix${AppConstants.settingsBox}');
    _games = await Hive.openBox('$namePrefix${AppConstants.gamesBox}');
    return this;
  }

  // --- Settings -----------------------------------------------------------

  T? getSetting<T>(String key) =>
      _settings.isOpen ? _settings.get(key) as T? : null;
  Future<void> setSetting(String key, Object? value) async {
    if (_settings.isOpen) await _settings.put(key, value);
  }

  // --- Recently played secrets (so words do not repeat) ---------------------

  static const _recentKey = 'recent_secrets';
  static const _recentMax = 400;

  Set<String> recentSecrets() =>
      (getSetting<List<dynamic>>(_recentKey) ?? const []).cast<String>().toSet();

  void addRecentSecret(String word) {
    final list =
        (getSetting<List<dynamic>>(_recentKey) ?? const []).cast<String>().toList()
          ..remove(word)
          ..add(word);
    final trimmed =
        list.length > _recentMax ? list.sublist(list.length - _recentMax) : list;
    setSetting(_recentKey, trimmed);
  }

  // --- Room coin escrow ---------------------------------------------------------
  //
  // Coins put into a room's pot are removed from the balance right away and
  // recorded here until the room pays out (or refunds), so a crash or a closed
  // app can never lose or duplicate coins.

  static const _escrowKey = 'room_escrow';
  static const _paidKey = 'room_paid';

  /// code -> {stake, kind, ts}
  Map<String, Map<String, dynamic>> escrows() {
    final raw = getSetting<String>(_escrowKey);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {for (final e in m.entries) e.key: (e.value as Map).cast<String, dynamic>()};
  }

  void setEscrow(String code, Map<String, dynamic> info) {
    final m = escrows()..[code] = info;
    setSetting(_escrowKey, jsonEncode(m));
  }

  void clearEscrow(String code) {
    final m = escrows()..remove(code);
    setSetting(_escrowKey, jsonEncode(m));
  }

  bool isRoomPaid(String code) =>
      (getSetting<List<dynamic>>(_paidKey) ?? const []).contains(code);

  void markRoomPaid(String code) {
    final list =
        (getSetting<List<dynamic>>(_paidKey) ?? const []).cast<String>().toList();
    if (list.contains(code)) return;
    list.add(code);
    setSetting(_paidKey, list.length > 200 ? list.sublist(list.length - 200) : list);
  }

  // --- Purchase flags (set by the IAP service in Phase 5) -----------------------

  bool get adsRemoved => getSetting<bool>('remove_ads') ?? false;
  bool get proPass => getSetting<bool>('pro_pass') ?? false;
  Future<void> setAdsRemoved(bool v) => setSetting('remove_ads', v);
  Future<void> setProPass(bool v) => setSetting('pro_pass', v);

  // --- Player stats -------------------------------------------------------

  static const _statsKey = 'player_stats';

  PlayerStats loadStats() {
    final raw = getSetting<String>(_statsKey);
    if (raw == null) return PlayerStats();
    return PlayerStats.fromJson(jsonDecode(raw) as Map);
  }

  Future<void> saveStats(PlayerStats stats) async {
    await setSetting(_statsKey, jsonEncode(stats.toJson()));
    touch();
  }

  // --- Game progress ------------------------------------------------------

  SavedGame? loadGame(String puzzleId) {
    if (!_games.isOpen) return null;
    final raw = _games.get(puzzleId);
    if (raw == null) return null;
    return SavedGame.fromJson(jsonDecode(raw as String) as Map);
  }

  Future<void> saveGame(SavedGame game) async {
    if (!_games.isOpen) return;
    await _games.put(game.puzzleId, jsonEncode(game.toJson()));
    touch();
  }

  Future<void> deleteGame(String puzzleId) => _games.delete(puzzleId);

  /// IDs of puzzles that were won or given up.
  Set<String> finishedPuzzleIds({bool winsOnly = false}) {
    final ids = <String>{};
    if (!_games.isOpen) return ids;
    for (final key in _games.keys) {
      final game = loadGame(key as String);
      if (game == null) continue;
      if (game.status == GameStatus.won ||
          (!winsOnly && game.status == GameStatus.gaveUp)) {
        ids.add(game.puzzleId);
      }
    }
    return ids;
  }

  /// Most recent unfinished game, if any (used for "Continue" on Home).
  SavedGame? latestUnfinished() {
    SavedGame? best;
    if (!_games.isOpen) return null;
    for (final key in _games.keys) {
      final game = loadGame(key as String);
      if (game == null || game.status != GameStatus.playing) continue;
      if (game.guesses.isEmpty) continue;
      best = game;
    }
    return best;
  }
}
