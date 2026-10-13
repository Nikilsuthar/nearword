import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ad_service.dart';
import '../../data/repositories/stats_repository.dart';
import '../game/game_controller.dart';
import 'hint_engine.dart';

/// How the player pays for a hint.
enum HintPayment { coins, rewardedAd }

/// Handles payment for hints and delegates the effect to [GameController].
class HintsController extends GetxController {
  final _game = Get.find<GameController>();
  final _stats = Get.find<StatsRepository>();
  final _ads = Get.find<AdService>();

  final RxBool busy = false.obs;

  RxInt get coins => _stats.coins;
  RxBool get rewardedReady => _ads.rewardedReady;

  /// Pro Pass = unlimited hints.
  bool get unlimited => _stats.hasPro;

  int costFor(HintType type) => switch (type) {
    HintType.betterWord => AppConstants.hintBetterWordCost,
    HintType.firstLetter => AppConstants.hintFirstLetterCost,
    HintType.wordLength => AppConstants.hintLengthCost,
  };

  bool isAvailable(HintType type) => _game.canApplyHint(type);

  /// Returns a user-facing message when the hint could not be used, or null on
  /// success.
  Future<String?> use(HintType type, HintPayment payment) async {
    if (busy.value) return null;
    // Validate first so a player is never charged for a no-op hint.
    if (!_game.canApplyHint(type)) {
      return 'This hint is not available right now.';
    }

    busy.value = true;
    try {
      if (!unlimited) {
        switch (payment) {
          case HintPayment.coins:
            if (!_stats.spendCoins(costFor(type))) {
              return 'Not enough coins. Win puzzles or watch an ad for a free hint.';
            }
          case HintPayment.rewardedAd:
            final earned = await _ads.showRewarded();
            if (!earned) {
              return 'Ad not available right now. Please try again later.';
            }
        }
      }
      if (!_game.applyHint(type)) {
        // Game state changed while the ad was showing; give the coins back.
        if (!unlimited && payment == HintPayment.coins) {
          _stats.addCoins(costFor(type));
        }
        return 'This hint is not available right now.';
      }
      return null;
    } finally {
      busy.value = false;
    }
  }
}
