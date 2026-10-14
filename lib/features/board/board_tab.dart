import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/daily_board_service.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/seeded.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/puzzle.dart';
import '../../routes/app_routes.dart';
import 'board_controller.dart';

/// Daily tournament leaderboard.
class BoardTab extends GetView<BoardController> {
  const BoardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'board_title'.tr,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'daily_label'.trParams({'n': '${controller.dailyNumber}'}),
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'board_refresh'.tr,
                onPressed: controller.reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(
            () => ChoiceCards<WordSet>(
              selected: controller.set.value,
              onChanged: (v) => controller.set.value = v,
              options: [
                ChoiceOption(WordSet.regular, 'style_regular'.tr),
                ChoiceOption(WordSet.india, 'style_india'.tr),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => ChoiceCards<Difficulty>(
              selected: controller.level.value,
              onChanged: (v) => controller.level.value = v,
              options: [
                ChoiceOption(Difficulty.easy, 'level_easy'.tr),
                ChoiceOption(Difficulty.medium, 'level_medium'.tr),
                ChoiceOption(Difficulty.hard, 'level_hard'.tr),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Obx(() {
            // Read every observable first so Obx always subscribes to them,
            // even when the board is switched off.
            final loading = controller.loading.value;
            final failed = controller.failed.value;
            final list = controller.entries.toList();
            final place = controller.myPlace.value;
            if (!controller.enabled) return const _OffCard();
            if (loading && list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (failed && list.isEmpty) {
              return _Message(
                icon: Icons.wifi_off_rounded,
                text: 'board_offline'.tr,
                action: TextButton(
                  onPressed: controller.reload,
                  child: Text('retry'.tr),
                ),
              );
            }
            if (list.isEmpty) {
              return _Message(
                icon: Icons.emoji_events_outlined,
                text: 'board_empty'.tr,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place == null
                      ? 'board_play_first'.tr
                      : 'board_your_place'.trParams({'n': '$place'}),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: place == null
                        ? scheme.onSurface.withValues(alpha: 0.65)
                        : AppColors.green,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < list.length; i++)
                  _EntryRow(
                    place: i + 1,
                    entry: list[i],
                    mine: list[i].uid == controller.myId,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.place, required this.entry, required this.mine});

  final int place;
  final DailyEntry entry;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = switch (place) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$place' };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? scheme.primary.withValues(alpha: 0.14) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mine ? scheme.primary : scheme.outline,
          width: mine ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              medal,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          InitialAvatar(
            name: entry.name,
            colorIndex: Seeded.hash(entry.uid) % 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '${entry.name} (${'board_you'.tr})' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  entry.solved
                      ? 'board_solved'.trParams({
                          'g': '${entry.guesses}',
                          't': clockLabel(entry.seconds),
                        })
                      : 'board_nearest'.trParams({'r': '${entry.best}'}),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            entry.solved ? Icons.check_circle_rounded : Icons.near_me_rounded,
            color: entry.solved ? AppColors.green : AppColors.yellow,
          ),
        ],
      ),
    );
  }
}

class _OffCard extends StatelessWidget {
  const _OffCard();

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.cloud_off_rounded,
      text: 'board_off'.tr,
      sub: 'board_off_sub'.tr,
      action: FilledButton(
        onPressed: () => Get.toNamed(Routes.settings),
        child: Text('online_needed_cta'.tr),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.sub, this.action});

  final IconData icon;
  final String text;
  final String? sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
