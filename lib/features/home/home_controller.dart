import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/seeded.dart';
import '../../data/models/saved_game.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';
import 'widgets/how_to_play_sheet.dart';

enum DailyState { fresh, inProgress, solved, gaveUp }

/// Home: daily puzzle, quick play, categories, battle, friend challenges.
class HomeController extends GetxController {
  final _repo = Get.find<PuzzleRepository>();
  final _storage = Get.find<StorageService>();
  final _stats = Get.find<StatsRepository>();
  final _settings = Get.find<SettingsService>();

  final Rxn<SavedGame> resumable = Rxn<SavedGame>();
  final Rx<DailyState> dailyState = DailyState.fresh.obs;
  final RxInt dailyGuesses = 0.obs;
  final RxInt dailyNumber = 1.obs;
  RxInt get coins => _stats.coins;
  RxInt get streak => _stats.streak;
  StatsRepository get statsRepo => _stats;

  String get dailyId => _repo.todaysDailyId;

  @override
  void onInit() {
    super.onInit();
    _refresh();
    ever(_storage.revision, (_) => _refresh());
  }

  @override
  void onReady() {
    super.onReady();
    final bonus = _stats.claimDailyLogin();
    if (bonus > 0) {
      Get.snackbar(
        'Daily bonus',
        '+$bonus coins for coming back today!',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
    if (!_settings.onboarded.value) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        HowToPlaySheet.show();
        _settings.markOnboarded();
      });
    }
  }

  void _refresh() {
    resumable.value = _storage.latestUnfinished();
    // Streak can lapse at midnight even without new data.
    _stats.streak.value = _stats.displayStreak;
    dailyNumber.value = _repo.dailyNumber(DateTime.now());
    final saved = _storage.loadGame(dailyId);
    dailyGuesses.value = saved?.guesses.length ?? 0;
    dailyState.value = switch (saved?.status) {
      GameStatus.won => DailyState.solved,
      GameStatus.gaveUp => DailyState.gaveUp,
      GameStatus.playing =>
        (saved!.guesses.isEmpty ? DailyState.fresh : DailyState.inProgress),
      null => DailyState.fresh,
    };
  }

  void playDaily() => Get.toNamed(Routes.game, arguments: dailyId);

  void playRandom() =>
      Get.toNamed(Routes.game, arguments: _repo.randomId());

  void resume() {
    final r = resumable.value;
    if (r != null) Get.toNamed(Routes.game, arguments: r.puzzleId);
  }

  void openCategories() => Get.toNamed(Routes.categories);
  void openStats() => Get.toNamed(Routes.stats);
  void openSettings() => Get.toNamed(Routes.settings);
  void openBattle() => Get.toNamed(Routes.battle);

  // --- Friend challenge -------------------------------------------------------

  /// Creates a puzzle code and opens the share sheet. The friend types the
  /// code in "Challenge a friend" and gets exactly the same secret word.
  Future<void> createChallenge() async {
    final id = _repo.randomId();
    final code = id.substring(4);
    await Share.share(
      '${AppConstants.appName} challenge! Can you find my secret word faster '
      'than me? Open the app > Challenge a friend > enter code $code',
    );
    Get.toNamed(Routes.game, arguments: id);
  }

  /// Puzzle id for a typed challenge code, or null when the code is invalid.
  String? challengeIdFor(String raw) {
    final code = Seeded.normalizeCode(raw);
    if (code.length != 6) return null;
    final id = 'rnd-$code';
    return _repo.puzzleById(id) == null ? null : id;
  }

  void openPuzzle(String id) => Get.toNamed(Routes.game, arguments: id);

  void showHowToPlay() => HowToPlaySheet.show();
}
