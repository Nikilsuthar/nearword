import 'package:get/get.dart';

import '../../core/services/daily_board_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/puzzle.dart';
import '../../data/repositories/puzzle_repository.dart';

/// Daily leaderboard for one word style + level (defaults to the player's own
/// settings, can be switched to look at the other boards).
class BoardController extends GetxController {
  final _board = Get.find<DailyBoardService>();
  final _settings = Get.find<SettingsService>();
  final _repo = Get.find<PuzzleRepository>();

  late final Rx<WordSet> set = _settings.wordSet.value.obs;
  late final Rx<Difficulty> level = _settings.level.value.obs;

  final RxList<DailyEntry> entries = <DailyEntry>[].obs;
  final RxBool loading = false.obs;
  final RxBool failed = false.obs;
  final RxnInt myPlace = RxnInt();

  bool get enabled => _board.enabled;
  String get myId => _board.myId;
  String get today => DateHelper.dayKey(_repo.now);
  int get dailyNumber => _repo.dailyNumber(_repo.now);

  @override
  void onInit() {
    super.onInit();
    // Follow the game settings unless the player picked another board.
    ever(_settings.wordSet, (v) => set.value = v);
    ever(_settings.level, (v) => level.value = v);
    ever(set, (_) => reload());
    ever(level, (_) => reload());
  }

  /// Loads (or reloads) the board. Safe to call when the tab is opened.
  Future<void> reload() async {
    if (!enabled) return;
    loading.value = true;
    failed.value = false;
    try {
      final list = await _board.top(today, set.value, level.value);
      entries.assignAll(list);
      final i = list.indexWhere((e) => e.uid == myId);
      myPlace.value = i >= 0 ? i + 1 : null;
    } catch (_) {
      failed.value = true;
    } finally {
      loading.value = false;
    }
  }
}
