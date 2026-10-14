import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/game_result.dart';
import '../../../routes/app_routes.dart';
import '../battle_controller.dart';
import '../widgets/battle_widgets.dart';

/// Live standings that turn into the final ranking (and the coin payout) when
/// the round closes. Used by live battles and challenges.
class RoomResultView extends StatelessWidget {
  const RoomResultView({super.key});

  Future<void> _done(BattleController battle) async {
    final r = battle.room.value;
    if (r != null && r.isChallenge) {
      // Challenge: back to the challenge room (it keeps running / is closed).
      if (battle.phase.value == BattlePhase.over) {
        await battle.leave();
        Get.until((route) => route.settings.name == Routes.home);
      } else {
        Get.back<void>();
      }
      return;
    }
    await battle.leave();
    Get.until((route) => route.settings.name == Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments is GameResult ? Get.arguments as GameResult : null;
    final battle = Get.find<BattleController>();
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(battle);
      },
      child: AppScaffold(
        body: Obx(() {
          final room = battle.room.value;
          final finished = battle.phase.value == BattlePhase.over;
          final order = battle.standings;
          final place = battle.myPlace;
          final payout = battle.myPayout.value;
          final stake = room?.stake ?? 0;
          final won = finished && place == 1 && order.length > 1;
          final headline = !finished
              ? 'round_in_progress'.tr
              : won
                  ? 'you_won_battle'.tr
                  : 'you_finished'.trParams({'p': placeLabel(place)});
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Center(
                child: Text(
                  won ? '🏆' : finished ? placeLabel(place) : '⏳',
                  style: const TextStyle(fontSize: 64),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (r != null) ...[
                const SizedBox(height: 6),
                Text(
                  'word_was'.trParams({'w': r.secretWord.toUpperCase()}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                    letterSpacing: 1,
                  ),
                ),
              ],

              // --- Coins ----------------------------------------------------------
              if (stake > 0 && finished) ...[
                const SizedBox(height: 14),
                SoftCard(
                  borderColor: (payout ?? 0) > stake
                      ? AppColors.green
                      : (payout ?? 0) > 0
                          ? AppColors.yellow
                          : AppColors.red,
                  child: Column(
                    children: [
                      CoinText(
                        payout ?? 0,
                        size: 28,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (payout ?? 0) > stake
                            ? 'payout_won'.trParams({'n': '${payout ?? 0}'})
                            : (payout ?? 0) > 0
                                ? 'payout_back'.trParams({'n': '${payout ?? 0}'})
                                : 'payout_none'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room?.result?.solved ?? false
                            ? 'payout_solved_note'.tr
                            : 'payout_nearest_note'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    finished ? 'final_ranking'.tr : 'live_ranking'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (!finished)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                ],
              ),
              if (!finished && room != null && !room.isChallenge)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'round_ends_note'.trParams({
                      's': '${AppConstants.battleGraceSeconds}',
                    }),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              for (var i = 0; i < order.length; i++)
                StandingRow(
                  place: i + 1,
                  player: order[i],
                  isMe: order[i].id == battle.playerId,
                  payout: finished ? room?.result?.payouts[order[i].id] : null,
                ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => Share.share(
                  'share_battle'.trParams({
                    'p': finished ? placeLabel(place) : '…',
                    'g': '${r?.guessCount ?? 0}',
                  }),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text('share'.tr),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _done(battle),
                child: Text('back_to_lobby'.tr),
              ),
            ],
          );
        }),
      ),
    );
  }
}
