import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/backend_config.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/puzzle.dart';
import '../../data/repositories/stats_repository.dart';
import '../../routes/app_routes.dart';
import '../../data/models/battle.dart';
import 'battle_controller.dart';

/// Live battles + challenges with friends (and practice vs bots).
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final battle = Get.find<BattleController>();
  final settings = Get.find<SettingsService>();
  final stats = Get.find<StatsRepository>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool _needNickname() {
    if (settings.nickname.value.trim().isEmpty) {
      battle.error.value = 'err_nickname';
      return true;
    }
    return false;
  }

  Future<void> _join() async {
    if (_needNickname()) return;
    if (!BackendConfig.online) {
      battle.error.value = 'online_needed';
      return;
    }
    if (await battle.joinRoom(_code.text)) Get.toNamed(Routes.room);
  }

  Future<void> _practice() async {
    if (_needNickname()) return;
    if (await battle.createRoom(practiceMode: true)) Get.toNamed(Routes.room);
  }

  Future<void> _openCreate(RoomKind kind) async {
    if (_needNickname()) return;
    if (!BackendConfig.online) {
      battle.error.value = 'online_needed';
      return;
    }
    final created = await Get.bottomSheet<bool>(
      CreateRoomSheet(kind: kind),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
    if (created == true) Get.toNamed(Routes.room);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text('friends_title'.tr,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),

        // Nickname needed for rooms.
        Obx(() {
          if (settings.nickname.value.trim().isNotEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              maxLength: 14,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'setup_name'.tr,
                hintText: 'setup_name_hint'.tr,
                counterText: '',
                prefixIcon: const Icon(Icons.person_rounded),
              ),
              onChanged: settings.setNickname,
            ),
          );
        }),

        Obx(() {
          final key = battle.error.value;
          if (key == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              borderColor: AppColors.red,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      key.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (key == 'online_needed')
                    TextButton(
                      onPressed: () => Get.toNamed(Routes.settings),
                      child: Text('online_needed_cta'.tr),
                    ),
                ],
              ),
            ),
          );
        }),

        // --- Live battle --------------------------------------------------
        _FeatureCard(
          colors: AppColors.battleGradient,
          icon: Icons.bolt_rounded,
          title: 'battle_title'.tr,
          body: 'battle_desc'.tr,
          primaryLabel: 'create_room'.tr,
          onPrimary: () => _openCreate(RoomKind.live),
        ),
        const SizedBox(height: 12),

        // --- Challenge --------------------------------------------------------
        _FeatureCard(
          colors: AppColors.challengeGradient,
          icon: Icons.flag_circle_rounded,
          title: 'challenge_title'.tr,
          body: 'challenge_desc'.tr,
          primaryLabel: 'create_challenge'.tr,
          onPrimary: () => _openCreate(RoomKind.challenge),
        ),

        // --- Join with a code ---------------------------------------------------
        SectionTitle('join_with_code'.tr),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'room_code'.tr,
                  counterText: '',
                ),
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: 10),
            Obx(
              () => SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: battle.busy.value ? null : _join,
                  child: Text('join'.tr),
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
              child: Text(
                'or_offline'.tr,
                style:
                    TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
            Expanded(child: Divider(color: scheme.outline)),
          ],
        ),
        const SizedBox(height: 14),
        Obx(
          () => OutlinedButton.icon(
            onPressed: battle.busy.value ? null : _practice,
            icon: const Icon(Icons.smart_toy_rounded),
            label: Text('practice_bots'.tr),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final List<Color> colors;
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return GradientPanel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.last,
            ),
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to create a live room or a challenge: level, word style, timer
/// and the coins each player puts in.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, required this.kind});

  final RoomKind kind;

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final battle = Get.find<BattleController>();
  final settings = Get.find<SettingsService>();
  final stats = Get.find<StatsRepository>();

  late Difficulty level = settings.level.value;
  late WordSet style = settings.wordSet.value;
  late int stake = 0;
  late int seconds = widget.kind == RoomKind.live
      ? AppConstants.battleDurations[1]
      : AppConstants.challengeWindows[1];

  bool get live => widget.kind == RoomKind.live;

  Future<void> _create() async {
    final ok = live
        ? await battle.createRoom(
            practiceMode: false,
            durationSec: seconds,
            level: level,
            wordSet: style,
            stake: stake,
          )
        : await battle.createChallenge(
            windowSec: seconds,
            level: level,
            wordSet: style,
            stake: stake,
          );
    if (ok) Get.back<bool>(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durations =
        live ? AppConstants.battleDurations : AppConstants.challengeWindows;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              live ? 'battle_title'.tr : 'challenge_title'.tr,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SectionTitle('room_style'.tr),
            ChoiceCards<WordSet>(
              selected: style,
              onChanged: (v) => setState(() => style = v),
              options: [
                ChoiceOption(WordSet.regular, 'style_regular'.tr),
                ChoiceOption(WordSet.india, 'style_india'.tr),
              ],
            ),
            SectionTitle('room_level'.tr),
            ChoiceCards<Difficulty>(
              selected: level,
              onChanged: (v) => setState(() => level = v),
              options: [
                ChoiceOption(Difficulty.easy, 'level_easy'.tr),
                ChoiceOption(Difficulty.medium, 'level_medium'.tr),
                ChoiceOption(Difficulty.hard, 'level_hard'.tr),
              ],
            ),
            SectionTitle(live ? 'round_length'.tr : 'window_length'.tr),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in durations)
                  ChoiceChip(
                    label: Text(durationLabel(d)),
                    selected: seconds == d,
                    onSelected: (_) => setState(() => seconds = d),
                  ),
              ],
            ),
            SectionTitle(
              'stake_label'.tr,
              trailing: Obx(
                () => Text(
                  'your_coins'.trParams({'n': '${stats.coins.value}'}),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            Obx(() {
              final coins = stats.coins.value;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in AppConstants.stakeOptions)
                    ChoiceChip(
                      avatar: s == 0
                          ? null
                          : const Icon(Icons.monetization_on_rounded,
                              size: 16, color: AppColors.gold),
                      label: Text(s == 0 ? 'stake_free'.tr : '$s'),
                      selected: stake == s,
                      onSelected:
                          s > coins ? null : (_) => setState(() => stake = s),
                    ),
                ],
              );
            }),
            if (stake > 0) ...[
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'pot_rules_title'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'pot_rules'.tr,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Obx(() {
              final key = battle.error.value;
              return key == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        key.tr,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
            }),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: battle.busy.value ? null : _create,
                  child: battle.busy.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(live ? 'create_room'.tr : 'create_challenge'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
