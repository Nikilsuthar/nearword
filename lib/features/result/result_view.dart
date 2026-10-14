import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_background.dart';
import '../../data/models/puzzle.dart';
import '../../routes/app_routes.dart';
import '../home/home_controller.dart';
import 'result_controller.dart';
import 'widgets/stat_chip.dart';

class ResultView extends GetView<ResultController> {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = controller.result;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppScaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: r.won
                          ? const [AppColors.gold, Color(0xFFFF9F43)]
                          : [scheme.outline, scheme.surfaceContainerHighest],
                    ),
                  ),
                  child: Icon(
                    r.won ? Icons.emoji_events_rounded : Icons.flag_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 14),
              Text(
                r.won ? 'won_title'.tr : 'lost_title'.tr,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Semantics(
                label: 'The secret word was ${r.secretWord}',
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.brandSoft, AppColors.cyan],
                  ).createShader(rect),
                  child: Text(
                    r.secretWord.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
              ),
              Text(
                '${r.title} · ${'level_${r.difficulty.name}'.tr}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: StatChip(
                      icon: Icons.tag_rounded,
                      value: '${r.guessCount}',
                      label: 'stat_guesses'.tr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatChip(
                      icon: Icons.timer_outlined,
                      value: formatDuration(r.seconds),
                      label: 'stat_time'.tr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatChip(
                      icon: Icons.lightbulb_outline_rounded,
                      value: '${r.hintsUsed}',
                      label: 'stat_hints'.tr,
                    ),
                  ),
                ],
              ),
              if (r.coinsEarned > 0) ...[
                const SizedBox(height: 12),
                SoftCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: AppColors.gold,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'coins_added'.trParams({'n': '${r.coinsEarned}'}),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Obx(
                              () => Text(
                                controller.doubled.value
                                    ? 'doubled_msg'.tr
                                    : 'added_balance'.tr,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () => controller.canDouble
                            ? FilledButton.tonalIcon(
                                onPressed: controller.doubling.value
                                    ? null
                                    : () async {
                                        final ok = await controller.doubleCoins();
                                        if (!ok) {
                                          Get.snackbar(
                                            'ok'.tr,
                                            'ad_unavailable'.tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.play_circle_outline),
                                label: const Text('x2'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
              for (final a in r.newAchievements)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SoftCard(
                    borderColor: AppColors.brand,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: AppColors.brandSoft,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'achievement_unlocked'.trParams({'t': 'ach_${a.id}_t'.tr}),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                  '${'ach_${a.id}_d'.tr}  ${'coins_added'.trParams({'n': '${a.rewardCoins}'})}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
                ),
              if (r.mode == PuzzleMode.daily)
                Obx(() {
                  final place = controller.boardPlace.value;
                  if (place == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SoftCard(
                      borderColor: AppColors.green,
                      onTap: () {
                        Get.find<HomeController>().tab.value = 1;
                        Get.until((route) => route.settings.name == Routes.home);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.leaderboard_rounded,
                              color: AppColors.green, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'board_your_place'
                                      .trParams({'n': '$place'}),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text('see_board'.tr),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                }),
              if (r.closestWords.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'nearest_words'.trParams({'w': r.secretWord}),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < r.closestWords.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forRank(i + 2)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.forRank(i + 2)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '${r.closestWords[i]}  ${i + 2}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ).animate().fadeIn(delay: 500.ms),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: controller.share,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text('share_result'.tr),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.nextPuzzle,
                child: Text(controller.nextLabel.$1.trParams(controller.nextLabel.$2)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: controller.goHome,
                child: Text('back'.tr),
              ),
            ],
          ),
          ConfettiWidget(
            confettiController: controller.confetti,
            blastDirection: pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              AppColors.green,
              AppColors.yellow,
              AppColors.pink,
              AppColors.brand,
              AppColors.cyan,
            ],
          ),
        ],
      ),
    );
  }
}
