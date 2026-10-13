import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/icon_map.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/banner_ad_widget.dart';
import 'categories_controller.dart';

class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

  Future<void> _onTap(CategoryItem item) async {
    if (!item.locked) {
      controller.play(item);
      return;
    }
    final canAfford = controller.canAffordUnlock();
    final confirm = await Get.dialog<String>(
      AlertDialog(
        title: Text('Unlock ${item.category.name}?'),
        content: Text(
          canAfford
              ? 'Spend ${controller.unlockCost} coins to unlock this category forever.'
              : 'You need ${controller.unlockCost} coins. Win puzzles and claim your '
                  'daily bonus to earn more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'cancel'),
            child: const Text('Cancel'),
          ),
          Obx(
            () => TextButton.icon(
              onPressed: controller.rewardedReady.value
                  ? () => Get.back(result: 'ad')
                  : null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Free for 24h'),
            ),
          ),
          if (canAfford)
            FilledButton(
              onPressed: () => Get.back(result: 'coins'),
              child: Text('Unlock (${controller.unlockCost})'),
            ),
        ],
      ),
    );
    var unlocked = false;
    if (confirm == 'coins') {
      unlocked = controller.unlock(item);
    } else if (confirm == 'ad') {
      unlocked = await controller.unlockForDay(item);
      if (!unlocked) {
        Get.snackbar(
          'Ad',
          'Ad not available right now.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
    if (unlocked) {
      Get.snackbar(
        'Unlocked',
        '${item.category.name} is now available.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      maxWidth: 840,
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatPill(
                icon: Icons.monetization_on_rounded,
                color: AppColors.gold,
                label: '${controller.coins.value}',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(),
      body: Obx(() {
        // Read the observable here, not inside the LayoutBuilder callback.
        final items = controller.items.toList();
        return LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 700 ? 3 : 2;
            final fontScale = MediaQuery.textScalerOf(context)
                .scale(1)
                .clamp(1.0, 1.8)
                .toDouble();
            return GridView(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Fixed extent that grows with the font-size setting.
                mainAxisExtent: 158 + 140 * (fontScale - 1),
              ),
              children: [
                for (final item in items)
                  _CategoryCard(item: item, onTap: () => _onTap(item)),
              ],
            );
          },
        );
      }),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item, required this.onTap});

  final CategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(
      0xFF000000 | (item.category.id.hashCode * 2654435761 & 0xFFFFFF),
    );
    final tint = HSLColor.fromColor(color).withSaturation(0.7).withLightness(0.62).toColor();

    return Semantics(
      button: true,
      label: '${item.category.name}, ${item.solved} solved'
          '${item.locked ? ', locked' : ''}',
      excludeSemantics: true,
      child: SoftCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (item.locked ? theme.colorScheme.outline : tint)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    categoryIcon(item.category.icon),
                    size: 26,
                    color: item.locked ? theme.colorScheme.outline : tint,
                  ),
                ),
                if (item.locked)
                  const Icon(Icons.lock_rounded, size: 20, color: AppColors.gold),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.solved == 0
                      ? '${item.total} words'
                      : '${item.solved} solved · ${item.total} words',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
