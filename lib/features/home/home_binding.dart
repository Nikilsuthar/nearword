import 'package:get/get.dart';

import '../board/board_controller.dart';
import '../stats/stats_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(BoardController());
    Get.put(StatsController());
  }
}
