import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/cards.dart';
import 'icons.dart';
import 'theme.dart';

/// The full card face, painted like the printed deck: a saturated, full-bleed
/// colour wash, a glowing subject, a big white number in the top-left with its
/// colour mark, and the same pair repeated upside-down in the bottom-right.
///
/// Master Magicians have no number: their name sits across the bottom in
/// letterspaced white capitals, with the colour mark before it.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.cloak,
    this.width = 88,
    this.glow = false,
  });
  final GameCard card;
  final double width;

  /// When set, [card] is drawn covered by this Cloak card (face-up).
  final GameCard? cloak;

  /// Draws a gilded selection rim and halo around the card.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final h = width / 0.72;
    final radius = width * 0.085;
    final face = cloak != null
        ? CloakCover(covered: card, cloak: cloak!, width: width)
        : _CardFace(card: card, width: width);
    return AnimatedScale(
      scale: glow ? 1.035 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: SizedBox(
        width: width,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: glow
                    ? TNTTheme.gold.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.42),
                blurRadius: glow ? 14 : 6,
                spreadRadius: glow ? 1.5 : 0,
                offset: glow ? Offset.zero : const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                face,
                if (glow)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _SelectionRimPainter(
                        color: TNTTheme.goldSoft,
                        strokeWidth: math.max(1.6, width * 0.035),
                        radius: radius,
                      ),
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

/// The painted face of a single card.
class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width});
  final GameCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final isTalisman = card.isTalisman;
    final tint = TNTTheme.cardTint[card.color]!;
    final light = TNTTheme.cardTintLight[card.color]!;
    final deep = TNTTheme.cardTintDeep[card.color]!;
    final glow = TNTTheme.cardGlow[card.color]!;
    final accent = TNTTheme.cardAccent[card.color]!;
    final artSize = w * (isTalisman ? 0.94 : 0.88);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed colour wash, bright at the top-left.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, tint, deep],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
        // A whisper of parchment grain, so the colour feels printed.
        Opacity(
          opacity: 0.11,
          child: Image.asset(TNTTheme.textureParchment, fit: BoxFit.cover),
        ),
        // The halo that makes the subject glow off the card.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, isTalisman ? 0.02 : -0.12),
                radius: 0.86,
                colors: [
                  glow.withValues(alpha: 0.62),
                  glow.withValues(alpha: 0.18),
                  glow.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.46, 0.78],
              ),
            ),
          ),
        ),
        // The painted subject.
        Align(
          alignment: Alignment(0, isTalisman ? 0.01 : -0.10),
          child: isTalisman
              ? TalismanIcon(type: card.talisman!, size: artSize, rich: true)
              : MagicianIcon(kind: card.magician!, size: artSize, rich: true),
        ),
        // Sparkles, vignette, and the name band.
        Positioned.fill(
          child: CustomPaint(
            painter: _FaceAtmospherePainter(
              seed: card.id,
              sparkle: accent,
              nameBand: !isTalisman,
            ),
          ),
        ),
        if (isTalisman) ...[
          _CornerMark(card: card, width: w, top: true),
          _CornerMark(card: card, width: w, top: false),
        ] else
          _NameBand(card: card, width: w),
        // A fine dark edge, as on the printed cards.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w * 0.085),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The top-left number + colour mark, and its upside-down twin at bottom-right.
class _CornerMark extends StatelessWidget {
  const _CornerMark({
    required this.card,
    required this.width,
    required this.top,
  });
  final GameCard card;
  final double width;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final mark = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${card.number}',
          style: TextStyle(
            fontFamily: TNTTheme.fontNumber,
            fontSize: w * 0.25,
            fontWeight: FontWeight.w900,
            height: 0.84,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: w * 0.035,
                offset: Offset(0, w * 0.012),
              ),
            ],
          ),
        ),
        SizedBox(height: w * 0.012),
        ColorGlyph(
          color: card.color,
          size: w * 0.15,
          tint: Colors.white,
          outline: Colors.black.withValues(alpha: 0.22),
        ),
      ],
    );
    final pad = EdgeInsets.all(w * 0.055);
    if (top) {
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(padding: pad, child: mark),
      );
    }
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: pad,
        child: Transform.rotate(angle: math.pi, child: mark),
      ),
    );
  }
}

/// The bottom nameplate of a Master Magician.
class _NameBand extends StatelessWidget {
  const _NameBand({required this.card, required this.width});
  final GameCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Positioned(
      left: w * 0.04,
      right: w * 0.04,
      bottom: w * 0.055,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ColorGlyph(
            color: card.color,
            size: w * 0.125,
            tint: Colors.white,
            outline: Colors.black.withValues(alpha: 0.22),
          ),
          SizedBox(width: w * 0.025),
          Flexible(
            child: Text(
              card.magician!.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TNTTheme.fontTitle,
                fontSize: w * 0.105,
                fontWeight: FontWeight.w700,
                letterSpacing: w * 0.008,
                height: 1.0,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: w * 0.03,
                    offset: Offset(0, w * 0.008),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A cloaked Talisman in the forest: the Cloak card face-up on top, with
/// the covered card's face-up sliver peeking out beneath it. Its corner
/// number stays visible (upside-down) under the Cloak, so the cover reads
/// as a stack rather than a plain card back.
class CloakCover extends StatelessWidget {
  const CloakCover({
    super.key,
    required this.covered,
    required this.cloak,
    this.width = 88,
  });

  /// The hidden Talisman.
  final GameCard covered;

  /// The Cloak card sitting on top of it.
  final GameCard cloak;

  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w / 0.72;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The covered card, shifted down so its bottom edge and
          // upside-down corner number peek out from under the Cloak.
          Transform.translate(
            offset: Offset(0, h * 0.14),
            child: _CardFace(card: covered, width: w),
          ),
          _CardFace(card: cloak, width: w),
        ],
      ),
    );
  }
}

/// The card back: a moonlit silver panel with black ravens, filigree, and the
/// T&T monogram — the look of the printed deck.
class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 88, this.child});
  final double width;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w / 0.72;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.085),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _RavenBackPainter(width: w)),
            if (child != null) Center(child: child!),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Sparkles, vignette, and the dark band behind a Magician's name.
class _FaceAtmospherePainter extends CustomPainter {
  _FaceAtmospherePainter({
    required this.seed,
    required this.sparkle,
    required this.nameBand,
  });
  final int seed;
  final Color sparkle;
  final bool nameBand;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final rnd = math.Random(seed * 7919 + 17);

    // A ring of tiny painted stars around the subject.
    for (var i = 0; i < 7; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final radius = w * (0.34 + rnd.nextDouble() * 0.14);
      final c = Offset(
        w / 2 + math.cos(a) * radius,
        h * 0.46 + math.sin(a) * radius * 1.18,
      );
      final s = w * (0.012 + rnd.nextDouble() * 0.022);
      canvas.drawCircle(
        c,
        s,
        Paint()
          ..color = sparkle.withValues(alpha: 0.25 + rnd.nextDouble() * 0.4),
      );
    }
    // Two larger four-point sparkles.
    for (var i = 0; i < 2; i++) {
      final c = Offset(
        w * (0.16 + rnd.nextDouble() * 0.68),
        h * (0.16 + rnd.nextDouble() * 0.30),
      );
      final s = w * (0.035 + rnd.nextDouble() * 0.03);
      final path = Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx + s * 0.16, c.dy - s * 0.16, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx + s * 0.16, c.dy + s * 0.16, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx - s * 0.16, c.dy + s * 0.16, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx - s * 0.16, c.dy - s * 0.16, c.dx, c.dy - s)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Darkened bottom for a Magician's name.
    if (nameBand) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.52),
            ],
          ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38)),
      );
    }

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.26)],
          stops: const [0.58, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceAtmospherePainter old) =>
      old.seed != seed || old.sparkle != sparkle || old.nameBand != nameBand;
}

/// The gilded rim drawn around a selectable card.
class _SelectionRimPainter extends CustomPainter {
  _SelectionRimPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionRimPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

/// The silver raven back, painted to match the deck's printed back.
class _RavenBackPainter extends CustomPainter {
  _RavenBackPainter({required this.width});
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final cx = w / 2;
    final cy = h / 2;

    // Silver ground.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F4F4), Color(0xFFD3DCDE), Color(0xFFAFBCC0)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Dark outer band with fine silver pinstripes.
    final band = w * 0.058;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(band / 2),
        Radius.circular(w * 0.075),
      ),
      Paint()
        ..color = const Color(0xFF151D20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = band,
    );
    final stripe = Paint()
      ..color = const Color(0xFFD9E2E4).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, w * 0.006);
    for (var i = 0; i < 3; i++) {
      final inset = band * (0.22 + i * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(w * 0.07)),
        stripe,
      );
    }

    // Inner silver panel.
    final panel = rect.deflate(band * 1.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(w * 0.045)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9EEEF), Color(0xFFC2CDD0)],
        ).createShader(panel),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(w * 0.045)),
      Paint()
        ..color = const Color(0xFF1A2224)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.012),
    );

    // Faint engraved swirls.
    final swirl = Paint()
      ..color = const Color(0xFF6E7F84).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, w * 0.006);
    for (var i = 0; i < 5; i++) {
      final r = w * (0.16 + i * 0.055);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.4),
        math.pi * (0.15 + i * 0.35),
        math.pi * 0.85,
        false,
        swirl,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.4),
        math.pi * (1.15 + i * 0.35),
        math.pi * 0.85,
        false,
        swirl,
      );
    }

    // Four ravens wheeling around the monogram.
    final raven = Paint()..color = const Color(0xFF0B1013);
    final positions = [
      Offset(cx - w * 0.23, cy - h * 0.20),
      Offset(cx + w * 0.23, cy - h * 0.20),
      Offset(cx - w * 0.23, cy + h * 0.20),
      Offset(cx + w * 0.23, cy + h * 0.20),
    ];
    final angles = [0.55, 2.30, 3.70, 5.45];
    for (var i = 0; i < positions.length; i++) {
      _paintRaven(canvas, positions[i], w * 0.15, angles[i], raven);
    }

    // Central medallion.
    final med = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * 0.30,
        height: h * 0.20,
      ),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(
      med,
      Paint()..color = const Color(0xFFE9EEEF).withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      med,
      Paint()
        ..color = const Color(0xFF11181B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.018),
    );
    canvas.drawRRect(
      med.deflate(w * 0.012),
      Paint()
        ..color = const Color(0xFF11181B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.007),
    );

    // T&T monogram.
    final tp = TextPainter(
      text: TextSpan(
        text: 'T&T',
        style: TextStyle(
          fontFamily: TNTTheme.fontTitle,
          fontSize: w * 0.115,
          fontWeight: FontWeight.w900,
          letterSpacing: w * 0.005,
          color: const Color(0xFF11181B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Corner flourishes.
    final flourish = Paint()
      ..color = const Color(0xFF11181B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.010)
      ..strokeCap = StrokeCap.round;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final p = Offset(cx + sx * w * 0.38, cy + sy * h * 0.38);
        final path = Path()
          ..moveTo(p.dx, p.dy - sy * w * 0.035)
          ..quadraticBezierTo(
            p.dx + sx * w * 0.035,
            p.dy,
            p.dx,
            p.dy + sy * w * 0.035,
          )
          ..quadraticBezierTo(
            p.dx - sx * w * 0.035,
            p.dy,
            p.dx,
            p.dy - sy * w * 0.035,
          );
        canvas.drawPath(path, flourish);
      }
    }
  }

  void _paintRaven(
    Canvas canvas,
    Offset c,
    double s,
    double rotation,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.42, height: s * 0.90),
      paint,
    );
    // Head.
    canvas.drawCircle(Offset(0, -s * 0.44), s * 0.20, paint);
    // Beak.
    final beak = Path()
      ..moveTo(-s * 0.08, -s * 0.50)
      ..lineTo(-s * 0.40, -s * 0.40)
      ..lineTo(-s * 0.08, -s * 0.32)
      ..close();
    canvas.drawPath(beak, paint);
    // Wings.
    for (final sx in [-1.0, 1.0]) {
      final wing = Path()
        ..moveTo(0, -s * 0.18)
        ..quadraticBezierTo(sx * s * 0.55, -s * 0.58, sx * s * 0.88, -s * 0.10)
        ..quadraticBezierTo(sx * s * 0.50, -s * 0.02, 0, s * 0.12)
        ..close();
      canvas.drawPath(wing, paint);
    }
    // Tail.
    final tail = Path()
      ..moveTo(-s * 0.10, s * 0.36)
      ..lineTo(0, s * 0.78)
      ..lineTo(s * 0.10, s * 0.36)
      ..close();
    canvas.drawPath(tail, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RavenBackPainter old) => old.width != width;
}
