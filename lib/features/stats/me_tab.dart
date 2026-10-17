import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/ui_kit.dart';
import '../../routes/app_routes.dart';
import '../home/home_controller.dart';
import '../result/widgets/stat_chip.dart';
import 'stats_controller.dart';
import 'widgets/distribution_chart.dart';

/// Profile: who I am, my stats and achievements.
class MeTab extends GetView<StatsController> {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final home = Get.find<HomeController>();
    final fontScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();

    return Obx(() {
      final s = controller.stats;
      final name = home.settings.nickname.value;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          // --- Profile header ------------------------------------------------
          GradientPanel(
            colors: AppColors.heroGradient,
            child: Row(
              children: [
                InitialAvatar(
                  name: name.isEmpty ? '?' : name,
                  colorIndex: 0,
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'hello_anon'.tr : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StyleChip(
                        label: styleLevelLabel(
                          home.settings.wordSet.value,
                          home.settings.level.value,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CoinText(
                      s.coins,
                      size: 20,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(Routes.settings),
                  icon: const Icon(Icons.settings_rounded),
                  label: Text('settings'.tr),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: home.showHowToPlay,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(
                    'how_to_play'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          SectionTitle('stats'.tr),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 104 + 90 * (fontScale - 1),
            ),
            children: [
              StatChip(
                icon: Icons.sports_esports_rounded,
                value: '${s.gamesPlayed}',
                label: 'stat_played'.tr,
              ),
              StatChip(
                icon: Icons.percent_rounded,
                value: (s.winRate * 100).toStringAsFixed(0),
                label: 'stat_wins_pct'.tr,
              ),
              StatChip(
                icon: Icons.functions_rounded,
                value: s.averageGuesses.toStringAsFixed(1),
                label: 'stat_avg'.tr,
              ),
              StatChip(
                icon: Icons.local_fire_department_rounded,
                value: '${controller.currentStreak}',
                label: 'stat_streak'.tr,
              ),
              StatChip(
                icon: Icons.emoji_events_rounded,
                value: '${s.maxStreak}',
                label: 'stat_max_streak'.tr,
              ),
              StatChip(
                icon: Icons.monetization_on_rounded,
                value: '${s.coins}',
                label: 'stat_coins'.tr,
              ),
            ],
          ),

          SectionTitle('guess_distribution'.tr),
          SoftCard(child: DistributionChart(data: controller.distribution)),

          SectionTitle('achievements'.tr),
          for (final a in controller.achievements)
            Builder(
              builder: (_) {
                final unlocked = controller.isUnlocked(a);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          unlocked
                              ? Icons.military_tech_rounded
                              : Icons.lock_outline_rounded,
                          color: unlocked ? AppColors.gold : scheme.outline,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ach_${a.id}_t'.tr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'ach_${a.id}_d'.tr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${a.rewardCoins}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: unlocked ? AppColors.green : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    });
  }
}
