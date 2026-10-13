import 'package:get/get.dart';

import '../../core/services/ad_service.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/semantic_engine.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';

/// Initializes long-lived services, then moves on to Home.
class SplashController extends GetxController {
  final RxnString error = RxnString();

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
      final settings = Get.put(SettingsService(storage).init(), permanent: true);
      Get.changeThemeMode(settings.themeMode.value);

      final engine = await Get.putAsync(
        () => SemanticEngine().init(),
        permanent: true,
      );
      Get.put(PuzzleRepository(engine), permanent: true);
      Get.put(StatsRepository(storage).init(), permanent: true);

      // GDPR/UMP consent first, then initialize ads. Failures never block the
      // game: without consent the app simply runs ad-free.
      final canRequestAds = await ConsentService().gatherConsent();
      await Get.putAsync(
        () => AdService(storage).init(canRequestAds: canRequestAds),
        permanent: true,
      );

      // Keep the logo on screen long enough to be seen.
      final spent = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1400);
      if (spent < minimum) await Future<void>.delayed(minimum - spent);
      Get.offAllNamed(Routes.home);
    } catch (e) {
      error.value = 'Could not start the game. Please try again.\n($e)';
    }
  }

  void retry() => _boot();
}
