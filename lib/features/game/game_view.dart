import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_background.dart';
import '../battle/battle_controller.dart';
import '../battle/widgets/battle_strip.dart';
import '../hints/widgets/hint_sheet.dart';
import 'game_controller.dart';
import 'widgets/guess_input.dart';
import 'widgets/guess_tile.dart';
import 'widgets/latest_card.dart';
import 'widgets/radar_view.dart';

class GameView extends GetView<GameController> {
  const GameView({super.key});

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('keep_playing'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _giveUp() async {
    final battle = controller.isBattle;
    final ok = await _confirm(
      'give_up_title'.tr,
      battle ? 'give_up_body_battle'.tr : 'give_up_body'.tr,
      'give_up'.tr,
    );
    if (ok) controller.giveUp();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !controller.isBattle,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !controller.isBattle) return;
        if (!controller.isPlaying) return;
        if (await _confirm(
          'leave_battle_title'.tr,
          'leave_battle_body'.tr,
          'leave'.tr,
        )) {
          controller.giveUp();
        }
      },
      child: AppScaffold(
        maxWidth: 720,
        appBar: AppBar(
          title: Obx(() => Text(controller.title)),
          actions: [
            Obx(
              () => IconButton(
                tooltip: 'hints'.tr,
                icon: const Icon(Icons.lightbulb_outline_rounded),
                onPressed: controller.isPlaying &&
                        !controller.isLoading.value &&
                        !controller.isBattle
                    ? () => Get.bottomSheet<void>(
                          const HintSheet(),
                          isScrollControlled: true,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                        )
                    : null,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'settings'.tr,
              onSelected: (v) {
                if (v == 'giveup') _giveUp();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'giveup',
                  enabled: controller.isPlaying,
                  child: Text('give_up'.tr),
                ),
              ],
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = controller.loadError.value;
          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error.tr, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          controller.loadPuzzle(controller.initialPuzzleId),
                      child: Text('retry'.tr),
                    ),
                  ],
                ),
              ),
            );
          }
          return _Body(controller: controller);
        }),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final battle = controller.battle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Status row: guesses, best rank, timer.
          Obx(() {
            final best = controller.bestRank;
            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          StatPill(
                            icon: Icons.tag_rounded,
                            label: '${controller.guessCount}',
                            semantics: '${controller.guessCount} guesses',
                          ),
                          const SizedBox(width: 8),
                          StatPill(
                            icon: Icons.near_me_rounded,
                            color:
                                best == null ? null : AppColors.forRank(best),
                            label: best == null
                                ? 'best_none'.tr
                                : 'best_n'.trParams({'n': '$best'}),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (battle != null)
                  Obx(() {
                    final left = (battle.remainingMs.value / 1000).ceil();
                    return StatPill(
                      icon: Icons.timer_rounded,
                      color: left <= 20 ? AppColors.red : AppColors.cyan,
                      label: clockLabel(left),
                    );
                  })
                else
                  StatPill(
                    icon: Icons.timer_outlined,
                    label: clockLabel(controller.elapsedSeconds.value),
                  ),
              ],
            );
          }),
          if (battle is BattleController) ...[
            const SizedBox(height: 10),
            BattleStrip(battle: battle),
          ],
          // Letter / length hints.
          Obx(() {
            final hint = controller.hintSummary;
            if (hint == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded,
                      size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(hint,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Obx(() => LatestCard(guess: controller.latest.value)),
          const SizedBox(height: 12),
          // List / radar switch.
          Obx(
            () => SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: scheme.outline),
              ),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_list_rounded, size: 18),
                  label: Text('list_tab'.tr),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.radar_rounded, size: 18),
                  label: Text('radar_tab'.tr),
                ),
              ],
              selected: {controller.radarView.value},
              onSelectionChanged: (s) => controller.radarView.value = s.first,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Obx(() {
              final list = controller.guesses.toList();
              if (controller.radarView.value) {
                return RadarView(
                  guesses: list,
                  latestWord: controller.latest.value?.word,
                );
              }
              final hi = controller.highlightedWord.value;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => GuessTile(
                  key: ValueKey(list[i].word),
                  guess: list[i],
                  highlighted: list[i].word == hi,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Hidden once the game ends; the Result screen opens shortly after.
          Obx(
            () => controller.isPlaying
                ? const GuessInput()
                : const SizedBox(height: 58),
          ),
        ],
      ),
    );
  }
}
