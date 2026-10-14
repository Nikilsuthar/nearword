import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/daily_board_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/saved_game.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';
import '../battle/battle_controller.dart';
import 'widgets/how_to_play_sheet.dart';

enum DailyState { fresh, inProgress, solved, gaveUp }

/// Home shell: bottom tabs, today's puzzle, quick modes.
class HomeController extends GetxController {
  final _repo = Get.find<PuzzleRepository>();
  final _storage = Get.find<StorageService>();
  final _stats = Get.find<StatsRepository>();
  final settings = Get.find<SettingsService>();

  /// 0 Home, 1 Rank, 2 Friends, 3 Me.
  final RxInt tab = 0.obs;

  final Rxn<SavedGame> resumable = Rxn<SavedGame>();
  final Rx<DailyState> dailyState = DailyState.fresh.obs;
  final RxInt dailyGuesses = 0.obs;
  final RxInt dailyNumber = 1.obs;
  final RxString dailyId = ''.obs;

  /// Top players today (null = not loaded / online board off).
  final Rxn<List<DailyEntry>> boardPreview = Rxn<List<DailyEntry>>();

  RxInt get coins => _stats.coins;
  RxInt get streak => _stats.streak;
  StatsRepository get statsRepo => _stats;

  @override
  void onInit() {
    super.onInit();
    _refresh();
    ever(_storage.revision, (_) => _refresh());
    ever(settings.level, (_) {
      _refresh();
      loadBoardPreview();
    });
    ever(settings.wordSet, (_) {
      _refresh();
      loadBoardPreview();
    });
  }

  @override
  void onReady() {
    super.onReady();
    final bonus = _stats.claimDailyLogin();
    if (bonus > 0) {
      Get.snackbar(
        'daily_bonus'.tr,
        'daily_bonus_msg'.trParams({'n': '$bonus'}),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
    if (!settings.onboarded.value) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        HowToPlaySheet.show();
        settings.markOnboarded();
      });
    }
    _backgroundSync();
  }

  /// Signs in, sends results that could not be sent earlier, settles rooms
  /// that finished while the app was closed and loads the board preview.
  Future<void> _backgroundSync() async {
    try {
      if (Get.isRegistered<FirebaseAuthService>()) {
        await Get.find<FirebaseAuthService>().signIn();
      }
      if (Get.isRegistered<DailyBoardService>()) {
        await Get.find<DailyBoardService>().flushPending();
      }
      if (Get.isRegistered<BattleController>()) {
        await Get.find<BattleController>().reconcile();
      }
    } catch (_) {}
    await loadBoardPreview();
  }

  void _refresh() {
    resumable.value = _storage.latestUnfinished();
    // Streak can lapse at midnight even without new data.
    _stats.streak.value = _stats.displayStreak;
    dailyNumber.value = _repo.dailyNumber(_repo.now);
    final id = _repo.todaysDailyId(settings.wordSet.value, settings.level.value);
    dailyId.value = id;
    final saved = _storage.loadGame(id);
    dailyGuesses.value = saved?.guesses.length ?? 0;
    dailyState.value = switch (saved?.status) {
      GameStatus.won => DailyState.solved,
      GameStatus.gaveUp => DailyState.gaveUp,
      GameStatus.playing =>
        (saved!.guesses.isEmpty ? DailyState.fresh : DailyState.inProgress),
      null => DailyState.fresh,
    };
  }

  Future<void> loadBoardPreview() async {
    if (!Get.isRegistered<DailyBoardService>()) return;
    final board = Get.find<DailyBoardService>();
    if (!board.enabled) {
      boardPreview.value = null;
      return;
    }
    try {
      final list = await board.top(
        _repo.todaysDailyId(settings.wordSet.value, settings.level.value).substring(6, 16),
        settings.wordSet.value,
        settings.level.value,
        limit: 3,
      );
      boardPreview.value = list;
    } catch (_) {
      boardPreview.value = null;
    }
  }

  void playDaily() => Get.toNamed(Routes.game, arguments: dailyId.value);

  void playRandom() => Get.toNamed(
        Routes.game,
        arguments: _repo.randomId(settings.wordSet.value, settings.level.value),
      );

  void resume() {
    final r = resumable.value;
    if (r != null) Get.toNamed(Routes.game, arguments: r.puzzleId);
  }

  void openCategories() => Get.toNamed(Routes.categories);
  void openSettings() => Get.toNamed(Routes.settings);
  void showHowToPlay() => HowToPlaySheet.show();
}
