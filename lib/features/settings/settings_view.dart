import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:safe_ads/safe_ads.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/backend_config.dart';
import '../../core/services/ads.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/puzzle.dart';
import '../home/widgets/how_to_play_sheet.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final s = Get.find<SettingsService>();
  late final TextEditingController _nick =
      TextEditingController(text: s.nickname.value);

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(title: Text('settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          _section(context, 'set_profile'.tr),
          SoftCard(
            child: TextField(
              controller: _nick,
              maxLength: 14,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'set_nickname'.tr,
                counterText: '',
                prefixIcon: const Icon(Icons.person_rounded),
              ),
              onChanged: s.setNickname,
            ),
          ),

          _section(context, 'set_game'.tr),
          Text(
            'set_style'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Obx(
            () => ChoiceCards<WordSet>(
              vertical: true,
              selected: s.wordSet.value,
              onChanged: s.setWordSet,
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
          const SizedBox(height: 16),
          Text(
            'set_level'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Obx(
            () => ChoiceCards<Difficulty>(
              vertical: true,
              selected: s.level.value,
              onChanged: s.setLevel,
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
          const SizedBox(height: 8),
          Text(
            'set_changes_apply'.tr,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'set_language'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Obx(
            () => ChoiceCards<String>(
              selected: s.language.value,
              onChanged: s.setLanguage,
              options: [
                ChoiceOption('en', 'language_en'.tr),
                ChoiceOption('hi', 'language_hi'.tr),
              ],
            ),
          ),

          _section(context, 'set_appearance'.tr),
          Obx(
            () => ChoiceCards<ThemeMode>(
              selected: s.themeMode.value,
              onChanged: s.setThemeMode,
              options: [
                ChoiceOption(ThemeMode.dark, 'theme_dark'.tr,
                    icon: Icons.dark_mode_rounded),
                ChoiceOption(ThemeMode.light, 'theme_light'.tr,
                    icon: Icons.light_mode_rounded),
                ChoiceOption(ThemeMode.system, 'theme_auto'.tr,
                    icon: Icons.phone_android_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Obx(
              () => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  'haptics'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('haptics_sub'.tr),
                value: s.haptics.value,
                onChanged: s.setHaptics,
              ),
            ),
          ),

          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Obx(
              () => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  'sound_fx'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('sound_fx_sub'.tr),
                value: s.sound.value,
                onChanged: s.setSound,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Obx(
              () => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  'music_bg'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('music_bg_sub'.tr),
                value: s.music.value,
                onChanged: s.setMusic,
              ),
            ),
          ),

          // Only developer builds (no baked-in server) can edit the server URL.
          if (BackendConfig.defaultUrl.trim().isEmpty) ...[
            _section(context, 'set_online'.tr),
            _ServerCard(settings: s),
          ],

          _section(context, 'set_help'.tr),
          SoftCard(
            onTap: HowToPlaySheet.show,
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'how_to_play'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SoftCard(
              onTap: () => launchUrl(
                Uri.parse(AppConstants.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(
                children: [
                  const Icon(Icons.policy_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'privacy_policy'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (Ads.privacyOptionsAvailable)
            ValueListenableBuilder<bool>(
              valueListenable: SafeAds.privacyOptionsRequired,
              builder: (context, required, _) {
                if (!required) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SoftCard(
                    onTap: SafeAds.showPrivacyOptions,
                    child: Row(
                      children: [
                        const Icon(Icons.privacy_tip_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'privacy_ads'.tr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${AppConstants.appName} · ${'app_tagline'.tr}\n'
              '${'about_line'.tr}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
}

class _ServerCard extends StatefulWidget {
  const _ServerCard({required this.settings});

  final SettingsService settings;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  late final TextEditingController _url = TextEditingController(
    text: widget.settings.backendUrl.value.isNotEmpty
        ? widget.settings.backendUrl.value
        : BackendConfig.databaseUrl,
  );
  String? _message; // translation key
  bool _ok = false;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final err = widget.settings.setBackendUrl(_url.text);
    setState(() {
      _ok = err == null;
      _message = err ??
          (widget.settings.backendUrl.value.isEmpty
              ? 'db_removed'
              : 'db_saved');
      if (err == null) _url.text = widget.settings.backendUrl.value;
    });
  }

  Future<void> _test() async {
    _save();
    if (!_ok) return;
    setState(() => _busy = true);
    final key = await widget.settings.testBackend();
    // Also try signing in so the status is truthful.
    if (key == 'db_connected' && Get.isRegistered<FirebaseAuthService>()) {
      await Get.find<FirebaseAuthService>().signIn();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = key == 'db_connected';
      _message = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'set_online_help'.tr,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'db_url'.tr,
              hintText: 'https://xxxx-default-rtdb.firebaseio.com',
              prefixIcon: const Icon(Icons.cloud_rounded),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _save,
                  child: Text('save'.tr),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _test,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text('test'.tr),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!.tr,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _ok ? AppColors.green : AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
