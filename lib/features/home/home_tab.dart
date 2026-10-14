import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/ui_kit.dart';
import 'home_controller.dart';

class HomeTab extends GetView<HomeController> {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fontScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final tileHeight = 150.0 + 170.0 * (fontScale - 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        // --- Header -------------------------------------------------------
        Row(
          children: [
            const LogoMark(size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() {
                final name = controller.settings.nickname.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? 'hello_anon'.tr
                          : 'hello_name'.trParams({'name': name}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      styleLevelLabel(
                        controller.settings.wordSet.value,
                        controller.settings.level.value,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                );
              }),
            ),
            Obx(
              () => StatPill(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.saffron,
                label: '${controller.streak.value}',
                semantics: 'streak_n'
                    .trParams({'n': '${controller.streak.value}'}),
              ),
            ),
            const SizedBox(width: 6),
            Obx(
              () => StatPill(
                icon: Icons.monetization_on_rounded,
                color: AppColors.gold,
                label: '${controller.coins.value}',
                semantics: 'coins_n'.trParams({'n': '${controller.coins.value}'}),
              ),
            ),
            IconButton(
              tooltip: 'settings'.tr,
              onPressed: controller.openSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),

        // --- Daily ----------------------------------------------------------
        Obx(
          () => _DailyCard(
            state: controller.dailyState.value,
            number: controller.dailyNumber.value,
            guesses: controller.dailyGuesses.value,
            chip: styleLevelLabel(
              controller.settings.wordSet.value,
              controller.settings.level.value,
            ),
            onTap: controller.playDaily,
          ),
        ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.05, curve: Curves.easeOut),
        const SizedBox(height: 12),

        // --- Board preview ------------------------------------------------------
        Obx(() {
          final list = controller.boardPreview.value;
          if (list == null || list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              onTap: () => controller.tab.value = 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'board_peek'.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Text(
                        'board_see_all'.tr,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < list.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(['🥇', '🥈', '🥉'][i],
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              list[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            list[i].solved
                                ? '${list[i].guesses} · ${clockLabel(list[i].seconds)}'
                                : '#${list[i].best}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: list[i].solved
                                  ? AppColors.green
                                  : AppColors.yellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),

        // --- Continue ---------------------------------------------------------------
        Obx(() {
          final r = controller.resumable.value;
          if (r == null || r.puzzleId == controller.dailyId.value) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              onTap: controller.resume,
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded,
                      color: scheme.primary, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'continue_game'.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text('guesses_so_far'
                            .trParams({'n': '${r.guesses.length}'})),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          );
        }),

        // --- Modes ---------------------------------------------------------------------
        SectionTitle('section_play'.tr),
        _TileRow(
          height: tileHeight,
          left: _ModeTile(
            icon: Icons.shuffle_rounded,
            colors: const [Color(0xFF19B5C8), Color(0xFF2F80ED)],
            title: 'mode_quick'.tr,
            subtitle: 'mode_quick_sub'.tr,
            onTap: controller.playRandom,
          ),
          right: _ModeTile(
            icon: Icons.grid_view_rounded,
            colors: const [Color(0xFF2F80ED), Color(0xFF1E5BD6)],
            title: 'mode_categories'.tr,
            subtitle: 'mode_categories_sub'.tr,
            onTap: controller.openCategories,
          ),
        ),
        const SizedBox(height: 12),
        _TileRow(
          height: tileHeight,
          left: _ModeTile(
            icon: Icons.bolt_rounded,
            colors: AppColors.battleGradient,
            title: 'mode_battle'.tr,
            subtitle: 'mode_battle_sub'.tr,
            badge: 'LIVE',
            onTap: () => controller.tab.value = 2,
          ),
          right: _ModeTile(
            icon: Icons.group_add_rounded,
            colors: AppColors.challengeGradient,
            title: 'mode_challenge'.tr,
            subtitle: 'mode_challenge_sub'.tr,
            onTap: () => controller.tab.value = 2,
          ),
        ),
        const SizedBox(height: 14),

        // --- Stats strip -----------------------------------------------------------------
        Obx(() {
          controller.coins.value; // rebuild when progress changes
          final s = controller.statsRepo.stats;
          return SoftCard(
            onTap: () => controller.tab.value = 3,
            child: Row(
              children: [
                Expanded(
                  child: _Mini(value: '${s.gamesPlayed}', label: 'stat_played'.tr),
                ),
                Expanded(
                  child: _Mini(
                    value: '${(s.winRate * 100).round()}%',
                    label: 'stat_winrate'.tr,
                  ),
                ),
                Expanded(
                  child: _Mini(
                    value: '${s.maxStreak}',
                    label: 'stat_beststreak'.tr,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: controller.showHowToPlay,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: Text('how_to_play'.tr),
          ),
        ),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.state,
    required this.number,
    required this.guesses,
    required this.chip,
    required this.onTap,
  });

  final DailyState state;
  final int number;
  final int guesses;
  final String chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = '$guesses';
    final title = switch (state) {
      DailyState.fresh => 'daily_fresh'.tr,
      DailyState.inProgress => 'daily_progress'.trParams({'n': n}),
      DailyState.solved => 'daily_solved'.trParams({'n': n}),
      DailyState.gaveUp => 'daily_gaveup'.tr,
    };
    final cta = switch (state) {
      DailyState.fresh => 'cta_play_today'.tr,
      DailyState.inProgress => 'cta_keep_going'.tr,
      _ => 'cta_view_result'.tr,
    };
    final done = state == DailyState.solved || state == DailyState.gaveUp;
    return GradientPanel(
      colors: AppColors.heroGradient,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(painter: _RingsPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StyleChip(
                      label: 'daily_label'.trParams({'n': '$number'}),
                    ),
                    StyleChip(label: chip),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  done ? 'daily_sub_done'.tr : 'daily_sub_fresh'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E5BD6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          cta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(
        c,
        i * size.width / 8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.30 - i * 0.05),
      );
    }
    canvas.drawCircle(
      c + Offset(cos(0.9), sin(0.9)) * size.width * 0.2,
      7,
      Paint()..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.height, required this.left, required this.right});

  final double height;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
