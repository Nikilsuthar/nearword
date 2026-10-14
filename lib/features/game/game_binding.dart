import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../battle/battle_controller.dart';
import '../hints/hints_controller.dart';
import 'game_controller.dart';

class GameBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments as String;
    final isRoom = id.startsWith('battle-') || id.startsWith('chal-');
    final battle = isRoom && Get.isRegistered<BattleController>()
        ? Get.find<BattleController>()
        : null;
    Get.lazyPut(
      () => GameController(
        initialPuzzleId: id,
        battle: battle,
        // Replace the game route so Back from Result returns to Home/Categories.
        onFinished: (result) => Get.offNamed(
          battle != null ? Routes.roomResult : Routes.result,
          arguments: result,
        ),
      ),
    );
    // Eager (not lazy): a lazily created controller would be bound to the
    // hint bottom sheet's route and deleted when the sheet closes.
    Get.put(HintsController());
  }
}
