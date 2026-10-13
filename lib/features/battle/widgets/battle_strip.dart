import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../battle_controller.dart';
import 'battle_widgets.dart';

/// Compact live scoreboard shown above the guess list during a battle.
class BattleStrip extends StatelessWidget {
  const BattleStrip({super.key, required this.battle});

  final BattleController battle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final room = battle.room.value; // subscribe
      if (room == null) return const SizedBox.shrink();
      final order = battle.standings;
      return SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: order.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = order[i];
            final me = p.id == battle.playerId;
            final color = p.solved
                ? AppColors.gold
                : p.hasGuessed
                    ? AppColors.forRank(p.bestRank)
                    : scheme.onSurface.withValues(alpha: 0.4);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: me
                    ? scheme.primary.withValues(alpha: 0.16)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: me ? scheme.primary : scheme.outline,
                  width: me ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(placeLabel(i + 1),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 6),
                  PlayerAvatar(player: p, size: 30),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 70),
                        child: Text(
                          me ? 'You' : p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        p.solved
                            ? 'Solved 🎯'
                            : p.hasGuessed
                                ? '#${p.bestRank}'
                                : '–',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
