import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Horizontal bar chart of wins per guess-count bucket.
class DistributionChart extends StatelessWidget {
  const DistributionChart({super.key, required this.data});

  final List<MapEntry<String, int>> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final e in data)
          Semantics(
            label: '${e.key} guesses: ${e.value} wins',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(e.key, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final fraction =
                            maxValue == 0 ? 0.0 : e.value / maxValue;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            height: 22,
                            width: (c.maxWidth * fraction).clamp(
                              e.value > 0 ? 28.0 : 4.0,
                              c.maxWidth,
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: e.value > 0
                                  ? AppColors.green
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: e.value > 0
                                ? Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
