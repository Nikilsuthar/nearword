import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Page scaffold with the NearWord backdrop: midnight base with soft violet
/// and cyan glows. Content is centred and capped for tablets.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.maxWidth = 560,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: body,
          ),
        ),
      ),
    ).withBackdrop(dark);
  }
}

extension on Widget {
  Widget withBackdrop(bool dark) => Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: dark ? AppColors.bgDark : AppColors.bgLight,
            ),
          ),
          Positioned(
            top: -140,
            left: -120,
            child: _Glow(
              color: AppColors.brand.withValues(alpha: dark ? 0.32 : 0.14),
              size: 380,
            ),
          ),
          Positioned(
            bottom: -160,
            right: -140,
            child: _Glow(
              color: AppColors.cyan.withValues(alpha: dark ? 0.16 : 0.10),
              size: 420,
            ),
          ),
          this,
        ],
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Rounded surface used across the app.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? scheme.surface : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor ?? scheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded label used for stats (streak, coins, timer ...).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.semantics,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semantics ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? scheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
