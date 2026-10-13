import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_background.dart';
import '../../../data/models/game_result.dart';
import '../../../routes/app_routes.dart';
import '../battle_controller.dart';
import '../widgets/battle_widgets.dart';

/// Live standings that turn into the final ranking when the round closes.
class BattleResultView extends StatelessWidget {
  const BattleResultView({super.key});

  Future<void> _backToLobby(BattleController battle) async {
    await battle.leave();
    Get.until((route) => route.settings.name == Routes.battle);
  }

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments as GameResult;
    final battle = Get.find<BattleController>();
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToLobby(battle);
      },
      child: AppScaffold(
        body: Obx(() {
          final finished = battle.phase.value == BattlePhase.over;
          final order = battle.standings;
          final place = battle.myPlace;
          final won = finished && place == 1 && order.length > 1;
          final headline = !finished
              ? 'Round in progress…'
              : won
                  ? 'You won the battle!'
                  : 'You finished ${placeLabel(place)}';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Center(
                child: Text(
                  won ? '🏆' : finished ? placeLabel(place) : '⏳',
                  style: const TextStyle(fontSize: 64),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'The word was  ${r.secretWord.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cyan,
                  letterSpacing: 1,
                ),
              ),
              if (r.coinsEarned > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '+${r.coinsEarned} coins',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    finished ? 'Final ranking' : 'Live ranking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (!finished)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (!finished)
                Text(
                  'Others are still guessing. The round ends when time runs '
                  'out or ${AppConstants.battleGraceSeconds}s after the first '
                  'solve.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              for (var i = 0; i < order.length; i++)
                StandingRow(
                  place: i + 1,
                  player: order[i],
                  isMe: order[i].id == battle.playerId,
                ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => Share.share(
                  '${AppConstants.appName} battle · '
                  '${finished ? placeLabel(place) : 'in progress'} · '
                  '${r.guessCount} guesses · '
                  '${order.map((p) => '${p.name}: ${p.solved ? '🎯' : p.hasGuessed ? '#${p.bestRank}' : '–'}').join('  ')}',
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _backToLobby(battle),
                child: const Text('Back to battle lobby'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
