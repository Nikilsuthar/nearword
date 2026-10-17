import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/seeded.dart';
import '../../../data/models/guess.dart';

/// Visualises every guess as a dot: the closer the meaning, the nearer the
/// centre (where the secret word sits). Tap a dot to read it.
class RadarView extends StatefulWidget {
  const RadarView({super.key, required this.guesses, this.latestWord});

  final List<Guess> guesses;
  final String? latestWord;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  String? _selected;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static double _radiusFraction(int rank) {
    if (rank <= 1) return 0;
    return (log(rank) / log(AppConstants.barMaxRank)).clamp(0.04, 0.97);
  }

  static double angleFor(String word) =>
      (Seeded.hash(word) % 3600) / 3600 * 2 * pi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth, box.maxHeight);
        final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
        final radius = side / 2 - 18;

        Offset posOf(Guess g) =>
            center +
            Offset(cos(angleFor(g.word)), sin(angleFor(g.word))) *
                (radius * _radiusFraction(g.rank));

        return GestureDetector(
          onTapDown: (d) {
            String? hit;
            var best = 26.0;
            for (final g in widget.guesses) {
              final dist = (posOf(g) - d.localPosition).distance;
              if (dist < best) {
                best = dist;
                hit = g.word;
              }
            }
            setState(() => _selected = hit);
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _RadarPainter(
                guesses: widget.guesses,
                latestWord: widget.latestWord,
                selected: _selected,
                pulse: _pulse.value,
                radius: radius,
                ringColor: scheme.onSurface.withValues(alpha: 0.12),
                textColor: scheme.onSurface,
                bg: scheme.surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.guesses,
    required this.latestWord,
    required this.selected,
    required this.pulse,
    required this.radius,
    required this.ringColor,
    required this.textColor,
    required this.bg,
  });

  final List<Guess> guesses;
  final String? latestWord;
  final String? selected;
  final double pulse;
  final double radius;
  final Color ringColor;
  final Color textColor;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Zones: red outside, yellow, green inside.
    void zone(double fraction, Color color) {
      canvas.drawCircle(
        c,
        radius * fraction,
        Paint()..color = color.withValues(alpha: 0.07),
      );
      canvas.drawCircle(
        c,
        radius * fraction,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.35),
      );
    }

    zone(1, AppColors.red);
    zone(_RadarViewState._radiusFraction(AppConstants.yellowMaxRank),
        AppColors.yellow);
    zone(_RadarViewState._radiusFraction(AppConstants.greenMaxRank),
        AppColors.green);

    // Crosshair.
    final line = Paint()
      ..color = ringColor
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(c.dx - radius, c.dy), Offset(c.dx + radius, c.dy), line);
    canvas.drawLine(
        Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy + radius), line);

    // Target at the centre.
    final ping = Tween<double>(begin: 6, end: 26).transform(pulse);
    canvas.drawCircle(
      c,
      ping,
      Paint()..color = AppColors.gold.withValues(alpha: (1 - pulse) * 0.35),
    );
    canvas.drawCircle(c, 7, Paint()..color = AppColors.gold);
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = bg,
    );

    // Guess dots (worst first so the best are painted on top).
    final ordered = [...guesses]..sort((a, b) => b.rank.compareTo(a.rank));
    final shown = <Rect>[];
    for (final g in ordered) {
      final f = _RadarViewState._radiusFraction(g.rank);
      final a = _RadarViewState.angleFor(g.word);
      final p = c + Offset(cos(a), sin(a)) * (radius * f);
      final color = AppColors.forRank(g.rank);
      final isLatest = g.word == latestWord;
      final isSel = g.word == selected;
      if (isLatest) {
        canvas.drawCircle(
          p,
          10 + pulse * 10,
          Paint()..color = color.withValues(alpha: (1 - pulse) * 0.5),
        );
      }
      canvas.drawCircle(p, isLatest || isSel ? 8 : 6, Paint()..color = color);
      canvas.drawCircle(
        p,
        isLatest || isSel ? 8 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = bg,
      );

      // Label the closest few, the latest and the selected one.
      final label = isLatest || isSel || guesses.indexOf(g) < 4;
      if (label) {
        final tp = TextPainter(
          text: TextSpan(
            text: g.word,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        var at = p + Offset(-tp.width / 2, 10);
        at = Offset(
          at.dx.clamp(2, size.width - tp.width - 2),
          at.dy.clamp(2, size.height - tp.height - 2),
        );
        final rect = (at & tp.size).inflate(2);
        if (isLatest || isSel || !shown.any((r) => r.overlaps(rect))) {
          shown.add(rect);
          tp.paint(canvas, at);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
