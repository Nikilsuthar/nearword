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
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: Obx(
              () => NavigationBar(
                selectedIndex: controller.tab.value,
                onDestinationSelected: (i) {
                  controller.tab.value = i;
                  if (i == 1) Get.find<BoardController>().reload();
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: 'tab_home'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.leaderboard_outlined),
                    selectedIcon: const Icon(Icons.leaderboard_rounded),
                    label: 'tab_rank'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.groups_outlined),
                    selectedIcon: const Icon(Icons.groups_rounded),
                    label: 'tab_play'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: 'tab_me'.tr,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(top: false, child: Ads.banner('home')),
        ],
      ),
    );
  }
}
