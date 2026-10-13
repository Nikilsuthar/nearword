import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Concentric "proximity" rings with a bright target dot: the app's mark.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brand, Color(0xFF4A2FD6)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r * 0.58)),
      bg,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        r * (0.30 + i * 0.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..color = Colors.white.withValues(alpha: 0.85 - i * 0.28),
      );
    }
    canvas.drawCircle(c, r * 0.13, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "NearWord" wordmark with a gradient on the second half.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Near', style: base),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.brandSoft, AppColors.cyan],
          ).createShader(rect),
          child: Text('Word', style: base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
