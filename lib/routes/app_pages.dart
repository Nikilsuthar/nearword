import 'package:get/get.dart';

import '../features/battle/battle_binding.dart';
import '../features/battle/views/battle_hub_view.dart';
import '../features/battle/views/battle_result_view.dart';
import '../features/battle/views/battle_room_view.dart';
import '../features/categories/categories_binding.dart';
import '../features/categories/categories_view.dart';
import '../features/game/game_binding.dart';
import '../features/game/game_view.dart';
import '../features/home/home_binding.dart';
import '../features/home/home_view.dart';
import '../features/result/result_binding.dart';
import '../features/result/result_view.dart';
import '../features/settings/settings_view.dart';
import '../features/splash/splash_binding.dart';
import '../features/splash/splash_view.dart';
import '../features/stats/stats_binding.dart';
import '../features/stats/stats_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.splash;

  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.game,
      page: () => const GameView(),
      binding: GameBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.categories,
      page: () => const CategoriesView(),
      binding: CategoriesBinding(),
    ),
    GetPage(
      name: Routes.result,
      page: () => const ResultView(),
      binding: ResultBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.stats,
      page: () => const StatsView(),
      binding: StatsBinding(),
    ),
    GetPage(name: Routes.settings, page: () => const SettingsView()),
    GetPage(
      name: Routes.battle,
      page: () => const BattleHubView(),
      binding: BattleBinding(),
    ),
    GetPage(
      name: Routes.battleRoom,
      page: () => const BattleRoomView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.battleResult,
      page: () => const BattleResultView(),
      transition: Transition.fadeIn,
    ),
  ];
}
