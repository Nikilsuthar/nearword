import 'package:get/get.dart';

import 'battle_controller.dart';

class BattleBinding extends Bindings {
  @override
  void dependencies() {
    // Lives as long as the Battle hub route (room, game and result stack on
    // top of it), so the whole flow shares one controller.
    if (!Get.isRegistered<BattleController>()) Get.put(BattleController());
  }
}
