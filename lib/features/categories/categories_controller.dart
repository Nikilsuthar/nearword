import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/category.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';

/// View-model for one category card.
class CategoryItem {
  const CategoryItem({
    required this.category,
    required this.solved,
    required this.total,
    required this.locked,
  });

  final Category category;
  final int solved;
  final int total;
  final bool locked;
}

class CategoriesController extends GetxController {
  final _repo = Get.find<PuzzleRepository>();
  final _stats = Get.find<StatsRepository>();
  final _storage = Get.find<StorageService>();
  final _ads = Get.find<AdService>();

  final RxList<CategoryItem> items = <CategoryItem>[].obs;
  RxInt get coins => _stats.coins;

  int get unlockCost => AppConstants.premiumCategoryCost;

  @override
  void onInit() {
    super.onInit();
    _rebuild();
    // Refresh whenever a game is saved/finished or coins are spent.
    ever(_storage.revision, (_) => _rebuild());
  }

  void _rebuild() {
    final done = _storage.finishedPuzzleIds(winsOnly: true);
    items.assignAll([
      for (final c in _repo.categories)
        CategoryItem(
          category: c,
          solved: done.where((id) => id.startsWith('cat-${c.id}-')).length,
          total: _repo.sizeOf(c.id),
          locked: !_stats.isCategoryUnlocked(c),
        ),
    ]);
  }

  bool canAffordUnlock() => _stats.coins.value >= unlockCost;

  /// Spends coins to unlock; returns whether it worked.
  bool unlock(CategoryItem item) {
    final ok = _stats.unlockCategory(item.category);
    _rebuild(); // refresh immediately, not after the disk write
    return ok;
  }

  RxBool get rewardedReady => _ads.rewardedReady;

  /// Rewarded ad -> unlock the category for 24 hours. Returns success.
  Future<bool> unlockForDay(CategoryItem item) async {
    final earned = await _ads.showRewarded();
    if (earned) {
      _stats.unlockCategoryTemporarily(item.category);
      _rebuild();
    }
    return earned;
  }

  void play(CategoryItem item) {
    Get.toNamed(
      Routes.game,
      arguments: _repo.randomCategoryId(item.category.id),
    );
  }
}
