import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Small, reusable UI pieces shared by the screens.

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A coloured panel with a gradient, used for hero cards.
class GradientPanel extends StatelessWidget {
  const GradientPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
    this.onTap,
  });

  final List<Color> colors;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.subtitle, this.icon});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Selectable cards in a row/column. One is always selected.
class ChoiceCards<T> extends StatelessWidget {
  const ChoiceCards({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.vertical = false,
  });

  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Stack the cards vertically (needed when subtitles are long).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final o in options)
        _ChoiceCard(
          option: o,
          selected: o.value == selected,
          onTap: () => onChanged(o.value),
          wide: vertical,
        ),
    ];
    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.wide,
  });

  final ChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brand : scheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: wide
                  ? Row(
                      children: [
                        if (option.icon != null) ...[
                          Icon(option.icon, color: fg),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                            child:
                                _texts(fg, scheme, CrossAxisAlignment.start)),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (option.icon != null) ...[
                          Icon(option.icon, color: fg),
                          const SizedBox(height: 6),
                        ],
                        _texts(fg, scheme, CrossAxisAlignment.center),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts(Color fg, ColorScheme scheme, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        if (option.subtitle != null && wide) ...[
          const SizedBox(height: 2),
          Text(
            option.subtitle!,
            style: TextStyle(
              color: fg.withValues(alpha: 0.78),
              fontSize: 12.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Coin amount with a coin icon.
class CoinText extends StatelessWidget {
  const CoinText(this.amount, {super.key, this.style, this.size = 18});

  final int amount;
  final TextStyle? style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.monetization_on_rounded, size: size, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(
          '$amount',
          style: style ?? const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

/// Pill with the chosen word style + level, e.g. "Regular · Medium".
class StyleChip extends StatelessWidget {
  const StyleChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Avatar colours (no purple).
const List<Color> kAvatarColors = [
  Color(0xFF2F80ED),
  Color(0xFF13A8C4),
  Color(0xFFFF6B5B),
  Color(0xFF2BD67B),
  Color(0xFFFF9F1C),
  Color(0xFF5C9DFF),
  Color(0xFFE5486B),
  Color(0xFF1FB58F),
];

/// Round avatar showing the first letter of a name.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.colorIndex = 0,
    this.size = 36,
  });

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = kAvatarColors[colorIndex.abs() % kAvatarColors.length];
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
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
