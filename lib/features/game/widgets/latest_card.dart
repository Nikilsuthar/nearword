import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/guess.dart';
import 'guess_tile.dart';

/// Big "latest guess" card with a temperature read-out and proximity meter.
class LatestCard extends StatelessWidget {
  const LatestCard({super.key, required this.guess});

  final Guess? guess;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = guess;
    if (g == null) {
      return Container(
        key: const ValueKey('empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            const Text('🧭', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Type any word. The lower its rank, the closer it is to the '
                'secret word in meaning.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final color = AppColors.forRank(g.rank);
    final (label, emoji) = AppColors.temperature(g.rank);
    return Container(
      key: ValueKey('latest-${g.word}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            scheme.surface,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  g.word,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Text(
                '#${g.rank}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('bar-${g.word}'),
              tween: Tween(begin: 0, end: rankFill(g.rank)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: color,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey('anim-${g.word}')).fadeIn(duration: 220.ms).scale(
          begin: const Offset(0.97, 0.97),
          curve: Curves.easeOutBack,
          duration: 320.ms,
        );
  }
}
