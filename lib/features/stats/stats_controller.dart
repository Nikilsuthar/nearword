import 'package:get/get.dart';

import '../../core/services/storage_service.dart';
import '../../data/models/achievement.dart';
import '../../data/models/player_stats.dart';
import '../../data/repositories/stats_repository.dart';

class StatsController extends GetxController {
  final _repo = Get.find<StatsRepository>();
  final _storage = Get.find<StorageService>();

  /// Reading [StorageService.revision] makes Obx widgets rebuild on changes.
  PlayerStats get stats {
    _storage.revision.value;
    return _repo.stats;
  }

  int get currentStreak {
    _storage.revision.value;
    return _repo.displayStreak;
  }

  List<Achievement> get achievements => AchievementCatalog.all;

  bool isUnlocked(Achievement a) => stats.achievements.containsKey(a.id);

  /// (bucket label, win count) in display order.
  List<MapEntry<String, int>> get distribution => [
    for (final b in PlayerStats.buckets)
      MapEntry(b, stats.distribution[b] ?? 0),
  ];
}
