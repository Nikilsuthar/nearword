import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';

/// Short, visual explanation of the rules.
class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key});

  static Future<void> show() => Get.bottomSheet<void>(
        const HowToPlaySheet(),
        isScrollControlled: true,
        backgroundColor: Get.theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to play', style: text.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'A secret word is hidden. Every word you try gets a rank: how '
              'close its MEANING is to the secret. Rank 1 is the secret.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 18),
            const _Step(
              color: AppColors.green,
              title: 'Green  ·  rank 1 – 300',
              body: 'Very close in meaning. You are on the right track.',
            ),
            const _Step(
              color: AppColors.yellow,
              title: 'Yellow  ·  rank 301 – 1,500',
              body: 'Same general area, but not quite there.',
            ),
            const _Step(
              color: AppColors.red,
              title: 'Red  ·  above 1,500',
              body: 'Far away. Try a different idea.',
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: think about categories, uses and things that appear '
              'together, not spelling. "ocean" is closer to "sea" than "ocelot".',
              style: text.bodyMedium?.copyWith(
                color: text.bodyMedium?.color?.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: Get.back,
                child: const Text("Let's play"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.color, required this.title, required this.body});

  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
