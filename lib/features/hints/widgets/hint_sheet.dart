import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../hint_engine.dart';
import '../hints_controller.dart';

/// Bottom sheet listing the three hints, each payable with coins or a
/// rewarded ad. Cards follow the app theme (same surfaces as everywhere else).
class HintSheet extends GetView<HintsController> {
  const HintSheet({super.key});

  static const _items = <(HintType, IconData, String, String)>[
    (HintType.betterWord, Icons.auto_awesome_rounded, 'hint_closer', 'hint_closer_sub'),
    (HintType.firstLetter, Icons.abc_rounded, 'hint_letter', 'hint_letter_sub'),
    (HintType.wordLength, Icons.straighten_rounded, 'hint_length', 'hint_length_sub'),
  ];

  Future<void> _use(HintType type, HintPayment payment) async {
    final key = await controller.use(type, payment);
    if (key == null) {
      Get.back<void>(); // close the sheet on success
    } else {
      Get.snackbar('hints'.tr, key.tr, snackPosition: SnackPosition.TOP);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Obx(() {
          final busy = controller.busy.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('hints'.tr, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  CoinText(controller.coins.value),
                ],
              ),
              if (controller.unlimited)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('hint_pro'.tr),
                ),
              const SizedBox(height: 10),
              for (final (type, icon, title, subtitle) in _items)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(icon, color: scheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                                Text(
                                  subtitle.tr,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!controller.isAvailable(type))
                        Text(
                          'hint_unavailable'.tr,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed:
                                    busy ? null : () => _use(type, HintPayment.coins),
                                child: Text(
                                  controller.unlimited
                                      ? 'use_free'.tr
                                      : 'use_coins'.trParams(
                                          {'n': '${controller.costFor(type)}'},
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (!controller.unlimited) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => _use(type, HintPayment.rewardedAd),
                                  icon: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'free_ad'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
