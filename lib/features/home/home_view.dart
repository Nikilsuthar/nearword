import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/ads.dart';
import '../../core/widgets/app_background.dart';
import '../battle/friends_tab.dart';
import '../board/board_controller.dart';
import '../board/board_tab.dart';
import '../stats/me_tab.dart';
import 'home_controller.dart';
import 'home_tab.dart';

/// App shell: four tabs behind a bottom navigation bar, banner ad above it.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.tab.value,
          children: const [
            HomeTab(),
            BoardTab(),
            FriendsTab(),
            MeTab(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation first, the ad banner sits below it (above the system bar).
          Obx(
            () => _NavBar(
              selected: controller.tab.value,
              onSelect: (i) {
                controller.tab.value = i;
                if (i == 1) Get.find<BoardController>().reload();
              },
              items: [
                _NavItem(
                    Icons.home_outlined, Icons.home_rounded, 'tab_home'.tr),
                _NavItem(Icons.leaderboard_outlined, Icons.leaderboard_rounded,
                    'tab_rank'.tr),
                _NavItem(
                    Icons.groups_outlined, Icons.groups_rounded, 'tab_play'.tr),
                _NavItem(Icons.person_outline_rounded, Icons.person_rounded,
                    'tab_me'.tr),
              ],
            ),
          ),
          SafeArea(top: false, child: Ads.banner('home')),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Compact bottom bar (fixed 60 dp, no extra system padding: the ad banner
/// below it handles the gesture inset).
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.selected,
    required this.onSelect,
    required this.items,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Container(
        key: const Key('nav_bar'),
        height: 60,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: items[i].label,
                  child: InkResponse(
                    onTap: () => onSelect(i),
                    radius: 40,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 56,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i == selected
                                  ? scheme.primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              i == selected
                                  ? items[i].selectedIcon
                                  : items[i].icon,
                              size: 22,
                              color: i == selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: i == selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
