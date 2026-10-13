import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../game_controller.dart';

/// Bottom input: auto-focused text field + submit button. Shakes when
/// [GameController.shakeTick] changes (duplicate / unknown word).
class GuessInput extends GetView<GameController> {
  const GuessInput({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(() {
          final msg = controller.message.value;
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: msg == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          );
        }),
        Obx(() {
          final tick = controller.shakeTick.value;
          final field = Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.textController,
                  focusNode: controller.focusNode,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  onSubmitted: (_) => controller.submit(),
                  decoration: const InputDecoration(hintText: 'Type a word…'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: controller.submit,
                  child: const Icon(Icons.arrow_upward_rounded, size: 28),
                ),
              ),
            ],
          );
          // Re-keying restarts the shake animation on every tick.
          return field
              .animate(key: ValueKey(tick), autoPlay: tick > 0)
              .shakeX(amount: 8, duration: 350.ms);
        }),
      ],
    );
  }
}
