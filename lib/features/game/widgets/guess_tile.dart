import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/guess.dart';

/// Fraction of the bar to fill: rank 1 is full, far ranks are nearly empty
/// (logarithmic so close ranks stay distinguishable).
double rankFill(int rank) {
  if (rank <= 1) return 1;
  final f = 1 - log(rank) / log(AppConstants.barMaxRank);
  return f.clamp(0.04, 1.0);
}

/// One row of the guess list: word, rank and a colour-coded bar that animates
/// in when the row is first built.
class GuessTile extends StatelessWidget {
  const GuessTile({
    super.key,
    required this.guess,
    this.highlighted = false,
  });

  final Guess guess;
  final bool highlighted;

  /// Kept for the unit tests / other callers.
  static double fillFor(int rank) => rankFill(rank);

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forRank(guess.rank);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${guess.word}, rank ${guess.rank}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? scheme.primary : scheme.outline,
            width: highlighted ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 48,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: rankFill(guess.rank)),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.35),
                              color.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          guess.word,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${guess.rank}',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
