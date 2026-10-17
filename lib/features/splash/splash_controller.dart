import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/ads.dart';
import '../../core/services/sfx.dart';
import '../../core/services/daily_board_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/semantic_engine.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';
import '../battle/battle_controller.dart';

/// Initializes long-lived services, then moves on to Setup (first launch) or
/// Home.
class SplashController extends GetxController {
  /// Translation key of the start-up problem (null = none).
  final RxnString error = RxnString();
  final RxnString detail = RxnString();

  @override
  void onReady() {
    super.onReady();
    _boot();
  }

  Future<void> _boot() async {
    try {
      error.value = null;
      final started = DateTime.now();
      final storage = await Get.putAsync(
        () => StorageService().init(),
        permanent: true,
      );
      final settings =
          Get.put(SettingsService(storage).init(), permanent: true);
      Get.updateLocale(Locale(settings.language.value));
      Get.changeThemeMode(settings.themeMode.value);

      final engine = await Get.putAsync(
        () => SemanticEngine().init(),
        permanent: true,
      );
      final repo = Get.put(
        PuzzleRepository(engine, recentSecrets: storage.recentSecrets),
        permanent: true,
      );
      final stats = Get.put(StatsRepository(storage).init(), permanent: true);
      final auth =
          Get.put(FirebaseAuthService(storage).init(), permanent: true);
      Get.put(DailyBoardService(storage, settings, auth: auth),
          permanent: true);
      Get.put(
        BattleController(
          settings: settings,
          storage: storage,
          stats: stats,
          repository: repo,
          auth: auth,
        ),
        permanent: true,
      );

      // Consent + ad SDK (safe_ads). Failures never block the game.
      await Ads.init(storage);

      // Keep the logo on screen long enough to be seen.
      final spent = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1400);
      if (spent < minimum) await Future<void>.delayed(minimum - spent);
      Sfx.startMusic();
      Get.offAllNamed(settings.setupDone.value ? Routes.home : Routes.setup);
    } catch (e) {
      error.value = 'start_error';
      detail.value = '$e';
    }
  }

  void retry() => _boot();
}
