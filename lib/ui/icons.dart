import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/cards.dart';
import 'theme.dart';

// --- Shared drawing helpers -------------------------------------------------
//
// NOTE (Flutter 3.47 engine API): Path owns [PathFillType] (Paint no longer
// carries it), and Path.quadraticBezierTo takes four doubles
// (control x1,y1 then end x2,y2).

Path _starPath(Rect r, {double inner = 0.42}) {
  final cx = r.center.dx;
  final cy = r.center.dy;
  final ro = r.shortestSide / 2;
  final ri = ro * inner;
  const points = 5;
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? ro : ri;
    final angle = math.pi / points * i - math.pi / 2;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// A crescent: outer disc minus an offset disc, filled with even-odd.
Path _crescentPath(Rect r) {
  final cx = r.center.dx;
  final cy = r.center.dy;
  final ro = r.shortestSide / 2;
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: ro))
    ..addOval(
      Rect.fromCircle(
        center: Offset(cx + ro * 0.45, cy - ro * 0.1),
        radius: ro * 0.82,
      ),
    );
}

Paint _fill(Color col) => Paint()
  ..color = col
  ..style = PaintingStyle.fill;

Paint _stroke(Color col, double w) => Paint()
  ..color = col
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

typedef _Drawer = void Function(Canvas canvas, Rect r, Color c);

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this._draw, this._color);
  final _Drawer _draw;
  final Color _color;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final r = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side * 0.86,
      height: side * 0.86,
    );
    _draw(canvas, r, _color);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old._draw != _draw || old._color != _color;
}

class _SizedIcon extends StatelessWidget {
  const _SizedIcon({required this.size, required this.painter});
  final double size;
  final CustomPainter painter;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: painter),
  );
}

// --- Talismans --------------------------------------------------------------

const Map<TalismanType, Color> _talismanDefault = {
  TalismanType.toad: Color(0xFF5C8A3F),
  TalismanType.flower: Color(0xFFC75B8A),
  TalismanType.crystal: Color(0xFF4E9DB0),
  TalismanType.mushroom: Color(0xFFB4442E),
  TalismanType.raven: Color(0xFF2A2118),
};

void _drawToad(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final ink = TNTTheme.ink;
  final w = r.width;
  // Body: a squat rounded blob.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, r.bottom - w * 0.30),
      width: w * 0.82,
      height: w * 0.62,
    ),
    _fill(col),
  );
  // Eye bumps on top.
  for (final sx in [-1, 1]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.20, r.top + w * 0.20),
      w * 0.17,
      _fill(col),
    );
  }
  // Eyes: white with ink pupils, gold highlight.
  for (final sx in [-1, 1]) {
    final e = Offset(cx + sx * w * 0.20, r.top + w * 0.19);
    c.drawCircle(e, w * 0.10, _fill(Colors.white));
    c.drawCircle(e + Offset(0, w * 0.015), w * 0.05, _fill(ink));
    c.drawCircle(e + Offset(-w * 0.02, -w * 0.02), w * 0.018, _fill(gold));
  }
  // Nostrils.
  for (final sx in [-1, 1]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.06, r.top + w * 0.36),
      w * 0.02,
      _fill(ink),
    );
  }
  // Smile.
  final smile = Path()..moveTo(cx - w * 0.20, r.top + w * 0.44);
  smile.quadraticBezierTo(
    cx,
    r.top + w * 0.56,
    cx + w * 0.20,
    r.top + w * 0.44,
  );
  c.drawPath(smile, _stroke(ink, w * 0.035));
}

void _drawFlower(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final cy = r.center.dy;
  final gold = TNTTheme.gold;
  const petals = 6;
  for (var i = 0; i < petals; i++) {
    final angle = math.pi * 2 / petals * i - math.pi / 2;
    final px = cx + math.cos(angle) * r.width * 0.24;
    final py = cy + math.sin(angle) * r.width * 0.24;
    c.save();
    c.translate(px, py);
    c.rotate(angle + math.pi / 2);
    c.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r.width * 0.30,
        height: r.width * 0.46,
      ),
      _fill(col),
    );
    c.restore();
  }
  // Center disc, gilded.
  c.drawCircle(Offset(cx, cy), r.width * 0.19, _fill(gold));
  c.drawCircle(
    Offset(cx, cy),
    r.width * 0.19,
    _stroke(TNTTheme.ink, r.width * 0.02),
  );
}

void _drawCrystal(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final ink = TNTTheme.ink;
  final w = r.width;
  final top = r.top;
  final girdleY = r.top + w * 0.40;
  final tl = Offset(cx - w * 0.30, top);
  final tr = Offset(cx + w * 0.30, top);
  final gl = Offset(cx - w * 0.44, girdleY);
  final gr = Offset(cx + w * 0.44, girdleY);
  final culet = Offset(cx, r.bottom);
  final outline = Path()
    ..moveTo(tl.dx, tl.dy)
    ..lineTo(tr.dx, tr.dy)
    ..lineTo(gr.dx, gr.dy)
    ..lineTo(culet.dx, culet.dy)
    ..lineTo(gl.dx, gl.dy)
    ..close();
  c.drawPath(outline, _fill(col));
  c.drawPath(outline, _stroke(ink, w * 0.03));
  // Facets.
  c.drawLine(tr, culet, _stroke(ink, w * 0.022));
  c.drawLine(tl, culet, _stroke(ink, w * 0.022));
  c.drawLine(gl, Offset(cx, top + w * 0.02), _stroke(ink, w * 0.022));
  c.drawLine(gr, Offset(cx, top + w * 0.02), _stroke(ink, w * 0.022));
  // Gilded sparkle.
  c.drawPath(
    _starPath(
      Rect.fromCenter(
        center: Offset(cx + w * 0.14, top + w * 0.20),
        width: w * 0.20,
        height: w * 0.20,
      ),
      inner: 0.35,
    ),
    _fill(gold),
  );
}

void _drawMushroom(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final w = r.width;
  // Stem: pale cream rounded rect.
  final stem = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(cx, r.bottom - w * 0.20),
      width: w * 0.34,
      height: w * 0.46,
    ),
    Radius.circular(w * 0.10),
  );
  c.drawRRect(stem, _fill(const Color(0xFFEAD9B0)));
  c.drawRRect(stem, _stroke(TNTTheme.ink, w * 0.025));
  // Cap: dome.
  final cap = Path()
    ..moveTo(cx - w * 0.48, r.top + w * 0.46)
    ..quadraticBezierTo(cx, r.top - w * 0.10, cx + w * 0.48, r.top + w * 0.46)
    ..close();
  c.drawPath(cap, _fill(col));
  c.drawPath(cap, _stroke(TNTTheme.ink, w * 0.03));
  // Spots.
  for (final (dx, dy, s) in [
    (0.0, 0.28, 0.09),
    (-0.22, 0.34, 0.06),
    (0.22, 0.34, 0.06),
  ]) {
    c.drawCircle(Offset(cx + dx * w, r.top + dy * w), s * w, _fill(gold));
  }
}

void _drawRaven(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final w = r.width;
  // Body.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx + w * 0.04, r.center.dy + w * 0.02),
      width: w * 0.62,
      height: w * 0.46,
    ),
    _fill(col),
  );
  // Head (upper left).
  c.drawCircle(Offset(cx - w * 0.16, r.top + w * 0.24), w * 0.16, _fill(col));
  // Beak.
  final beak = Path()
    ..moveTo(cx - w * 0.30, r.top + w * 0.20)
    ..lineTo(cx - w * 0.52, r.top + w * 0.28)
    ..lineTo(cx - w * 0.30, r.top + w * 0.32)
    ..close();
  c.drawPath(beak, _fill(gold));
  // Tail (right).
  final tail = Path()
    ..moveTo(cx + w * 0.30, r.center.dy - w * 0.02)
    ..lineTo(cx + w * 0.56, r.center.dy + w * 0.18)
    ..lineTo(cx + w * 0.24, r.center.dy + w * 0.16)
    ..close();
  c.drawPath(tail, _fill(col));
  // Eye.
  c.drawCircle(Offset(cx - w * 0.17, r.top + w * 0.22), w * 0.035, _fill(gold));
  // Legs.
  c.drawLine(
    Offset(cx + w * 0.0, r.bottom - w * 0.10),
    Offset(cx - w * 0.02, r.bottom),
    _stroke(col, w * 0.03),
  );
  c.drawLine(
    Offset(cx + w * 0.14, r.bottom - w * 0.10),
    Offset(cx + w * 0.12, r.bottom),
    _stroke(col, w * 0.03),
  );
}

const Map<TalismanType, _Drawer> _talismanDraw = {
  TalismanType.toad: _drawToad,
  TalismanType.flower: _drawFlower,
  TalismanType.crystal: _drawCrystal,
  TalismanType.mushroom: _drawMushroom,
  TalismanType.raven: _drawRaven,
};

/// A stylized talisman: toad, flower, crystal, mushroom, or raven.
///
/// [rich] paints the full-colour storybook version used on the card faces;
/// the default single-tint glyph is used for small UI marks.
class TalismanIcon extends StatelessWidget {
  const TalismanIcon({
    super.key,
    required this.type,
    this.size = 64,
    this.color,
    this.rich = false,
  });
  final TalismanType type;
  final double size;
  final Color? color;
  final bool rich;
  @override
  Widget build(BuildContext context) => _SizedIcon(
    size: size,
    painter: _GlyphPainter(
      rich ? _talismanRichDraw[type]! : _talismanDraw[type]!,
      color ?? _talismanDefault[type]!,
    ),
  );
}

// --- Master Magicians -------------------------------------------------------

const Map<MagicianKind, Color> _magicianDefault = {
  MagicianKind.vanish: Color(0xFF8FB8C9),
  MagicianKind.summon: Color(0xFFE4C766),
  MagicianKind.poison: Color(0xFF7CA23F),
  MagicianKind.cloak: Color(0xFF5C7A9C),
};

void _drawVanish(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final cy = r.center.dy;
  final gold = TNTTheme.gold;
  final w = r.width;
  // Fading crescent.
  c.drawPath(
    _crescentPath(
      Rect.fromCenter(
        center: Offset(cx - w * 0.06, cy),
        width: w * 0.44,
        height: w * 0.44,
      ),
    ),
    _fill(col),
  );
  // Swirl arcs around it, fading.
  for (var i = 0; i < 3; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: Offset(cx - w * 0.06, cy),
        width: w * (0.56 + i * 0.18),
        height: w * (0.56 + i * 0.18),
      ),
      math.pi * 0.15 + i * 0.25,
      math.pi * 1.05,
      false,
      _stroke(col.withValues(alpha: 0.35 + i * 0.18), w * 0.03),
    );
  }
  // A rising gold wisp.
  c.drawPath(
    _starPath(
      Rect.fromCenter(
        center: Offset(cx + w * 0.18, cy - w * 0.18),
        width: w * 0.16,
        height: w * 0.16,
      ),
      inner: 0.35,
    ),
    _fill(gold),
  );
}

void _drawSummon(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final w = r.width;
  // Cupped palm: an open hand.
  final palm = Path()
    ..moveTo(cx - w * 0.42, r.bottom - w * 0.16)
    ..quadraticBezierTo(
      cx,
      r.bottom + w * 0.06,
      cx + w * 0.42,
      r.bottom - w * 0.16,
    )
    ..lineTo(cx + w * 0.42, r.bottom - w * 0.30)
    ..quadraticBezierTo(
      cx,
      r.bottom - w * 0.10,
      cx - w * 0.42,
      r.bottom - w * 0.30,
    )
    ..close();
  c.drawPath(palm, _fill(col));
  c.drawPath(palm, _stroke(TNTTheme.ink, w * 0.025));
  // Rising star above the hand.
  final starRect = Rect.fromCenter(
    center: Offset(cx, r.top + w * 0.30),
    width: w * 0.40,
    height: w * 0.40,
  );
  c.drawPath(_starPath(starRect), _fill(gold));
  c.drawPath(_starPath(starRect), _stroke(TNTTheme.ink, w * 0.02));
  // Spark trails.
  for (final dy in [0.52, 0.62]) {
    c.drawCircle(Offset(cx, r.top + dy * w), w * 0.03, _fill(gold));
  }
}

void _drawPoison(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final ink = TNTTheme.ink;
  final w = r.width;
  // Neck.
  c.drawRect(
    Rect.fromCenter(
      center: Offset(cx, r.top + w * 0.20),
      width: w * 0.24,
      height: w * 0.22,
    ),
    _fill(col),
  );
  // Cork.
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, r.top + w * 0.10),
        width: w * 0.34,
        height: w * 0.12,
      ),
      Radius.circular(w * 0.04),
    ),
    _fill(const Color(0xFFB48A4A)),
  );
  // Body: rounded flask.
  final body = Path()
    ..addOval(
      Rect.fromCenter(
        center: Offset(cx, r.bottom - w * 0.24),
        width: w * 0.64,
        height: w * 0.52,
      ),
    );
  c.drawPath(body, _fill(col));
  c.drawPath(body, _stroke(ink, w * 0.03));
  // Liquid shine + bubbles.
  c.drawCircle(
    Offset(cx - w * 0.12, r.bottom - w * 0.30),
    w * 0.05,
    _fill(col.withValues(alpha: 0.5)),
  );
  for (final (dx, dy, s) in [
    (0.10, 0.30, 0.05),
    (0.16, 0.42, 0.035),
    (0.02, 0.46, 0.03),
  ]) {
    c.drawCircle(Offset(cx + dx * w, r.top + dy * w), s * w, _fill(gold));
  }
}

void _drawCloak(Canvas c, Rect r, Color col) {
  final cx = r.center.dx;
  final gold = TNTTheme.gold;
  final ink = TNTTheme.ink;
  final w = r.width;
  // Shoulders / cloak body.
  final body = Path()
    ..moveTo(cx - w * 0.46, r.bottom)
    ..quadraticBezierTo(
      cx - w * 0.44,
      r.center.dy,
      cx - w * 0.28,
      r.center.dy - w * 0.10,
    )
    ..lineTo(cx + w * 0.28, r.center.dy - w * 0.10)
    ..quadraticBezierTo(cx + w * 0.44, r.center.dy, cx + w * 0.46, r.bottom)
    ..close();
  c.drawPath(body, _fill(col));
  // Hood.
  final hood = Path()
    ..moveTo(cx - w * 0.30, r.center.dy - w * 0.06)
    ..quadraticBezierTo(
      cx,
      r.top - w * 0.04,
      cx + w * 0.30,
      r.center.dy - w * 0.06,
    )
    ..quadraticBezierTo(
      cx,
      r.center.dy + w * 0.04,
      cx - w * 0.30,
      r.center.dy - w * 0.06,
    )
    ..close();
  c.drawPath(hood, _fill(col));
  c.drawPath(hood, _stroke(ink, w * 0.025));
  // Shadowed face.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, r.top + w * 0.34),
      width: w * 0.30,
      height: w * 0.30,
    ),
    _fill(ink.withValues(alpha: 0.85)),
  );
  // Gilded clasp at the collar.
  c.drawPath(
    _starPath(
      Rect.fromCenter(
        center: Offset(cx, r.center.dy + w * 0.02),
        width: w * 0.14,
        height: w * 0.14,
      ),
      inner: 0.4,
    ),
    _fill(gold),
  );
}

const Map<MagicianKind, _Drawer> _magicianDraw = {
  MagicianKind.vanish: _drawVanish,
  MagicianKind.summon: _drawSummon,
  MagicianKind.poison: _drawPoison,
  MagicianKind.cloak: _drawCloak,
};

/// A stylized Master Magician: vanish, summon, poison, or cloak.
///
/// [rich] paints the full-colour portrait used on the card faces; the default
/// single-tint glyph is used for small UI marks.
class MagicianIcon extends StatelessWidget {
  const MagicianIcon({
    super.key,
    required this.kind,
    this.size = 64,
    this.color,
    this.rich = false,
  });
  final MagicianKind kind;
  final double size;
  final Color? color;
  final bool rich;
  @override
  Widget build(BuildContext context) => _SizedIcon(
    size: size,
    painter: _GlyphPainter(
      rich ? _magicianRichDraw[kind]! : _magicianDraw[kind]!,
      color ?? _magicianDefault[kind]!,
    ),
  );
}

// --- Full-colour card art ---------------------------------------------------
//
// The printed deck is painted rather than iconographic: each face is a small
// glowing scene. These richer variants are used at card size; the single-tint
// glyphs above remain for menu and rule-book marks.

const Color _artGold = Color(0xFFE8B44A);
const Color _artInk = Color(0xFF201A2A);

Paint _gradient(Rect r, Color a, Color b, {bool vertical = true}) =>
    Paint()
      ..shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [a, b],
      ).createShader(r);

void _drawToadRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Moonlit water rings.
  for (var i = 0; i < 2; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: Offset(cx, r.bottom - w * 0.08),
        width: w * (1.02 + i * 0.20),
        height: w * (0.34 + i * 0.10),
      ),
      math.pi * 1.06,
      math.pi * 0.88,
      false,
      _stroke(Colors.white.withValues(alpha: 0.26 - i * 0.11), w * 0.018),
    );
  }

  // Lily pad.
  final pad = Rect.fromCenter(
    center: Offset(cx, r.bottom - w * 0.13),
    width: w * 0.98,
    height: w * 0.32,
  );
  c.drawOval(pad, _fill(const Color(0xFF23481F)));
  c.drawOval(pad.deflate(w * 0.035), _fill(const Color(0xFF3C7031)));
  final vein = _stroke(Colors.white.withValues(alpha: 0.16), w * 0.012);
  for (var i = 0; i < 5; i++) {
    final a = math.pi * (1.12 + 0.19 * i);
    c.drawLine(
      Offset(cx, r.bottom - w * 0.13),
      Offset(
        cx + math.cos(a) * w * 0.44,
        r.bottom - w * 0.13 + math.sin(a) * w * 0.12,
      ),
      vein,
    );
  }

  // Body and pale belly.
  final body = Rect.fromCenter(
    center: Offset(cx, top + w * 0.52),
    width: w * 0.78,
    height: w * 0.54,
  );
  c.drawOval(body, _fill(const Color(0xFF6D9238)));
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, top + w * 0.64),
      width: w * 0.46,
      height: w * 0.28,
    ),
    _fill(const Color(0xFFDCD49A)),
  );

  // Front feet.
  for (final sx in [-1.0, 1.0]) {
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx + sx * w * 0.31, top + w * 0.72),
        width: w * 0.17,
        height: w * 0.24,
      ),
      _fill(const Color(0xFF5D7F30)),
    );
  }

  // Eye bumps.
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.19, top + w * 0.27),
      w * 0.19,
      _fill(const Color(0xFF789C40)),
    );
  }
  // Eyes.
  for (final sx in [-1.0, 1.0]) {
    final e = Offset(cx + sx * w * 0.19, top + w * 0.26);
    c.drawCircle(e, w * 0.108, _fill(const Color(0xFFF6EED2)));
    c.drawCircle(e + Offset(0, w * 0.012), w * 0.054, _fill(_artInk));
    c.drawCircle(
      e + Offset(-w * 0.022, -w * 0.026),
      w * 0.019,
      _fill(Colors.white),
    );
  }

  // Nostrils, smile, and speckles.
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.055, top + w * 0.40),
      w * 0.018,
      _fill(_artInk.withValues(alpha: 0.8)),
    );
  }
  final smile = Path()
    ..moveTo(cx - w * 0.19, top + w * 0.45)
    ..quadraticBezierTo(cx, top + w * 0.55, cx + w * 0.19, top + w * 0.45);
  c.drawPath(smile, _stroke(_artInk.withValues(alpha: 0.75), w * 0.025));
  for (final (dx, dy, s) in [
    (-0.27, 0.36, 0.035),
    (0.27, 0.39, 0.028),
    (-0.12, 0.31, 0.022),
  ]) {
    c.drawCircle(
      Offset(cx + dx * w, top + dy * w),
      s * w,
      _fill(const Color(0xFF4E6D27)),
    );
  }

  // Top-light.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.10, top + w * 0.30),
      width: w * 0.24,
      height: w * 0.12,
    ),
    _fill(Colors.white.withValues(alpha: 0.18)),
  );
}

void _drawFlowerRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final cy = r.top + w * 0.45;

  // Still water and reflection.
  c.drawRect(
    Rect.fromLTWH(r.left, r.top + w * 0.66, w, w * 0.34),
    _fill(const Color(0xFF1B4A56).withValues(alpha: 0.55)),
  );
  for (var i = 0; i < 4; i++) {
    c.drawLine(
      Offset(cx - w * (0.34 - i * 0.03), r.top + w * (0.72 + i * 0.055)),
      Offset(cx + w * (0.34 - i * 0.03), r.top + w * (0.72 + i * 0.055)),
      _stroke(Colors.white.withValues(alpha: 0.16 - i * 0.03), w * 0.012),
    );
  }
  // Pad.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, r.top + w * 0.76),
      width: w * 0.82,
      height: w * 0.20,
    ),
    _fill(const Color(0xFF2F6033)),
  );

  // Outer petals.
  for (var i = 0; i < 9; i++) {
    final a = math.pi * 2 / 9 * i - math.pi / 2;
    c.save();
    c.translate(cx + math.cos(a) * w * 0.21, cy + math.sin(a) * w * 0.19);
    c.rotate(a + math.pi / 2);
    final petal = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.24,
      height: w * 0.46,
    );
    c.drawOval(petal, _fill(const Color(0xFFE88CA2)));
    c.drawOval(
      petal.deflate(w * 0.022).translate(0, -w * 0.02),
      _fill(const Color(0xFFF7C3CB)),
    );
    c.restore();
  }
  // Inner petals.
  for (var i = 0; i < 6; i++) {
    final a = math.pi * 2 / 6 * i - math.pi / 2;
    c.save();
    c.translate(cx + math.cos(a) * w * 0.11, cy + math.sin(a) * w * 0.10);
    c.rotate(a + math.pi / 2);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.19, height: w * 0.30),
      _fill(const Color(0xFFFBE7D2)),
    );
    c.restore();
  }
  // Gilded heart.
  c.drawCircle(Offset(cx, cy), w * 0.135, _fill(_artGold));
  c.drawCircle(Offset(cx, cy), w * 0.095, _fill(const Color(0xFFF6D77C)));
  for (var i = 0; i < 7; i++) {
    final a = math.pi * 2 / 7 * i;
    c.drawCircle(
      Offset(cx + math.cos(a) * w * 0.06, cy + math.sin(a) * w * 0.06),
      w * 0.012,
      _fill(const Color(0xFF9C5A18)),
    );
  }
  // Petal highlights.
  c.drawCircle(
    Offset(cx - w * 0.16, cy - w * 0.22),
    w * 0.03,
    _fill(Colors.white.withValues(alpha: 0.5)),
  );
}

void _drawCrystalRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.06;

  // Glow and rocky base.
  c.drawCircle(
    Offset(cx, top + w * 0.44),
    w * 0.40,
    _fill(const Color(0xFFA7F0F0).withValues(alpha: 0.16)),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, r.bottom - w * 0.10),
      width: w * 0.80,
      height: w * 0.22,
    ),
    _fill(const Color(0xFF123A45)),
  );

  void shard(double dx, double height, double width, Color body, Color light) {
    final baseY = r.bottom - w * 0.12;
    final tip = top + w * (0.82 - height);
    final l = cx + dx - width * 0.5;
    final rr = cx + dx + width * 0.5;
    final shoulder = tip + w * height * 0.34;
    final path = Path()
      ..moveTo(cx + dx, tip)
      ..lineTo(rr, shoulder)
      ..lineTo(rr - w * 0.02, baseY)
      ..lineTo(l + w * 0.02, baseY)
      ..lineTo(l, shoulder)
      ..close();
    c.drawPath(path, _fill(body));
    // Lit facet.
    final facet = Path()
      ..moveTo(cx + dx, tip)
      ..lineTo(l, shoulder)
      ..lineTo(l + w * 0.02, baseY)
      ..lineTo(cx + dx - w * 0.01, baseY)
      ..close();
    c.drawPath(facet, _fill(light));
    // Edge lines.
    c.drawPath(path, _stroke(Colors.white.withValues(alpha: 0.55), w * 0.012));
    c.drawLine(
      Offset(cx + dx, tip),
      Offset(cx + dx, baseY),
      _stroke(Colors.white.withValues(alpha: 0.28), w * 0.010),
    );
  }

  shard(
    -w * 0.24,
    0.44,
    w * 0.22,
    const Color(0xFF56B6D6),
    const Color(0xFFB6F1FA),
  );
  shard(
    w * 0.25,
    0.38,
    w * 0.20,
    const Color(0xFF8E76D6),
    const Color(0xFFDCD2FF),
  );
  shard(0, 0.66, w * 0.30, const Color(0xFF7FD8E8), const Color(0xFFE6FEFF));

  // Sparkles.
  for (final (dx, dy, s) in [
    (-0.30, 0.24, 0.09),
    (0.31, 0.16, 0.07),
    (0.18, 0.34, 0.05),
  ]) {
    c.drawPath(
      _starPath(
        Rect.fromCenter(
          center: Offset(cx + dx * w, top + dy * w),
          width: s * w,
          height: s * w,
        ),
        inner: 0.30,
      ),
      _fill(Colors.white.withValues(alpha: 0.92)),
    );
  }
}

void _drawMushroomRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Grass.
  for (final (dx, h, lean) in [
    (-0.34, 0.18, -0.04),
    (-0.22, 0.24, -0.02),
    (0.30, 0.20, 0.04),
    (0.38, 0.14, 0.05),
  ]) {
    final p = Path()
      ..moveTo(cx + dx * w, r.bottom - w * 0.04)
      ..quadraticBezierTo(
        cx + (dx + lean) * w,
        r.bottom - w * (0.04 + h * 0.5),
        cx + (dx + lean) * w,
        r.bottom - w * (0.04 + h),
      );
    c.drawPath(p, _stroke(const Color(0xFF2E5A2B), w * 0.035));
  }

  // Small companion mushroom.
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - w * 0.30, r.bottom - w * 0.20),
        width: w * 0.10,
        height: w * 0.22,
      ),
      Radius.circular(w * 0.04),
    ),
    _fill(const Color(0xFFE6D3A8)),
  );
  final smallCap = Path()
    ..moveTo(cx - w * 0.40, r.bottom - w * 0.28)
    ..quadraticBezierTo(
      cx - w * 0.30,
      r.bottom - w * 0.44,
      cx - w * 0.20,
      r.bottom - w * 0.28,
    )
    ..close();
  c.drawPath(smallCap, _fill(const Color(0xFFB83A34)));

  // Stem.
  final stem = Path()
    ..moveTo(cx - w * 0.13, top + w * 0.52)
    ..quadraticBezierTo(
      cx - w * 0.16,
      r.bottom - w * 0.10,
      cx - w * 0.08,
      r.bottom - w * 0.04,
    )
    ..lineTo(cx + w * 0.09, r.bottom - w * 0.04)
    ..quadraticBezierTo(
      cx + w * 0.15,
      r.bottom - w * 0.12,
      cx + w * 0.12,
      top + w * 0.52,
    )
    ..close();
  c.drawPath(
    stem,
    _gradient(
      stem.getBounds(),
      const Color(0xFFF4E6C4),
      const Color(0xFFC7B183),
    ),
  );
  c.drawPath(
    stem,
    _stroke(const Color(0xFF7A5A32).withValues(alpha: 0.55), w * 0.014),
  );

  // Cap.
  final cap = Path()
    ..moveTo(cx - w * 0.48, top + w * 0.48)
    ..quadraticBezierTo(cx - w * 0.46, top + w * 0.08, cx, top + w * 0.02)
    ..quadraticBezierTo(
      cx + w * 0.46,
      top + w * 0.08,
      cx + w * 0.48,
      top + w * 0.48,
    )
    ..quadraticBezierTo(cx, top + w * 0.58, cx - w * 0.48, top + w * 0.48)
    ..close();
  c.drawPath(
    cap,
    _gradient(
      cap.getBounds(),
      const Color(0xFFE45A46),
      const Color(0xFF9E1F2C),
    ),
  );
  c.drawPath(
    cap,
    _stroke(const Color(0xFF6D1422).withValues(alpha: 0.7), w * 0.018),
  );

  // Gills.
  for (var i = -3; i <= 3; i++) {
    c.drawLine(
      Offset(cx + i * w * 0.055, top + w * 0.47),
      Offset(cx + i * w * 0.045, top + w * 0.55),
      _stroke(const Color(0xFFE8C9A1).withValues(alpha: 0.6), w * 0.012),
    );
  }

  // Spots.
  for (final (dx, dy, s) in [
    (-0.22, 0.24, 0.075),
    (0.05, 0.16, 0.060),
    (0.26, 0.28, 0.055),
    (-0.06, 0.34, 0.042),
    (0.15, 0.40, 0.032),
  ]) {
    c.drawCircle(
      Offset(cx + dx * w, top + dy * w),
      s * w,
      _fill(const Color(0xFFF7EBD2)),
    );
  }
  // Cap sheen.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.18, top + w * 0.20),
      width: w * 0.24,
      height: w * 0.12,
    ),
    _fill(Colors.white.withValues(alpha: 0.22)),
  );
}

void _drawRavenRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Moon.
  c.drawCircle(
    Offset(cx + w * 0.06, top + w * 0.27),
    w * 0.29,
    _fill(const Color(0xFFF7EBC8).withValues(alpha: 0.94)),
  );
  c.drawCircle(
    Offset(cx + w * 0.06, top + w * 0.27),
    w * 0.29,
    _stroke(const Color(0xFFFFF7DF).withValues(alpha: 0.7), w * 0.02),
  );

  // Branch.
  final branch = Path()
    ..moveTo(r.left + w * 0.04, r.bottom - w * 0.22)
    ..quadraticBezierTo(
      cx,
      r.bottom - w * 0.10,
      r.right - w * 0.02,
      r.bottom - w * 0.20,
    );
  c.drawPath(branch, _stroke(const Color(0xFF2B2119), w * 0.055));
  c.drawPath(branch, _stroke(const Color(0xFF5A4130), w * 0.022));

  // Body.
  c.save();
  c.translate(cx + w * 0.03, top + w * 0.55);
  c.rotate(-0.18);
  final body = Rect.fromCenter(
    center: Offset.zero,
    width: w * 0.42,
    height: w * 0.50,
  );
  c.drawOval(body, _fill(const Color(0xFF161C26)));
  c.drawOval(
    body.deflate(w * 0.03).translate(-w * 0.05, -w * 0.02),
    _fill(const Color(0xFF2D4258).withValues(alpha: 0.75)),
  );
  // Wing feather strokes.
  for (var i = 0; i < 4; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.02, w * 0.03),
        width: w * (0.30 + i * 0.03),
        height: w * (0.22 + i * 0.02),
      ),
      math.pi * 1.15,
      math.pi * 0.55,
      false,
      _stroke(const Color(0xFF0B0F16), w * 0.018),
    );
  }
  c.restore();

  // Tail.
  final tail = Path()
    ..moveTo(cx + w * 0.17, top + w * 0.64)
    ..lineTo(cx + w * 0.44, top + w * 0.80)
    ..lineTo(cx + w * 0.19, top + w * 0.79)
    ..close();
  c.drawPath(tail, _fill(const Color(0xFF11161F)));

  // Head and beak.
  final head = Offset(cx - w * 0.15, top + w * 0.35);
  c.drawCircle(head, w * 0.135, _fill(const Color(0xFF161C26)));
  c.drawCircle(
    head.translate(-w * 0.03, -w * 0.03),
    w * 0.08,
    _fill(const Color(0xFF2D4258).withValues(alpha: 0.6)),
  );
  final beak = Path()
    ..moveTo(head.dx - w * 0.09, head.dy - w * 0.02)
    ..lineTo(head.dx - w * 0.30, head.dy + w * 0.03)
    ..lineTo(head.dx - w * 0.09, head.dy + w * 0.08)
    ..close();
  c.drawPath(beak, _fill(const Color(0xFFD9A648)));
  c.drawCircle(
    head.translate(-w * 0.03, -w * 0.02),
    w * 0.022,
    _fill(const Color(0xFFF7EBC8)),
  );
  c.drawCircle(
    head.translate(-w * 0.03, -w * 0.02),
    w * 0.011,
    _fill(const Color(0xFF0B0F16)),
  );

  // Feet.
  for (final dx in [-0.06, 0.10]) {
    c.drawLine(
      Offset(cx + dx * w, top + w * 0.78),
      Offset(cx + dx * w, r.bottom - w * 0.20),
      _stroke(const Color(0xFFD9A648), w * 0.022),
    );
  }

  // Stars.
  for (final (dx, dy, s) in [
    (-0.34, 0.12, 0.07),
    (0.36, 0.10, 0.05),
    (0.34, 0.40, 0.04),
  ]) {
    c.drawPath(
      _starPath(
        Rect.fromCenter(
          center: Offset(cx + dx * w, top + dy * w),
          width: s * w,
          height: s * w,
        ),
        inner: 0.32,
      ),
      _fill(const Color(0xFFFFE9AE)),
    );
  }
}

const Map<TalismanType, _Drawer> _talismanRichDraw = {
  TalismanType.toad: _drawToadRich,
  TalismanType.flower: _drawFlowerRich,
  TalismanType.crystal: _drawCrystalRich,
  TalismanType.mushroom: _drawMushroomRich,
  TalismanType.raven: _drawRavenRich,
};

// --- Master Magician portraits ---------------------------------------------

void _drawVanishRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Spell swirls.
  for (var i = 0; i < 3; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: Offset(cx, top + w * 0.46),
        width: w * (0.86 + i * 0.16),
        height: w * (0.66 + i * 0.12),
      ),
      math.pi * 0.10 + i * 0.30,
      math.pi * 1.10,
      false,
      _stroke(Colors.white.withValues(alpha: 0.20 - i * 0.04), w * 0.022),
    );
  }

  // Robe.
  final robe = Path()
    ..moveTo(cx - w * 0.42, r.bottom - w * 0.02)
    ..quadraticBezierTo(
      cx - w * 0.34,
      top + w * 0.62,
      cx - w * 0.22,
      top + w * 0.48,
    )
    ..lineTo(cx + w * 0.22, top + w * 0.48)
    ..quadraticBezierTo(
      cx + w * 0.34,
      top + w * 0.62,
      cx + w * 0.42,
      r.bottom - w * 0.02,
    )
    ..close();
  c.drawPath(
    robe,
    _gradient(
      robe.getBounds(),
      const Color(0xFF3C5E93),
      const Color(0xFF1C2C4E),
    ),
  );
  c.drawPath(
    robe,
    _stroke(const Color(0xFF9CB6D8).withValues(alpha: 0.35), w * 0.015),
  );

  // Open spellbook.
  final leftPage = Path()
    ..moveTo(cx - w * 0.40, r.bottom - w * 0.04)
    ..lineTo(cx - w * 0.02, r.bottom - w * 0.12)
    ..lineTo(cx - w * 0.02, r.bottom - w * 0.27)
    ..lineTo(cx - w * 0.37, r.bottom - w * 0.20)
    ..close();
  final rightPage = Path()
    ..moveTo(cx + w * 0.40, r.bottom - w * 0.04)
    ..lineTo(cx + w * 0.02, r.bottom - w * 0.12)
    ..lineTo(cx + w * 0.02, r.bottom - w * 0.27)
    ..lineTo(cx + w * 0.37, r.bottom - w * 0.20)
    ..close();
  for (final page in [leftPage, rightPage]) {
    c.drawPath(page, _fill(const Color(0xFFF3E3BE)));
    c.drawPath(
      page,
      _stroke(const Color(0xFF8A6A3B).withValues(alpha: 0.6), w * 0.012),
    );
  }
  for (var i = 0; i < 3; i++) {
    c.drawLine(
      Offset(cx - w * 0.34 + i * w * 0.02, r.bottom - w * (0.22 - i * 0.035)),
      Offset(cx - w * 0.08, r.bottom - w * (0.28 - i * 0.035)),
      _stroke(const Color(0xFFB49A6A).withValues(alpha: 0.7), w * 0.010),
    );
  }

  // Beard.
  final beard = Path()
    ..moveTo(cx - w * 0.23, top + w * 0.38)
    ..quadraticBezierTo(
      cx - w * 0.30,
      top + w * 0.62,
      cx - w * 0.14,
      top + w * 0.72,
    )
    ..quadraticBezierTo(cx, top + w * 0.78, cx + w * 0.14, top + w * 0.72)
    ..quadraticBezierTo(
      cx + w * 0.30,
      top + w * 0.62,
      cx + w * 0.23,
      top + w * 0.38,
    )
    ..quadraticBezierTo(cx, top + w * 0.50, cx - w * 0.23, top + w * 0.38)
    ..close();
  c.drawPath(beard, _fill(const Color(0xFFD8D4CB)));
  for (var i = -1; i <= 1; i++) {
    final strand = Path()
      ..moveTo(cx + i * w * 0.08, top + w * 0.46)
      ..quadraticBezierTo(
        cx + i * w * 0.10,
        top + w * 0.62,
        cx + i * w * 0.04,
        top + w * 0.70,
      );
    c.drawPath(
      strand,
      _stroke(const Color(0xFFA9A49A).withValues(alpha: 0.6), w * 0.012),
    );
  }

  // Face.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, top + w * 0.33),
      width: w * 0.28,
      height: w * 0.30,
    ),
    _fill(const Color(0xFFE8B58C)),
  );
  c.drawCircle(
    Offset(cx, top + w * 0.37),
    w * 0.035,
    _fill(const Color(0xFFD89A74)),
  );
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.065, top + w * 0.31),
      w * 0.018,
      _fill(_artInk),
    );
    c.drawLine(
      Offset(cx + sx * w * 0.10, top + w * 0.28),
      Offset(cx + sx * w * 0.045, top + w * 0.275),
      _stroke(const Color(0xFF7B7B7B), w * 0.014),
    );
  }

  // Hat, perched above the eyes.
  final cone = Path()
    ..moveTo(cx - w * 0.23, top + w * 0.21)
    ..quadraticBezierTo(
      cx - w * 0.06,
      top - w * 0.03,
      cx + w * 0.15,
      top + w * 0.21,
    )
    ..close();
  c.drawPath(
    cone,
    _gradient(
      cone.getBounds(),
      const Color(0xFF5B468F),
      const Color(0xFF2A2148),
    ),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.03, top + w * 0.21),
      width: w * 0.60,
      height: w * 0.105,
    ),
    _fill(const Color(0xFF352A5A)),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.03, top + w * 0.205),
      width: w * 0.56,
      height: w * 0.065,
    ),
    _fill(const Color(0xFF6B54A2)),
  );
  c.drawLine(
    Offset(cx - w * 0.20, top + w * 0.188),
    Offset(cx + w * 0.12, top + w * 0.188),
    _stroke(_artGold, w * 0.024),
  );

  // Magic.
  c.drawPath(
    _starPath(
      Rect.fromCenter(
        center: Offset(cx + w * 0.30, top + w * 0.48),
        width: w * 0.20,
        height: w * 0.20,
      ),
      inner: 0.32,
    ),
    _fill(const Color(0xFFFFE39B)),
  );
  for (final (dx, dy, s) in [
    (-0.36, 0.40, 0.05),
    (0.34, 0.62, 0.045),
    (0.18, 0.24, 0.035),
  ]) {
    c.drawCircle(
      Offset(cx + dx * w, top + dy * w),
      s * w,
      _fill(const Color(0xFFFFE9AE)),
    );
  }
}

void _drawSummonRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Feathered spell-ribbons.
  for (var i = 0; i < 3; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: Offset(cx, top + w * 0.40),
        width: w * (0.90 + i * 0.12),
        height: w * (0.58 + i * 0.10),
      ),
      math.pi * (0.15 + i * 0.12),
      math.pi * 0.95,
      false,
      _stroke(
        const Color(0xFFDFF6D8).withValues(alpha: 0.30 - i * 0.06),
        w * 0.020,
      ),
    );
  }

  // Dress.
  final dress = Path()
    ..moveTo(cx - w * 0.16, top + w * 0.48)
    ..quadraticBezierTo(
      cx - w * 0.30,
      top + w * 0.68,
      cx - w * 0.40,
      r.bottom - w * 0.02,
    )
    ..lineTo(cx + w * 0.40, r.bottom - w * 0.02)
    ..quadraticBezierTo(
      cx + w * 0.30,
      top + w * 0.68,
      cx + w * 0.16,
      top + w * 0.48,
    )
    ..close();
  c.drawPath(
    dress,
    _gradient(
      dress.getBounds(),
      const Color(0xFFE8FBFF),
      const Color(0xFF9BD4D8),
    ),
  );
  c.drawPath(
    dress,
    _stroke(const Color(0xFFFFFFFF).withValues(alpha: 0.55), w * 0.014),
  );
  // Sash and skirt folds.
  c.drawLine(
    Offset(cx - w * 0.17, top + w * 0.56),
    Offset(cx + w * 0.17, top + w * 0.56),
    _stroke(const Color(0xFF7FB86A), w * 0.030),
  );
  for (var i = -1; i <= 1; i++) {
    final fold = Path()
      ..moveTo(cx + i * w * 0.09, top + w * 0.60)
      ..quadraticBezierTo(
        cx + i * w * 0.16,
        top + w * 0.78,
        cx + i * w * 0.22,
        r.bottom - w * 0.05,
      );
    c.drawPath(fold, _stroke(Colors.white.withValues(alpha: 0.32), w * 0.012));
  }

  // Arms.
  for (final sx in [-1.0, 1.0]) {
    final arm = Path()
      ..moveTo(cx + sx * w * 0.13, top + w * 0.49)
      ..quadraticBezierTo(
        cx + sx * w * 0.28,
        top + w * 0.38,
        cx + sx * w * 0.34,
        top + w * 0.24,
      );
    c.drawPath(arm, _stroke(const Color(0xFFE8B58C), w * 0.055));
    c.drawCircle(
      Offset(cx + sx * w * 0.34, top + w * 0.22),
      w * 0.045,
      _fill(const Color(0xFFF0C7A4)),
    );
  }

  // Head and hair.
  final head = Offset(cx, top + w * 0.30);
  c.drawCircle(head, w * 0.135, _fill(const Color(0xFFE8B58C)));
  c.drawArc(
    Rect.fromCenter(center: head, width: w * 0.30, height: w * 0.30),
    math.pi * 1.02,
    math.pi * 0.96,
    false,
    _stroke(const Color(0xFF5B3526), w * 0.055),
  );
  for (var i = 0; i < 3; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: head.translate(-w * 0.06 + i * w * 0.05, w * 0.03),
        width: w * 0.26,
        height: w * 0.30,
      ),
      math.pi * 1.10,
      math.pi * 0.60,
      false,
      _stroke(const Color(0xFF7A4A32), w * 0.018),
    );
  }
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(head.dx + sx * w * 0.045, head.dy - w * 0.01),
      w * 0.016,
      _fill(_artInk),
    );
  }
  c.drawArc(
    Rect.fromCenter(
      center: head.translate(0, w * 0.03),
      width: w * 0.08,
      height: w * 0.06,
    ),
    0.2,
    math.pi - 0.4,
    false,
    _stroke(const Color(0xFF9B5A4A), w * 0.012),
  );

  // Star between raised hands.
  c.drawPath(
    _starPath(
      Rect.fromCenter(
        center: Offset(cx, top + w * 0.17),
        width: w * 0.24,
        height: w * 0.24,
      ),
      inner: 0.34,
    ),
    _fill(const Color(0xFFFFDE8A)),
  );
  c.drawCircle(
    Offset(cx, top + w * 0.17),
    w * 0.06,
    _fill(const Color(0xFFFFF3C9)),
  );

  // Birds.
  for (final (dx, dy, s, flip) in [
    (-0.34, 0.30, 0.10, 1.0),
    (0.36, 0.34, 0.09, -1.0),
    (-0.28, 0.18, 0.07, 1.0),
    (0.30, 0.20, 0.06, -1.0),
    (0.02, 0.42, 0.05, -1.0),
  ]) {
    final bx = cx + dx * w;
    final by = top + dy * w;
    final bird = Path()
      ..moveTo(bx - s * w, by)
      ..quadraticBezierTo(bx - s * w * 0.4, by - s * w * 0.9, bx, by)
      ..quadraticBezierTo(
        bx + s * w * 0.4 * flip,
        by - s * w * 0.9,
        bx + s * w,
        by,
      );
    c.drawPath(
      bird,
      _stroke(const Color(0xFF2F6B6B).withValues(alpha: 0.85), w * 0.016),
    );
  }
}

void _drawPoisonRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final top = r.top + w * 0.04;

  // Warm brew glow.
  c.drawCircle(
    Offset(cx, top + w * 0.46),
    w * 0.44,
    _fill(const Color(0xFFF3A14A).withValues(alpha: 0.18)),
  );

  // Dress.
  final dress = Path()
    ..moveTo(cx - w * 0.34, r.bottom - w * 0.02)
    ..quadraticBezierTo(
      cx - w * 0.26,
      top + w * 0.58,
      cx - w * 0.17,
      top + w * 0.46,
    )
    ..lineTo(cx + w * 0.17, top + w * 0.46)
    ..quadraticBezierTo(
      cx + w * 0.28,
      top + w * 0.60,
      cx + w * 0.34,
      r.bottom - w * 0.02,
    )
    ..close();
  c.drawPath(
    dress,
    _gradient(
      dress.getBounds(),
      const Color(0xFF5C3B5E),
      const Color(0xFF2A1E38),
    ),
  );

  // Apron.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, top + w * 0.70),
      width: w * 0.34,
      height: w * 0.40,
    ),
    _fill(const Color(0xFFEADCC3).withValues(alpha: 0.85)),
  );

  // Hair.
  for (var i = 0; i < 5; i++) {
    c.drawCircle(
      Offset(
        cx - w * 0.20 + i * w * 0.10,
        top + w * 0.30 + (i.isEven ? 0 : w * 0.03),
      ),
      w * 0.10,
      _fill(const Color(0xFFB85A2A)),
    );
  }

  // Face.
  final head = Offset(cx, top + w * 0.32);
  c.drawCircle(head, w * 0.135, _fill(const Color(0xFFE8B58C)));
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(head.dx + sx * w * 0.045, head.dy - w * 0.01),
      w * 0.015,
      _fill(_artInk),
    );
  }
  c.drawCircle(
    Offset(head.dx, head.dy + w * 0.035),
    w * 0.026,
    _fill(const Color(0xFFD89A74)),
  );
  c.drawArc(
    Rect.fromCenter(
      center: head.translate(0, w * 0.03),
      width: w * 0.07,
      height: w * 0.06,
    ),
    0.2,
    math.pi - 0.4,
    false,
    _stroke(const Color(0xFF8A3F35), w * 0.012),
  );

  // Hat.
  final cone = Path()
    ..moveTo(cx - w * 0.23, top + w * 0.22)
    ..quadraticBezierTo(
      cx - w * 0.06,
      top - w * 0.04,
      cx + w * 0.17,
      top + w * 0.22,
    )
    ..close();
  c.drawPath(
    cone,
    _gradient(
      cone.getBounds(),
      const Color(0xFF4A3348),
      const Color(0xFF1C1424),
    ),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.02, top + w * 0.22),
      width: w * 0.70,
      height: w * 0.14,
    ),
    _fill(const Color(0xFF2A1E30)),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - w * 0.02, top + w * 0.215),
      width: w * 0.64,
      height: w * 0.075,
    ),
    _fill(const Color(0xFF4A3348)),
  );
  c.drawLine(
    Offset(cx - w * 0.20, top + w * 0.195),
    Offset(cx + w * 0.14, top + w * 0.195),
    _stroke(const Color(0xFFD9A648), w * 0.024),
  );

  // Potion bottle.
  final bottle = Path()
    ..moveTo(cx - w * 0.10, top + w * 0.54)
    ..lineTo(cx - w * 0.12, top + w * 0.62)
    ..quadraticBezierTo(
      cx - w * 0.20,
      top + w * 0.72,
      cx - w * 0.10,
      top + w * 0.82,
    )
    ..quadraticBezierTo(cx, top + w * 0.88, cx + w * 0.10, top + w * 0.82)
    ..quadraticBezierTo(
      cx + w * 0.20,
      top + w * 0.72,
      cx + w * 0.12,
      top + w * 0.62,
    )
    ..lineTo(cx + w * 0.10, top + w * 0.54)
    ..close();
  c.drawPath(bottle, _fill(const Color(0xFFD94B5C)));
  c.drawPath(
    bottle,
    _stroke(const Color(0xFFF2B9C0).withValues(alpha: 0.65), w * 0.014),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, top + w * 0.52),
        width: w * 0.16,
        height: w * 0.06,
      ),
      Radius.circular(w * 0.02),
    ),
    _fill(const Color(0xFF8C5A34)),
  );
  c.drawCircle(
    Offset(cx - w * 0.04, top + w * 0.70),
    w * 0.018,
    _fill(Colors.white.withValues(alpha: 0.5)),
  );

  // Raven on the shoulder.
  final rb = Offset(cx + w * 0.26, top + w * 0.52);
  c.drawOval(
    Rect.fromCenter(center: rb, width: w * 0.16, height: w * 0.22),
    _fill(const Color(0xFF141820)),
  );
  c.drawCircle(
    rb.translate(-w * 0.03, -w * 0.10),
    w * 0.06,
    _fill(const Color(0xFF141820)),
  );
  final rbBeak = Path()
    ..moveTo(rb.dx - w * 0.07, rb.dy - w * 0.11)
    ..lineTo(rb.dx - w * 0.14, rb.dy - w * 0.09)
    ..lineTo(rb.dx - w * 0.07, rb.dy - w * 0.06)
    ..close();
  c.drawPath(rbBeak, _fill(const Color(0xFFD9A648)));
  c.drawCircle(
    rb.translate(-w * 0.045, -w * 0.11),
    w * 0.011,
    _fill(const Color(0xFFFFE9AE)),
  );
  // Wing and tail, so the raven reads as a bird even at card size.
  final rbWing = Path()
    ..moveTo(rb.dx + w * 0.01, rb.dy - w * 0.04)
    ..quadraticBezierTo(
      rb.dx + w * 0.12,
      rb.dy - w * 0.03,
      rb.dx + w * 0.10,
      rb.dy + w * 0.09,
    )
    ..quadraticBezierTo(
      rb.dx + w * 0.04,
      rb.dy + w * 0.04,
      rb.dx + w * 0.01,
      rb.dy - w * 0.04,
    )
    ..close();
  c.drawPath(rbWing, _fill(const Color(0xFF1F2A38)));
  final rbTail = Path()
    ..moveTo(rb.dx - w * 0.04, rb.dy + w * 0.09)
    ..lineTo(rb.dx - w * 0.10, rb.dy + w * 0.17)
    ..lineTo(rb.dx + w * 0.02, rb.dy + w * 0.11)
    ..close();
  c.drawPath(rbTail, _fill(const Color(0xFF141820)));

  // Brew bubbles.
  for (final (dx, dy, s) in [
    (-0.28, 0.36, 0.03),
    (0.30, 0.42, 0.025),
    (-0.22, 0.46, 0.018),
  ]) {
    c.drawCircle(
      Offset(cx + dx * w, top + dy * w),
      s * w,
      _fill(const Color(0xFFFFD98A).withValues(alpha: 0.7)),
    );
  }
}

void _drawCloakRich(Canvas c, Rect r, Color _) {
  final w = r.width;
  final cx = r.center.dx;
  final t = r.top;
  const skin = Color(0xFFE2AC84);
  const hair = Color(0xFF17171D);
  const ribbons = [
    Color(0xFFF0A8C0), // pink
    Color(0xFF8FD8F0), // sky
    Color(0xFFC7A6F0), // lavender
    Color(0xFFF3D27A), // gold
    Color(0xFF9FE8C8), // mint
    Color(0xFFF2F7FF), // near white
  ];

  // Two ribbons arcing behind the figure, over the shoulders.
  c.drawPath(
    Path()
      ..moveTo(cx - w * 0.34, t + w * 0.42)
      ..quadraticBezierTo(cx - w * 0.30, t + w * 0.02, cx + w * 0.10, t + w * 0.10),
    _stroke(ribbons[1].withValues(alpha: 0.38), w * 0.045),
  );
  c.drawPath(
    Path()
      ..moveTo(cx - w * 0.14, t + w * 0.05)
      ..quadraticBezierTo(cx + w * 0.26, t, cx + w * 0.35, t + w * 0.40),
    _stroke(ribbons[0].withValues(alpha: 0.38), w * 0.045),
  );

  // Torso: a dark charcoal shirt, shoulders to the card edge.
  final body = Path()
    ..moveTo(cx - w * 0.31, r.bottom - w * 0.01)
    ..quadraticBezierTo(
      cx - w * 0.33,
      t + w * 0.44,
      cx - w * 0.19,
      t + w * 0.355,
    )
    ..quadraticBezierTo(cx, t + w * 0.315, cx + w * 0.19, t + w * 0.355)
    ..quadraticBezierTo(
      cx + w * 0.33,
      t + w * 0.44,
      cx + w * 0.31,
      r.bottom - w * 0.01,
    )
    ..close();
  c.drawPath(
    body,
    _gradient(body.getBounds(), const Color(0xFF34343C), const Color(0xFF1C1C22)),
  );

  // Neck, face, and short dark hair.
  c.drawRect(
    Rect.fromLTWH(cx - w * 0.032, t + w * 0.285, w * 0.064, w * 0.06),
    _fill(skin),
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, t + w * 0.19),
      width: w * 0.20,
      height: w * 0.23,
    ),
    _fill(skin.withValues(alpha: 0.92)),
  );
  for (final sx in [-1.0, 1.0]) {
    c.drawCircle(
      Offset(cx + sx * w * 0.028, t + w * 0.185),
      w * 0.011,
      _fill(const Color(0xFF3A2A2A)),
    );
  }
  c.drawPath(
    Path()
      ..moveTo(cx - w * 0.105, t + w * 0.215)
      ..quadraticBezierTo(cx - w * 0.12, t + w * 0.055, cx, t + w * 0.045)
      ..quadraticBezierTo(cx + w * 0.12, t + w * 0.055, cx + w * 0.105, t + w * 0.215)
      ..quadraticBezierTo(cx, t + w * 0.13, cx - w * 0.105, t + w * 0.215)
      ..close(),
    _fill(hair),
  );

  // Swirling ribbons of pastel light wrapping the body.
  void swirl(double x0, double y0, double m1x, double m1y, double x1, double y1,
      double m2x, double m2y, double x2, double y2, Color col, double k, double a) {
    c.drawPath(
      Path()
        ..moveTo(cx + x0 * w, t + y0 * w)
        ..quadraticBezierTo(
          cx + m1x * w,
          t + m1y * w,
          cx + x1 * w,
          t + y1 * w,
        )
        ..quadraticBezierTo(cx + m2x * w, t + m2y * w, cx + x2 * w, t + y2 * w),
      _stroke(col.withValues(alpha: a), k * w),
    );
  }
  final bottom = r.bottom - t;
  swirl(-0.36, bottom - 0.02, -0.46, 0.46, -0.18, 0.375, 0.16, 0.285, 0.40, 0.42,
      ribbons[0], 0.055, 0.8);
  swirl(-0.30, bottom - 0.02, -0.34, 0.40, 0.04, 0.34, 0.30, 0.30, 0.41, 0.38,
      ribbons[1], 0.06, 0.8);
  swirl(-0.24, bottom - 0.02, -0.04, 0.33, 0.16, 0.31, 0.32, 0.31, 0.36, 0.36,
      ribbons[2], 0.05, 0.75);
  swirl(-0.34, bottom - 0.05, 0.0, 0.58, 0.34, bottom - 0.05, 0.34, bottom - 0.05,
      0.34, bottom - 0.05, ribbons[3], 0.045, 0.7);
  swirl(0.37, bottom - 0.02, 0.46, 0.46, 0.18, 0.375, -0.16, 0.285, -0.40, 0.42,
      ribbons[4], 0.055, 0.8);
  swirl(-0.29, bottom - 0.04, 0.05, 0.42, 0.30, bottom - 0.06, 0.30, bottom - 0.06,
      0.30, bottom - 0.06, ribbons[5], 0.032, 0.75);

  // Magic motes.
  for (final (dx, dy, s, col) in [
    (-0.36, 0.30, 0.020, ribbons[5]),
    (0.38, 0.24, 0.016, ribbons[4]),
    (-0.30, 0.58, 0.014, ribbons[0]),
    (0.34, 0.55, 0.020, ribbons[1]),
    (-0.02, 0.10, 0.013, ribbons[5]),
    (0.22, 0.14, 0.012, ribbons[2]),
  ]) {
    c.drawCircle(
      Offset(cx + dx * w, t + dy * w),
      s * w,
      _fill(col.withValues(alpha: 0.7)),
    );
  }
}

const Map<MagicianKind, _Drawer> _magicianRichDraw = {
  MagicianKind.vanish: _drawVanishRich,
  MagicianKind.summon: _drawSummonRich,
  MagicianKind.poison: _drawPoisonRich,
  MagicianKind.cloak: _drawCloakRich,
};

// --- Color glyphs -----------------------------------------------------------

const Map<CardColor, Color> _glyphDefault = {
  CardColor.sun: Color(0xFFE06A5F),
  CardColor.moon: Color(0xFF4FB6C9),
  CardColor.star: Color(0xFF8FBE4A),
};

typedef _GlyphDraw = void Function(
  Canvas canvas,
  Rect r,
  Color c,
  Color outline,
);

void _drawSun(Canvas c, Rect r, Color col, Color outline) {
  final cx = r.center.dx;
  final cy = r.center.dy;
  final w = r.width;
  for (var i = 0; i < 8; i++) {
    final angle = math.pi * 2 / 8 * i;
    c.drawLine(
      Offset(cx + math.cos(angle) * w * 0.28, cy + math.sin(angle) * w * 0.28),
      Offset(cx + math.cos(angle) * w * 0.44, cy + math.sin(angle) * w * 0.44),
      _stroke(col, w * 0.05),
    );
  }
  c.drawCircle(Offset(cx, cy), w * 0.24, _fill(col));
  c.drawCircle(Offset(cx, cy), w * 0.24, _stroke(outline, w * 0.025));
}

void _drawMoon(Canvas c, Rect r, Color col, Color outline) {
  final crescent = _crescentPath(r.deflate(r.width * 0.02));
  c.drawPath(crescent, _fill(col));
  c.drawPath(crescent, _stroke(outline, r.width * 0.02));
}

void _drawStar(Canvas c, Rect r, Color col, Color outline) {
  // The deck's Star mark is a four-point sparkle, not a five-point star.
  final cx = r.center.dx;
  final cy = r.center.dy;
  final s = r.shortestSide / 2;
  final sparkle = Path()
    ..moveTo(cx, cy - s)
    ..quadraticBezierTo(cx + s * 0.13, cy - s * 0.13, cx + s, cy)
    ..quadraticBezierTo(cx + s * 0.13, cy + s * 0.13, cx, cy + s)
    ..quadraticBezierTo(cx - s * 0.13, cy + s * 0.13, cx - s, cy)
    ..quadraticBezierTo(cx - s * 0.13, cy - s * 0.13, cx, cy - s)
    ..close();
  c.drawPath(sparkle, _fill(col));
  c.drawPath(sparkle, _stroke(outline, r.width * 0.02));
}

const Map<CardColor, _GlyphDraw> _glyphDraw = {
  CardColor.sun: _drawSun,
  CardColor.moon: _drawMoon,
  CardColor.star: _drawStar,
};

class _ColorGlyphPainter extends CustomPainter {
  _ColorGlyphPainter(this._draw, this._color, this._outline);
  final _GlyphDraw _draw;
  final Color _color;
  final Color _outline;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final r = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side * 0.86,
      height: side * 0.86,
    );
    _draw(canvas, r, _color, _outline);
  }

  @override
  bool shouldRepaint(covariant _ColorGlyphPainter old) =>
      old._draw != _draw || old._color != _color || old._outline != _outline;
}

/// The three card-color marks: sun, moon, or star.
class ColorGlyph extends StatelessWidget {
  const ColorGlyph({
    super.key,
    required this.color,
    this.size = 24,
    this.tint,
    this.outline,
  });
  final CardColor color;
  final double size;
  final Color? tint;

  /// The thin keyline around the mark. Defaults to the app's gold; card
  /// faces pass a pale shadow colour instead.
  final Color? outline;
  @override
  Widget build(BuildContext context) => _SizedIcon(
    size: size,
    painter: _ColorGlyphPainter(
      _glyphDraw[color]!,
      tint ?? _glyphDefault[color]!,
      outline ?? TNTTheme.gold,
    ),
  );
}
