import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../game_controller.dart';

/// Bottom input: auto-focused text field + submit button. Shakes when
/// [GameController.shakeTick] changes (duplicate / unknown word).
class GuessInput extends StatefulWidget {
  const GuessInput({super.key});

  @override
  State<GuessInput> createState() => _GuessInputState();
}

class _GuessInputState extends State<GuessInput>
    with SingleTickerProviderStateMixin {
  final GameController controller = Get.find<GameController>();

  /// Drives the shake. The text field itself is never rebuilt with a new key,
  /// because that would drop the keyboard connection (typing would stop after
  /// a wrong or duplicate word).
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever(controller.shakeTick, (_) {
      if (mounted) _shake.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    _shake.dispose();
    super.dispose();
  }

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
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
                math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value),
                0),
            child: child,
          ),
          child: Row(
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
                  decoration: InputDecoration(hintText: 'type_a_word'.tr),
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
          ),
        ),
      ],
    );
  }
}
