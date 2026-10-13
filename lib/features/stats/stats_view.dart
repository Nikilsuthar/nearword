import '../../core/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../result/widgets/stat_chip.dart';
import 'stats_controller.dart';
import 'widgets/distribution_chart.dart';

class StatsView extends GetView<StatsController> {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      maxWidth: 640,
      appBar: AppBar(title: const Text('Stats')),
      bottomNavigationBar: const BannerAdWidget(),
      body: Obx(() {
              final s = controller.stats;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      // Height follows the font-size setting.
                      mainAxisExtent: 104 +
                          90 *
                              (MediaQuery.textScalerOf(context)
                                      .scale(1)
                                      .clamp(1.0, 1.8)
                                      .toDouble() -
                                  1),
                    ),
                    children: [
                      StatChip(
                        icon: Icons.sports_esports,
                        value: '${s.gamesPlayed}',
                        label: 'Played',
                      ),
                      StatChip(
                        icon: Icons.percent,
                        value: (s.winRate * 100).toStringAsFixed(0),
                        label: 'Win %',
                      ),
                      StatChip(
                        icon: Icons.functions,
                        value: s.averageGuesses.toStringAsFixed(1),
                        label: 'Avg guesses',
                      ),
                      StatChip(
                        icon: Icons.local_fire_department,
                        value: '${controller.currentStreak}',
                        label: 'Streak',
                      ),
                      StatChip(
                        icon: Icons.emoji_events,
                        value: '${s.maxStreak}',
                        label: 'Max streak',
                      ),
                      StatChip(
                        icon: Icons.monetization_on,
                        value: '${s.coins}',
                        label: 'Coins',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Guess distribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DistributionChart(data: controller.distribution),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Achievements',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in controller.achievements)
                    Builder(
                      builder: (_) {
                        final unlocked = controller.isUnlocked(a);
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              unlocked
                                  ? Icons.military_tech_rounded
                                  : Icons.lock_outline,
                              color: unlocked
                                  ? AppColors.brand
                                  : theme.colorScheme.outline,
                            ),
                            title: Text(a.title),
                            subtitle: Text(a.description),
                            trailing: Text(
                              '+${a.rewardCoins}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: unlocked ? AppColors.green : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
      }),
    );
  }
}
