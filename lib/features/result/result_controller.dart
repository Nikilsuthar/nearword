import 'package:confetti/confetti.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/ad_service.dart';
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
  final _ads = Get.find<AdService>();

  /// Set after the player doubles this game's coins with a rewarded ad.
  final RxBool doubled = false.obs;
  final RxBool doubling = false.obs;

  /// Reads [doubled] first so an enclosing Obx always subscribes to it.
  bool get canDouble =>
      !doubled.value && result.coinsEarned > 0 && !result.alreadyRecorded;
  RxBool get rewardedReady => _ads.rewardedReady;

  String get shareText => ShareText.build(result);

  /// Label of the "next" button, depending on how the game was started.
  String get nextLabel => switch (result.mode) {
        PuzzleMode.daily => 'Play a quick puzzle',
        PuzzleMode.category => 'Another ${result.title} word',
        _ => 'Next puzzle',
      };

  @override
  void onReady() {
    super.onReady();
    if (result.won && !result.alreadyRecorded) confetti.play();
    if (!result.alreadyRecorded) _ads.recordGameEnd();
  }

  @override
  void onClose() {
    confetti.dispose();
    super.onClose();
  }

  Future<void> share() =>
      Share.share(shareText);

  /// Rewarded ad: grants the coins earned in this game a second time.
  /// Returns false if the ad was unavailable or dismissed early.
  Future<bool> doubleCoins() async {
    if (!canDouble || doubling.value) return false;
    doubling.value = true;
    try {
      final earned = await _ads.showRewarded();
      if (!earned) return false;
      _stats.addCoins(result.coinsEarned);
      doubled.value = true;
      return true;
    } finally {
      doubling.value = false;
    }
  }

  /// Opens another puzzle. An interstitial may play first (only here,
  /// between games).
  Future<void> nextPuzzle() async {
    await _ads.maybeShowInterstitial();
    final String id;
    if (result.mode == PuzzleMode.category) {
      final catId = result.puzzleId.split('-')[1];
      id = _repo.randomCategoryId(catId);
    } else {
      id = _repo.randomId();
    }
    Get.offNamed(Routes.game, arguments: id);
  }

  Future<void> goHome() async {
    await _ads.maybeShowInterstitial();
    Get.back<void>();
  }
}
