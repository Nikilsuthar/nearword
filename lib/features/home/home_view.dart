import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/logo.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  Future<void> _challengeDialog() async {
    final input = TextEditingController();
    final error = RxnString();
    void submit(String raw) {
      final id = controller.challengeIdFor(raw);
      if (id == null) {
        error.value = 'That code is not valid.';
      } else {
        Get.back<String>(result: id);
      }
    }

    // The dialog only returns what to do; navigation happens after it has
    // fully closed (pushing a route in the same frame trips a framework
    // assertion).
    final choice = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Challenge a friend'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share a code: your friend gets the same secret word, so you can '
                'compare who needs fewer guesses.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Get.back<String>(result: 'create'),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Create & share a challenge'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Got a code?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Obx(
                () => TextField(
                  controller: input,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    errorText: error.value,
                    counterText: '',
                  ),
                  onSubmitted: (v) => submit(v),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<String>(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => submit(input.text),
            child: const Text('Play code'),
          ),
        ],
      ),
    );
    // `input` is intentionally not disposed here: the dialog's exit animation
    // may still be using it, and it holds no resources.
    if (choice == 'create') {
      await controller.createChallenge();
    } else if (choice != null) {
      controller.openPuzzle(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Tiles grow with the user's font-size setting so text never overflows.
    final fontScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final tileHeight = 168.0 + 170.0 * (fontScale - 1);
    return AppScaffold(
      bottomNavigationBar: const BannerAdWidget(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // --- Header -----------------------------------------------------
          Row(
            children: [
              const LogoMark(size: 38),
              const SizedBox(width: 10),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Wordmark(fontSize: 26),
                  ),
                ),
              ),
              Obx(
                () => StatPill(
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.deepOrangeAccent,
                  label: '${controller.streak.value}',
                  semantics: '${controller.streak.value} day streak',
                ),
              ),
              const SizedBox(width: 6),
              Obx(
                () => StatPill(
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.gold,
                  label: '${controller.coins.value}',
                  semantics: '${controller.coins.value} coins',
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: controller.openSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 18),

          // --- Daily ------------------------------------------------------
          Obx(
            () => _DailyCard(
              controller: controller,
              state: controller.dailyState.value,
              number: controller.dailyNumber.value,
              guesses: controller.dailyGuesses.value,
            ),
          )
              .animate()
              .fadeIn(delay: 80.ms)
              .slideY(begin: 0.06, curve: Curves.easeOut),
          const SizedBox(height: 14),

          // --- Continue -----------------------------------------------------
          Obx(() {
            final r = controller.resumable.value;
            if (r == null || r.puzzleId == controller.dailyId) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
                          const Text('Continue your game',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('${r.guesses.length} guesses so far'),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            );
          }),

          // --- Modes ----------------------------------------------------------
          Text('Play', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Column(
            children: [
              SizedBox(
                height: tileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.shuffle_rounded,
                        color: AppColors.cyan,
                        title: 'Quick play',
                        subtitle: 'Random word',
                        onTap: controller.playRandom,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.grid_view_rounded,
                        color: AppColors.pink,
                        title: 'Categories',
                        subtitle: 'Pick a theme',
                        onTap: controller.openCategories,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: tileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.bolt_rounded,
                        color: AppColors.gold,
                        title: 'Battle',
                        subtitle: 'Race your friends',
                        badge: 'LIVE',
                        onTap: controller.openBattle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.group_add_rounded,
                        color: AppColors.green,
                        title: 'Challenge',
                        subtitle: 'Same word, one code',
                        onTap: _challengeDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 160.ms),
          const SizedBox(height: 18),

          // --- Stats strip --------------------------------------------------------
          Obx(() {
            controller.coins.value; // rebuild when progress changes
            final s = controller.statsRepo.stats;
            return SoftCard(
              onTap: controller.openStats,
              child: Row(
                children: [
                  Expanded(
                    child: _Mini(value: '${s.gamesPlayed}', label: 'Played'),
                  ),
                  Expanded(
                    child: _Mini(
                      value: '${(s.winRate * 100).round()}%',
                      label: 'Win rate',
                    ),
                  ),
                  Expanded(
                    child: _Mini(value: '${s.maxStreak}', label: 'Best streak'),
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
              label: const Text('How to play'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.controller,
    required this.state,
    required this.number,
    required this.guesses,
  });

  final HomeController controller;
  final DailyState state;
  final int number;
  final int guesses;

  @override
  Widget build(BuildContext context) {
    final n = number;
    final g = guesses;
    final (title, cta) = switch (state) {
      DailyState.fresh => ("Find today's word", 'Play today'),
      DailyState.inProgress => ('$g guesses so far', 'Keep going'),
      DailyState.solved => ('Solved in $g guesses', 'View result'),
      DailyState.gaveUp => ('Better luck tomorrow', 'View result'),
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFF), Color(0xFF4A2FD6), Color(0xFF2A1B8C)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'DAILY  #$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state == DailyState.solved
                        ? 'Come back tomorrow for a new word.'
                        : 'Everyone in the world gets the same word today.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: controller.playDaily,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3B24B8),
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
                          state == DailyState.solved
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.red,
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
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
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
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
