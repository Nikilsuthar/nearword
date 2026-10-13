import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../hint_engine.dart';
import '../hints_controller.dart';

/// Bottom sheet listing the three hints, each payable with coins or a
/// rewarded ad.
class HintSheet extends GetView<HintsController> {
  const HintSheet({super.key});

  static const _items = <(HintType, IconData, String, String)>[
    (
      HintType.betterWord,
      Icons.auto_awesome,
      'Reveal a closer word',
      'Adds a word that ranks better than your best guess.',
    ),
    (
      HintType.firstLetter,
      Icons.abc,
      'First letter',
      'Shows the first letter of the secret word.',
    ),
    (
      HintType.wordLength,
      Icons.straighten,
      'Word length',
      'Shows how many letters the word has.',
    ),
  ];

  Future<void> _use(HintType type, HintPayment payment) async {
    final message = await controller.use(type, payment);
    if (message == null) {
      Get.back(); // close the sheet on success
    } else {
      Get.snackbar('Hint', message, snackPosition: SnackPosition.TOP);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Obx(() {
            final busy = controller.busy.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hints',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 18,
                      color: AppColors.yellow,
                    ),
                    const SizedBox(width: 4),
                    Text('${controller.coins.value}'),
                  ],
                ),
                if (controller.unlimited)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Pro Pass: unlimited free hints'),
                  ),
                const SizedBox(height: 8),
                for (final (type, icon, title, subtitle) in _items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: AppColors.brand),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!controller.isAvailable(type))
                            const Text('Already used or unavailable')
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: busy
                                        ? null
                                        : () => _use(type, HintPayment.coins),
                                    child: Text(
                                      controller.unlimited
                                          ? 'Use (free)'
                                          : 'Use · ${controller.costFor(type)} coins',
                                    ),
                                  ),
                                ),
                                if (!controller.unlimited) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: busy ||
                                              !controller.rewardedReady.value
                                          ? null
                                          : () => _use(
                                                type,
                                                HintPayment.rewardedAd,
                                              ),
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Free · ad'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
