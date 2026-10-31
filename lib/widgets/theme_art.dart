import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The empty-state mark, drawn to match the active theme.
///
/// Everything is painted rather than shipped as an asset: it stays crisp at any
/// density, costs a few hundred bytes, and recolours with the palette.
class ThemeMark extends StatelessWidget {
  const ThemeMark({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mark = palette.mark;

    // Default / non-seasonal themes render the official Clearport brand logo;
    // seasonal themes render their custom painted marks.
    if (mark == ThemeMarkKind.terminal) {
      return Image.asset(
        'assets/branding/clearport-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    final glyph = switch (mark) {
      ThemeMarkKind.pumpkin => CustomPaint(
        size: Size.square(size),
        painter: PumpkinPainter(
          body: palette.accent,
          face: palette.bg,
          stem: const Color(0xFF4E7A3A),
          glow: palette.accent,
        ),
      ),
      ThemeMarkKind.snowflake => CustomPaint(
        size: Size.square(size * 0.92),
        painter: SnowflakePainter(color: palette.accent),
      ),
      ThemeMarkKind.marigold => CustomPaint(
        size: Size.square(size * 0.92),
        painter: MarigoldPainter(
          petal: palette.accent,
          centre: palette.secondary,
        ),
      ),
      ThemeMarkKind.terminal => const SizedBox.shrink(),
    };

    return SizedBox(
      width: size,
      height: size,
      child: Center(child: glyph),
    );
  }
}

/// A carved pumpkin, lit from inside.
class PumpkinPainter extends CustomPainter {
  PumpkinPainter({
    required this.body,
    required this.face,
    required this.stem,
    required this.glow,
  });

  final Color body;
  final Color face;
  final Color stem;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // Inner light: a soft halo so the pumpkin reads as glowing on pure black.
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.56),
      s * 0.46,
      Paint()
        ..color = glow.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.10),
    );

    // Body.
    final rect = Rect.fromLTWH(s * 0.07, s * 0.24, s * 0.86, s * 0.62);
    canvas.drawOval(rect, Paint()..color = body);

    // Ridges.
    final ridge = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022;
    for (final dx in [-0.17, 0.17]) {
      canvas.drawPath(
        Path()
          ..moveTo(s * (0.5 + dx * 0.35), s * 0.26)
          ..quadraticBezierTo(
            s * (0.5 + dx),
            s * 0.55,
            s * (0.5 + dx * 0.35),
            s * 0.84,
          ),
        ridge,
      );
    }

    // Stem.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.455, s * 0.28)
        ..lineTo(s * 0.49, s * 0.13)
        ..lineTo(s * 0.555, s * 0.15)
        ..lineTo(s * 0.53, s * 0.30)
        ..close(),
      Paint()..color = stem,
    );

    // Angry, slanted eyes: inner corners dropped low, outer corners high.
    final cut = Paint()..color = face;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.265, s * 0.455)
        ..lineTo(s * 0.435, s * 0.385)
        ..lineTo(s * 0.405, s * 0.505)
        ..close(),
      cut,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.735, s * 0.455)
        ..lineTo(s * 0.565, s * 0.385)
        ..lineTo(s * 0.595, s * 0.505)
        ..close(),
      cut,
    );

    // Nose.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.5, s * 0.515)
        ..lineTo(s * 0.462, s * 0.60)
        ..lineTo(s * 0.538, s * 0.60)
        ..close(),
      cut,
    );

    // A wide, toothy grin: filled crescent, then teeth cut back in body colour.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.295, s * 0.645)
        ..quadraticBezierTo(s * 0.50, s * 0.665, s * 0.705, s * 0.645)
        ..quadraticBezierTo(s * 0.665, s * 0.845, s * 0.50, s * 0.845)
        ..quadraticBezierTo(s * 0.335, s * 0.845, s * 0.295, s * 0.645)
        ..close(),
      cut,
    );
    final tooth = Paint()..color = body;
    for (final dx in [-0.085, 0.0, 0.085]) {
      canvas.drawPath(
        Path()
          ..moveTo(s * (0.5 + dx - 0.030), s * 0.658)
          ..lineTo(s * (0.5 + dx + 0.030), s * 0.658)
          ..lineTo(s * (0.5 + dx), s * 0.712)
          ..close(),
        tooth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PumpkinPainter old) =>
      old.body != body || old.face != face || old.stem != stem;
}

/// Six-armed snowflake for the Midwinter theme.
class SnowflakePainter extends CustomPainter {
  SnowflakePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final tip = c + Offset(math.cos(angle), math.sin(angle)) * (s * 0.46);
      canvas.drawLine(c, tip, paint);
      for (final branch in [0.55, 0.78]) {
        final base =
            c + Offset(math.cos(angle), math.sin(angle)) * (s * 0.46 * branch);
        for (final spread in [-0.6, 0.6]) {
          final leaf =
              base +
              Offset(math.cos(angle + spread), math.sin(angle + spread)) *
                  (s * 0.14);
          canvas.drawLine(base, leaf, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SnowflakePainter old) => old.color != color;
}

/// A marigold — the flower that guides the way home on Día de los Muertos.
class MarigoldPainter extends CustomPainter {
  MarigoldPainter({required this.petal, required this.centre});

  final Color petal;
  final Color centre;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final paint = Paint()..color = petal;

    for (var ring = 0; ring < 2; ring++) {
      final count = ring == 0 ? 8 : 6;
      final radius = s * (ring == 0 ? 0.30 : 0.19);
      final length = s * (ring == 0 ? 0.17 : 0.14);
      final offset = ring == 0 ? 0.0 : math.pi / count;
      for (var i = 0; i < count; i++) {
        final angle = (2 * math.pi / count) * i + offset;
        final centrePetal =
            c + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.save();
        canvas.translate(centrePetal.dx, centrePetal.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: length * 2,
            height: length,
          ),
          paint,
        );
        canvas.restore();
      }
    }
    canvas.drawCircle(c, s * 0.13, Paint()..color = centre);
  }

  @override
  bool shouldRepaint(covariant MarigoldPainter old) =>
      old.petal != petal || old.centre != centre;
}

/// Corner cobwebs with one spider, for the Haunted theme.
///
/// Painted once behind the empty state. [shouldRepaint] is false because the
/// colours never change while the widget lives; a theme switch rebuilds it.
class SpiderWebPainter extends CustomPainter {
  SpiderWebPainter({required this.web, required this.spider});

  final Color web;
  final Color spider;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) * 0.44;
    final line = Paint()
      ..color = web.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    _corner(canvas, const Offset(0, 0), radius, 0, math.pi / 2, line);
    _corner(
      canvas,
      Offset(size.width, 0),
      radius,
      math.pi / 2,
      math.pi / 2,
      line,
    );

    _spider(
      canvas,
      Offset(size.width * 0.80, size.height * 0.10),
      radius * 0.30,
    );
  }

  void _corner(
    Canvas canvas,
    Offset origin,
    double radius,
    double startAngle,
    double sweep,
    Paint line,
  ) {
    const strands = 7;
    for (var i = 0; i <= strands; i++) {
      final angle = startAngle + sweep * (i / strands);
      canvas.drawLine(
        origin,
        origin + Offset(math.cos(angle), math.sin(angle)) * radius,
        line,
      );
    }
    for (final scale in [0.34, 0.62, 0.92]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius * scale),
        startAngle,
        sweep,
        false,
        line,
      );
    }
  }

  void _spider(Canvas canvas, Offset at, double legSpan) {
    final body = Paint()..color = spider.withValues(alpha: 0.88);
    final thread = Paint()
      ..color = web.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    // Silk line down from the top edge.
    canvas.drawLine(Offset(at.dx, 0), at, thread);

    final leg = Paint()
      ..color = spider.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Four legs a side, each with an elbow, fanning out from the body.
    for (var i = 0; i < 4; i++) {
      for (final side in [-1.0, 1.0]) {
        final root = Offset(
          at.dx + side * legSpan * 0.12,
          at.dy + legSpan * (0.26 + i * 0.07),
        );
        final elbow = Offset(
          at.dx + side * legSpan * (0.42 + i * 0.04),
          at.dy + legSpan * (0.02 + i * 0.06),
        );
        final tip = Offset(
          at.dx + side * legSpan * (0.62 + i * 0.06),
          at.dy + legSpan * (0.28 + i * 0.15),
        );
        canvas.drawPath(
          Path()
            ..moveTo(root.dx, root.dy)
            ..lineTo(elbow.dx, elbow.dy)
            ..lineTo(tip.dx, tip.dy),
          leg,
        );
      }
    }

    // Abdomen, then head.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(at.dx, at.dy + legSpan * 0.42),
        width: legSpan * 0.55,
        height: legSpan * 0.70,
      ),
      body,
    );
    canvas.drawCircle(
      Offset(at.dx, at.dy + legSpan * 0.10),
      legSpan * 0.17,
      body,
    );
  }

  @override
  bool shouldRepaint(covariant SpiderWebPainter old) =>
      old.web != web || old.spider != spider;
}
