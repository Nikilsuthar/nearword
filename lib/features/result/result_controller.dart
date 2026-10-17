import 'package:confetti/confetti.dart';

import '../../core/services/sfx.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/ads.dart';
import '../../core/services/daily_board_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/share_text.dart';
import '../../data/models/game_result.dart';
import '../../data/models/puzzle.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';

class ResultController extends GetxController {
  final GameResult result = Get.arguments as GameResult;
  final ConfettiController confetti = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  final _repo = Get.find<PuzzleRepository>();
  final _stats = Get.find<StatsRepository>();
  final _settings = Get.find<SettingsService>();

  /// Set after the player doubles this game's coins with a rewarded ad.
  final RxBool doubled = false.obs;
  final RxBool doubling = false.obs;

  /// Place on today's board after a daily puzzle (null = unknown / offline).
  final RxnInt boardPlace = RxnInt();

  /// Reads [doubled] first so an enclosing Obx always subscribes to it.
  bool get canDouble =>
      !doubled.value && result.coinsEarned > 0 && !result.alreadyRecorded;

  String get shareText => ShareText.build(result);

  /// Translation key + params of the "next" button.
  (String, Map<String, String>) get nextLabel => switch (result.mode) {
        PuzzleMode.daily => ('next_quick', const <String, String>{}),
        PuzzleMode.category => ('next_category', {'c': result.title}),
        _ => ('next_puzzle', const <String, String>{}),
      };

  @override
  void onReady() {
    super.onReady();
    if (result.won && !result.alreadyRecorded) {
      confetti.play();
      Sfx.play('win');
      if (result.coinsEarned > 0) {
        Future<void>.delayed(
          const Duration(milliseconds: 900),
          () => Sfx.play('coin'),
        );
      }
    } else if (!result.won && !result.alreadyRecorded) {
      Sfx.play('lose', volume: 0.7);
    }
    if (!result.alreadyRecorded) Ads.gameFinished();
    Ads.prepareRewarded();
    if (result.mode == PuzzleMode.daily) _loadBoardPlace();
  }

  @override
  void onClose() {
    confetti.dispose();
    super.onClose();
  }

  Future<void> _loadBoardPlace() async {
    if (!Get.isRegistered<DailyBoardService>()) return;
    final board = Get.find<DailyBoardService>();
    if (!board.enabled) return;
    final p = _repo.puzzleById(result.puzzleId);
    if (p == null) return;
    try {
      // Give the submission a moment to land before reading the board.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final list = await board.top(p.id.substring(6, 16), p.wordSet, p.level);
      final i = list.indexWhere((e) => e.uid == board.myId);
      if (i >= 0) boardPlace.value = i + 1;
    } catch (_) {}
  }

  Future<void> share() => Share.share(shareText);

  /// Rewarded ad: grants the coins earned in this game a second time.
  /// Returns false if the ad was unavailable or dismissed early.
  Future<bool> doubleCoins() async {
    if (!canDouble || doubling.value) return false;
    doubling.value = true;
    try {
      if (!await Ads.rewarded('double_coins')) return false;
      _stats.addCoins(result.coinsEarned);
      doubled.value = true;
      return true;
    } finally {
      doubling.value = false;
    }
  }

  /// Opens another puzzle. An interstitial may play first (only here, between
  /// games, and only when the safe_ads rules allow it).
  Future<void> nextPuzzle() async {
    final set = _settings.wordSet.value;
    final level = _settings.level.value;
    final String id;
    if (result.mode == PuzzleMode.category) {
      id = _repo.randomCategoryId(result.puzzleId.split('-')[1], set, level);
    } else {
      id = _repo.randomId(set, level);
    }
    await Ads.betweenGames(
      'next_puzzle',
      () => Get.offNamed(Routes.game, arguments: id),
    );
  }

  Future<void> goHome() async {
    await Ads.betweenGames('result_back', () => Get.back<void>());
  }
}
