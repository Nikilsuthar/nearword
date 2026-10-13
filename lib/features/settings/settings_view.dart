import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/app_background.dart';
import '../home/widgets/how_to_play_sheet.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsService>();
    final scheme = Theme.of(context).colorScheme;
    final nick = TextEditingController(text: s.nickname.value);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        );

    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          section('Profile'),
          SoftCard(
            child: TextField(
              controller: nick,
              maxLength: 14,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nickname (shown in battles)',
                counterText: '',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              onChanged: s.setNickname,
            ),
          ),
          section('Appearance'),
          SoftCard(
            child: Obx(
              () => SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.phone_android_rounded),
                    label: Text('Auto'),
                  ),
                ],
                selected: {s.themeMode.value},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Obx(
              () => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Haptic feedback',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Vibrate on guesses and wins'),
                value: s.haptics.value,
                onChanged: s.setHaptics,
              ),
            ),
          ),
          section('Help'),
          SoftCard(
            onTap: HowToPlaySheet.show,
            child: const Row(
              children: [
                Icon(Icons.help_outline_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text('How to play',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          FutureBuilder<bool>(
            future: ConsentService().privacyOptionsRequired,
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SoftCard(
                  onTap: ConsentService().showPrivacyOptions,
                  child: const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Privacy & ad choices',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${AppConstants.appName} · ${AppConstants.tagline}\n'
              'Word similarity powered by GloVe embeddings.',
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
}
