import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_background.dart';
import '../../../routes/app_routes.dart';
import '../battle_controller.dart';
import '../widgets/battle_widgets.dart';

/// Lobby: share the code, watch players arrive, host starts the round.
class BattleRoomView extends StatefulWidget {
  const BattleRoomView({super.key});

  @override
  State<BattleRoomView> createState() => _BattleRoomViewState();
}

class _BattleRoomViewState extends State<BattleRoomView> {
  final battle = Get.find<BattleController>();
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever<BattlePhase>(battle.phase, (p) {
      if (p == BattlePhase.playing) {
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
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Leave the room?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await battle.leave();
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Lobby'),
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
          final players = battle.livePlayers;
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
                  child: const Text('Connection problem… retrying.'),
                ),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Text(
                      battle.practice.value ? 'PRACTICE ROOM' : 'ROOM CODE',
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
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    if (!battle.practice.value) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: room.code));
                              Get.snackbar('Copied', 'Room code copied',
                                  snackPosition: SnackPosition.BOTTOM);
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy'),
                          ),
                          TextButton.icon(
                            onPressed: () => Share.share(
                              'Join my ${AppConstants.appName} battle! Open '
                              'Battle > Join and enter code ${room.code}',
                            ),
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: const Text('Invite'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Players', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${players.length}/${AppConstants.battleMaxPlayers} · '
                    '${room.durationSec ~/ 60} min',
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
                      color: p.id == battle.playerId
                          ? scheme.primary
                          : scheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatar(player: p),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.id == battle.playerId ? '${p.name} (you)' : p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      if (p.id == room.hostId)
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 22),
                      if (p.isBot)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.smart_toy_rounded, size: 20),
                        ),
                    ],
                  ),
                ).animate().fadeIn().slideX(begin: 0.1),
              const SizedBox(height: 20),
              Obx(() {
                final err = battle.error.value;
                return err == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(err,
                            style: const TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w700)),
                      );
              }),
              if (battle.isHost)
                FilledButton.icon(
                  onPressed: players.length >= 2 ? battle.start : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(players.length >= 2
                      ? 'Start battle'
                      : 'Waiting for players…'),
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
                    Text(
                      'Waiting for the host to start…',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
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
          const Text('Get ready!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
          const Text('Same secret word for everyone.'),
        ],
      ),
    );
  }
}
