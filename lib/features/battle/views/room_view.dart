import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_background.dart';
import '../../../data/models/battle.dart';
import '../../../routes/app_routes.dart';
import '../battle_controller.dart';
import '../widgets/battle_widgets.dart';

/// A room: live-battle lobby / countdown, or a challenge's waiting area.
class RoomView extends StatefulWidget {
  const RoomView({super.key});

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  final battle = Get.find<BattleController>();
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever<BattlePhase>(battle.phase, (p) {
      if (p == BattlePhase.playing && !battle.isChallenge) {
        Get.offNamed(Routes.game, arguments: battle.puzzleId);
      } else if (p == BattlePhase.idle && battle.error.value != null) {
        Get.back<void>();
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (battle.isChallenge) {
      // A challenge keeps running; just go back to the tabs.
      Get.back<void>();
      return;
    }
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('leave_room_title'.tr),
        content: Text('leave_room_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('stay'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('leave'.tr),
          ),
        ],
      ),
    );
    if (ok == true) {
      await battle.leave();
      Get.back<void>();
    }
  }

  void _playChallenge() {
    battle.beginPlaying();
    Get.toNamed(Routes.game, arguments: battle.puzzleId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AppScaffold(
        appBar: AppBar(
          title: Obx(
            () => Text(
              battle.isChallenge ? 'challenge_title'.tr : 'lobby'.tr,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
        ),
        body: Obx(() {
          final room = battle.room.value;
          if (room == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (battle.phase.value == BattlePhase.countdown) {
            return _Countdown(seconds: battle.countdown.value);
          }
          return _RoomBody(
            battle: battle,
            room: room,
            onPlayChallenge: _playChallenge,
          );
        }),
      ),
    );
  }
}

class _RoomBody extends StatelessWidget {
  const _RoomBody({
    required this.battle,
    required this.room,
    required this.onPlayChallenge,
  });

  final BattleController battle;
  final BattleRoom room;
  final VoidCallback onPlayChallenge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final challenge = room.isChallenge;
    final finished = room.status == RoomStatus.finished;
    final players = challenge ? battle.standings : battle.livePlayers;
    final me = battle.me;
    final iAmDone = me?.done ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (battle.connectionLost.value)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('connection_problem'.tr),
          ),

        // --- Code card -----------------------------------------------------
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            children: [
              Text(
                battle.practice.value ? 'practice_room'.tr : 'room_code'.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                room.code,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Tag(styleLevelLabel(room.wordSet, room.level)),
                  _Tag(durationLabel(room.durationSec)),
                  if (room.stake > 0)
                    _Tag(
                      'room_stake_line'.trParams({
                        'n': '${room.stake}',
                        'p': '${room.stake * (room.roster.isEmpty ? room.players.length : room.roster.length)}',
                      }),
                      color: AppColors.gold,
                    ),
                ],
              ),
              if (!battle.practice.value) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        Get.snackbar(
                          'copied'.tr,
                          'code_copied'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text('copy'.tr),
                    ),
                    TextButton.icon(
                      onPressed: () => Share.share(
                        challenge
                            ? 'challenge_share'.trParams({
                                'c': room.code,
                                's': styleLabel(room.wordSet),
                                'l': levelLabel(room.level),
                                'n': '${room.stake}',
                              })
                            : 'room_share'.trParams({'c': room.code}),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text('invite'.tr),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // --- Challenge timer -----------------------------------------------------
        if (challenge) ...[
          const SizedBox(height: 12),
          SoftCard(
            child: Row(
              children: [
                Icon(
                  finished ? Icons.flag_rounded : Icons.timer_rounded,
                  color: finished ? AppColors.green : AppColors.saffron,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finished ? 'challenge_closed'.tr : 'time_left'.tr,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Obx(
                        () => Text(
                          finished
                              ? '—'
                              : clockLabel((battle.remainingMs.value / 1000).ceil()),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        Row(
          children: [
            Text('players'.tr, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${players.length}/${AppConstants.battleMaxPlayers}',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in players)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: p.id == battle.playerId ? scheme.primary : scheme.outline,
              ),
            ),
            child: Row(
              children: [
                PlayerAvatar(player: p),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.id == battle.playerId
                            ? 'row_you'.trParams({'name': p.name})
                            : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (challenge)
                        Text(
                          p.solved
                              ? 'row_solved'.trParams({'n': '${p.guesses}'})
                              : p.hasGuessed
                                  ? 'row_guesses'.trParams({'n': '${p.guesses}'})
                                  : 'row_none'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (p.id == room.hostId)
                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 22),
                if (p.isBot)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.smart_toy_rounded, size: 20),
                  ),
              ],
            ),
          ).animate().fadeIn().slideX(begin: 0.08),

        const SizedBox(height: 18),
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

        // --- Actions ----------------------------------------------------------------
        if (challenge) ...[
          if (finished)
            FilledButton(
              onPressed: () => Get.toNamed(Routes.roomResult),
              child: Text('final_ranking'.tr),
            )
          else ...[
            FilledButton.icon(
              onPressed: iAmDone ? null : onPlayChallenge,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('play_now'.tr),
            ),
            const SizedBox(height: 8),
            Text(
              'play_again_note'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (iAmDone)
              TextButton(
                onPressed: () => Get.toNamed(Routes.roomResult),
                child: Text('live_ranking'.tr),
              ),
            if (battle.isHost)
              TextButton(
                onPressed: battle.endChallengeNow,
                child: Text('end_now'.tr),
              ),
          ],
        ] else if (battle.isHost)
          FilledButton.icon(
            onPressed: players.length >= 2 ? battle.start : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              players.length >= 2 ? 'start_battle'.tr : 'waiting_players'.tr,
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'waiting_host'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'get_ready'.tr,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '$seconds',
            key: ValueKey(seconds),
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.w900,
              color: AppColors.brandSoft,
            ),
          ).animate().scale(
                begin: const Offset(1.6, 1.6),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),
          Text('same_word_all'.tr),
        ],
      ),
    );
  }
}
