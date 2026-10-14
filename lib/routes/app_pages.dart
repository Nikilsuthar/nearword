import 'package:get/get.dart';

import '../features/battle/views/room_result_view.dart';
import '../features/battle/views/room_view.dart';
import '../features/categories/categories_binding.dart';
import '../features/categories/categories_view.dart';
import '../features/game/game_binding.dart';
import '../features/game/game_view.dart';
import '../features/home/home_binding.dart';
import '../features/home/home_view.dart';
import '../features/result/result_binding.dart';
import '../features/result/result_view.dart';
import '../features/settings/settings_view.dart';
import '../features/setup/setup_view.dart';
import '../features/splash/splash_binding.dart';
import '../features/splash/splash_view.dart';
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
      name: Routes.setup,
      page: () => const SetupView(),
      transition: Transition.fadeIn,
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
    GetPage(name: Routes.settings, page: () => const SettingsView()),
    GetPage(
      name: Routes.room,
      page: () => const RoomView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.roomResult,
      page: () => const RoomResultView(),
      transition: Transition.fadeIn,
    ),
  ];
}
