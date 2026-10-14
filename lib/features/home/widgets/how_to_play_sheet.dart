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
            Text('how_title'.tr, style: text.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'how_intro'.tr,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 18),
            _Step(
              color: AppColors.green,
              title: 'how_green'.tr,
              body: 'how_green_sub'.tr,
            ),
            _Step(
              color: AppColors.yellow,
              title: 'how_yellow'.tr,
              body: 'how_yellow_sub'.tr,
            ),
            _Step(
              color: AppColors.red,
              title: 'how_red'.tr,
              body: 'how_red_sub'.tr,
            ),
            const SizedBox(height: 12),
            Text(
              'how_tip'.tr,
              style: text.bodyMedium?.copyWith(
                color: text.bodyMedium?.color?.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: Get.back,
                child: Text('how_go'.tr),
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
