import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sfx.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/game_result.dart';
import '../../../routes/app_routes.dart';
import '../../home/home_controller.dart';
import '../battle_controller.dart';
import '../widgets/battle_widgets.dart';

/// Live standings that turn into the final ranking (and the coin payout) when
/// the round closes. Used by live battles and challenges.
class RoomResultView extends StatefulWidget {
  const RoomResultView({super.key});

  @override
  State<RoomResultView> createState() => _RoomResultViewState();
}

class _RoomResultViewState extends State<RoomResultView> {
  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 3));
  Worker? _worker;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    final battle = Get.find<BattleController>();
    _worker = ever(battle.phase, (_) => _celebrate(battle));
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate(battle));
  }

  /// Plays the win / finish sound and the confetti once, when the round ends.
  void _celebrate(BattleController battle) {
    if (_celebrated || battle.phase.value != BattlePhase.over) return;
    _celebrated = true;
    final won = battle.myPlace == 1 && battle.standings.length > 1;
    if (won) {
      _confetti.play();
      Sfx.play('win');
    } else {
      Sfx.play('lose', volume: 0.7);
    }
    if ((battle.myPayout.value ?? 0) > 0) {
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        () => Sfx.play('coin'),
      );
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _done(BattleController battle) async {
    final r = battle.room.value;
    if (r != null && r.isChallenge) {
      // Challenge: back to the challenge room (it keeps running / is closed).
      if (battle.phase.value == BattlePhase.over) {
        await battle.leave();
        _backToFriends();
      } else {
        Get.back<void>();
      }
      return;
    }
    await battle.leave();
    _backToFriends();
  }

  /// Back to the Home screen with the Friends tab selected.
  void _backToFriends() {
    Get.until((route) => route.settings.name == Routes.home);
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().tab.value = 2;
    }
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
        body: Stack(children: [
          Obx(() {
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
                    won
                        ? '🏆'
                        : finished
                            ? placeLabel(place)
                            : '⏳',
                    style: const TextStyle(fontSize: 64),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                ),
                const SizedBox(height: 8),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (r != null && finished) ...[
                  // no spoilers before the round ends
                  const SizedBox(height: 14),
                  SoftCard(
                    borderColor: AppColors.teal,
                    child: Column(
                      children: [
                        Text(
                          'winning_word'.tr,
                          style: TextStyle(
                            fontSize: 12.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.secretWord.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppColors.teal,
                            letterSpacing: 2,
                          ),
                        ).animate().fadeIn(delay: 300.ms).scale(
                              begin: const Offset(0.8, 0.8),
                              curve: Curves.easeOutBack,
                            ),
                        if (r.closestWords.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'top3_words'.tr,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0;
                                  i < math.min(3, r.closestWords.length);
                                  i++)
                                _WordPill(
                                  medal: ['🥇', '🥈', '🥉'][i],
                                  word: r.closestWords[i],
                                )
                                    .animate()
                                    .fadeIn(delay: (500 + i * 150).ms)
                                    .slideY(begin: 0.4),
                            ],
                          ),
                        ],
                      ],
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
                                  ? 'payout_back'
                                      .trParams({'n': '${payout ?? 0}'})
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
                    payout:
                        finished ? room?.result?.payouts[order[i].id] : null,
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 22,
              gravity: 0.25,
              shouldLoop: false,
              colors: const [
                AppColors.green,
                AppColors.gold,
                AppColors.cyan,
                AppColors.red,
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// A word with its medal. A plain Row (not a Chip) so the emoji is never
/// squeezed into Chip's small avatar box and clipped.
class _WordPill extends StatelessWidget {
  const _WordPill({required this.medal, required this.word});

  final String medal;
  final String word;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              medal,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
