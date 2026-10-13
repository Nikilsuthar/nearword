import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/battle.dart';

const List<Color> kAvatarColors = [
  Color(0xFF7C5CFF),
  Color(0xFF22D3EE),
  Color(0xFFFF5CAA),
  Color(0xFF34E3A0),
  Color(0xFFFFC857),
  Color(0xFFFF8A5C),
  Color(0xFF5C9DFF),
  Color(0xFFB45CFF),
];

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 36});

  final BattlePlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = kAvatarColors[player.avatar % kAvatarColors.length];
    final initial =
        player.name.isEmpty ? '?' : player.name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
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
  });

  final int place;
  final BattlePlayer player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rankColor = player.solved
        ? AppColors.gold
        : player.hasGuessed
            ? AppColors.forRank(player.bestRank)
            : scheme.onSurface.withValues(alpha: 0.4);
    final status = player.solved
        ? 'Solved · ${player.guesses} guesses'
        : player.hasGuessed
            ? '${player.guesses} guesses'
            : 'No guesses yet';
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
                  isMe ? '${player.name} (you)' : player.name,
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
