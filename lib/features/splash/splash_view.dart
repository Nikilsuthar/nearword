import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_background.dart';
import '../../core/widgets/logo.dart';
import 'splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: Obx(() {
          final err = controller.error.value;
          if (err != null) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(err.tr, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.retry,
                    child: Text('retry'.tr),
                  ),
                ],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 104)
                  .animate()
                  .scale(duration: 700.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 900.ms, color: Colors.white24),
              const SizedBox(height: 22),
              const Wordmark(fontSize: 40).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 8),
              Text(
                'app_tagline'.tr,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          );
        }),
      ),
    );
  }
}
