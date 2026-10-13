import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/backend_config.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/app_background.dart';
import '../../../routes/app_routes.dart';
import '../battle_controller.dart';

class BattleHubView extends StatefulWidget {
  const BattleHubView({super.key});

  @override
  State<BattleHubView> createState() => _BattleHubViewState();
}

class _BattleHubViewState extends State<BattleHubView> {
  final battle = Get.find<BattleController>();
  final settings = Get.find<SettingsService>();
  late final TextEditingController _nick;
  final _code = TextEditingController();
  int _duration = 180;

  @override
  void initState() {
    super.initState();
    _nick = TextEditingController(text: settings.nickname.value);
    battle.error.value = null;
  }

  @override
  void dispose() {
    _nick.dispose();
    _code.dispose();
    super.dispose();
  }

  bool _ensureNickname() {
    if (_nick.text.trim().isEmpty) {
      battle.error.value = 'Choose a nickname first.';
      return false;
    }
    settings.setNickname(_nick.text);
    return true;
  }

  Future<void> _create({required bool practice}) async {
    if (!_ensureNickname()) return;
    if (!practice && !BackendConfig.online) {
      battle.error.value =
          'Online rooms need a Firebase database URL (see README). '
          'Try a practice battle meanwhile.';
      return;
    }
    if (await battle.createRoom(practiceMode: practice, durationSec: _duration)) {
      Get.toNamed(Routes.battleRoom);
    }
  }

  Future<void> _join() async {
    if (!_ensureNickname()) return;
    if (!BackendConfig.online) {
      battle.error.value =
          'Joining online rooms needs a Firebase database URL (see README).';
      return;
    }
    if (await battle.joinRoom(_code.text)) Get.toNamed(Routes.battleRoom);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppScaffold(
      appBar: AppBar(title: const Text('Battle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  AppColors.pink.withValues(alpha: 0.28),
                  AppColors.brand.withValues(alpha: 0.28),
                ],
              ),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Word battle', style: text.titleLarge),
                      const SizedBox(height: 2),
                      const Text(
                        'Everyone hunts the same secret word. A live '
                        'scoreboard shows who is nearest. First to find it '
                        'wins.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nick,
            maxLength: 14,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Your nickname',
              counterText: '',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Text('Round length', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final d in AppConstants.battleDurations)
                ButtonSegment(value: d, label: Text('${d ~/ 60} min')),
            ],
            selected: {_duration},
            onSelectionChanged: (v) => setState(() => _duration = v.first),
          ),
          const SizedBox(height: 18),
          Obx(() {
            final err = battle.error.value;
            if (err == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                err,
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          Obx(
            () => FilledButton.icon(
              onPressed: battle.busy.value ? null : () => _create(practice: false),
              icon: const Icon(Icons.add_circle_rounded),
              label: const Text('Create online room'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: AppConstants.battleCodeLength,
                  decoration: const InputDecoration(
                    hintText: 'ROOM CODE',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(width: 10),
              Obx(
                () => SizedBox(
                  height: 58,
                  child: FilledButton.tonal(
                    onPressed: battle.busy.value ? null : _join,
                    child: const Text('Join'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: scheme.outline)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or play offline',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55))),
              ),
              Expanded(child: Divider(color: scheme.outline)),
            ],
          ),
          const SizedBox(height: 14),
          Obx(
            () => OutlinedButton.icon(
              onPressed: battle.busy.value ? null : () => _create(practice: true),
              icon: const Icon(Icons.smart_toy_rounded),
              label: const Text('Practice vs bots'),
            ),
          ),
          if (!BackendConfig.online) ...[
            const SizedBox(height: 14),
            Text(
              'Online rooms are switched off until a Firebase Realtime '
              'Database URL is set in backend_config.dart.',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
