import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/battle.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 36});

  final BattlePlayer player;
  final double size;

  @override
  Widget build(BuildContext context) => InitialAvatar(
        name: player.name,
        colorIndex: player.avatar,
        size: size,
      );
}

String placeLabel(int place) => switch (place) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$place',
    };

/// One row of the live leaderboard: place, avatar, name and how near they are.
class StandingRow extends StatelessWidget {
  const StandingRow({
    super.key,
    required this.place,
    required this.player,
    required this.isMe,
    this.payout,
  });

  final int place;
  final BattlePlayer player;
  final bool isMe;

  /// Coins this player received once the room is settled.
  final int? payout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rankColor = player.solved
        ? AppColors.gold
        : player.hasGuessed
            ? AppColors.forRank(player.bestRank)
            : scheme.onSurface.withValues(alpha: 0.4);
    final status = player.solved
        ? 'row_solved'.trParams({'n': '${player.guesses}'})
        : player.hasGuessed
            ? 'row_guesses'.trParams({'n': '${player.guesses}'})
            : 'row_none'.tr;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? scheme.primary.withValues(alpha: 0.14) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? scheme.primary : scheme.outline,
          width: isMe ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              placeLabel(place),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          PlayerAvatar(player: player),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe
                      ? 'row_you'.trParams({'name': player.name})
                      : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (payout != null && payout! > 0) ...[
            CoinText(payout!, size: 16),
            const SizedBox(width: 10),
          ],
          Text(
            player.solved
                ? '🎯'
                : player.hasGuessed
                    ? '#${player.bestRank}'
                    : '–',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: rankColor,
            ),
          ),
        ],
      ),
    );
  }
}
