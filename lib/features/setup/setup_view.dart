import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/settings_service.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/puzzle.dart';
import '../../routes/app_routes.dart';

/// Shown once, before the first game: language, word style, level, nickname.
/// Everything can be changed later in Settings.
class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final settings = Get.find<SettingsService>();
  late final TextEditingController _name =
      TextEditingController(text: settings.nickname.value);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    settings.setNickname(_name.text);
    settings.completeSetup();
    Get.offAllNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _start,
              child: Text('setup_start'.tr),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          const Center(child: LogoMark(size: 64)),
          const SizedBox(height: 14),
          Text(
            'setup_title'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'setup_sub'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),

          SectionTitle('setup_language'.tr),
          Obx(
            () => ChoiceCards<String>(
              selected: settings.language.value,
              onChanged: settings.setLanguage,
              options: [
                ChoiceOption('en', 'language_en'.tr, icon: Icons.translate_rounded),
                ChoiceOption('hi', 'language_hi'.tr, icon: Icons.translate_rounded),
              ],
            ),
          ),

          SectionTitle('setup_style'.tr),
          Obx(
            () => ChoiceCards<WordSet>(
              vertical: true,
              selected: settings.wordSet.value,
              onChanged: settings.setWordSet,
              options: [
                ChoiceOption(
                  WordSet.regular,
                  'style_regular'.tr,
                  subtitle: 'style_regular_sub'.tr,
                  icon: Icons.menu_book_rounded,
                ),
                ChoiceOption(
                  WordSet.india,
                  'style_india'.tr,
                  subtitle: 'style_india_sub'.tr,
                  icon: Icons.temple_hindu_rounded,
                ),
              ],
            ),
          ),

          SectionTitle('setup_level'.tr),
          Obx(
            () => ChoiceCards<Difficulty>(
              vertical: true,
              selected: settings.level.value,
              onChanged: settings.setLevel,
              options: [
                ChoiceOption(
                  Difficulty.easy,
                  'level_easy'.tr,
                  subtitle: 'level_easy_sub'.tr,
                  icon: Icons.sentiment_satisfied_alt_rounded,
                ),
                ChoiceOption(
                  Difficulty.medium,
                  'level_medium'.tr,
                  subtitle: 'level_medium_sub'.tr,
                  icon: Icons.psychology_alt_rounded,
                ),
                ChoiceOption(
                  Difficulty.hard,
                  'level_hard'.tr,
                  subtitle: 'level_hard_sub'.tr,
                  icon: Icons.local_fire_department_rounded,
                ),
              ],
            ),
          ),

          SectionTitle('setup_name'.tr),
          TextField(
            controller: _name,
            maxLength: 14,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'setup_name_hint'.tr,
              counterText: '',
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
