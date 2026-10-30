import 'package:flutter/material.dart';

import '../game/cards.dart';
import '../game/engine.dart';
import 'icons.dart';
import 'theme.dart';

/// App-wide player name, editable on the home screen and read by every
/// screen. Backed by a [ValueNotifier] so edits propagate.
class AppName extends InheritedNotifier {
  const AppName({super.key, required Listenable notifier, required super.child})
      : super(notifier: notifier);

  /// One-shot read; establishes no dependency.
  static String read(BuildContext context) {
    final w = context.findAncestorWidgetOfExactType<AppName>();
    return (w?.notifier as ValueNotifier<String>?)?.value.trim() ?? '';
  }

  /// Read that rebuilds when the name changes.
  static ValueNotifier<String>? of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppName>();
    return w?.notifier as ValueNotifier<String>?;
  }
}

/// Themed page scaffold: the moonlit forest behind a deep teal wash.
class TntScaffold extends StatelessWidget {
  const TntScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(TNTTheme.textureForest, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TNTTheme.deepTealDark.withValues(alpha: 0.72),
                  TNTTheme.deepTealDark.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

/// A gilded, rounded menu button for the home screen and mode pickers.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: TNTTheme.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: TNTTheme.goldSoft.withValues(alpha: 0.65)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: TNTTheme.goldSoft, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: TNTTheme.fontTitle,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: TNTTheme.parchment,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontFamily: TNTTheme.fontUi,
                            fontSize: 12.5,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: TNTTheme.goldSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bot-skill selection tile (Amateur / Skilled / Master).
class SkillTile extends StatelessWidget {
  const SkillTile({
    super.key,
    required this.skill,
    required this.selected,
    required this.onTap,
  });

  final BotSkill skill;
  final bool selected;
  final VoidCallback onTap;

  static const _labels = {
    BotSkill.amateur: 'Amateur',
    BotSkill.skilled: 'Skilled',
    BotSkill.master: 'Master',
  };
  static const _blurb = {
    BotSkill.amateur: 'Learns the craft.',
    BotSkill.skilled: 'Sharp — slips now and then.',
    BotSkill.master: 'Flawless play.',
  };

  @override
  Widget build(BuildContext context) {
    final glyph = switch (skill) {
      BotSkill.amateur => CardColor.star,
      BotSkill.skilled => CardColor.moon,
      BotSkill.master => CardColor.sun,
    };
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? TNTTheme.gold.withValues(alpha: 0.22)
                : TNTTheme.ink.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? TNTTheme.gold
                  : TNTTheme.goldSoft.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorGlyph(color: glyph, size: selected ? 24 : 18),
              const SizedBox(height: 6),
              Text(
                _labels[skill]!,
                style: TextStyle(
                  fontFamily: TNTTheme.fontTitle,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? TNTTheme.goldSoft
                      : Colors.white70,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _blurb[skill]!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: TNTTheme.fontUi,
                    fontSize: 10.5,
                    color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A minus/plus counter with a labelled center readout.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  Widget _button(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TNTTheme.ink.withValues(alpha: enabled ? 0.7 : 0.4),
          border: Border.all(
              color: TNTTheme.goldSoft.withValues(
                  alpha: enabled ? 0.8 : 0.3),
              width: 1.2),
        ),
        child: Icon(icon,
            color: TNTTheme.goldSoft.withValues(alpha: enabled ? 1 : 0.4),
            size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontFamily: TNTTheme.fontTitle,
              fontSize: 15,
              color: TNTTheme.parchment),
        ),
        const SizedBox(width: 16),
        _button(Icons.remove, value > min, () => onChange(value - 1)),
        const SizedBox(width: 14),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: TNTTheme.fontDisplay,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: TNTTheme.goldSoft),
          ),
        ),
        const SizedBox(width: 14),
        _button(Icons.add, value < max, () => onChange(value + 1)),
      ],
    );
  }
}

/// A parchment panel with a gilded border — the standard content card.
class ParchmentPanel extends StatelessWidget {
  const ParchmentPanel({
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.width,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(TNTTheme.textureParchment, fit: BoxFit.cover),
            Container(color: TNTTheme.parchment.withValues(alpha: 0.88)),
            Padding(
              padding: padding,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _GiltBorder(14, TNTTheme.goldSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiltBorder extends CustomPainter {
  _GiltBorder(this.radius, this.color);
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _GiltBorder old) => old.color != color;
}
