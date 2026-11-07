import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Das Zeichen von Jellyflex (wie das App-Icon): ein weiches Play-Dreieck mit Glanzlicht und zwei
/// "Sende"-Bögen an der Spitze – als Vektor, in den Farben des Themes. Statisch im Logo, animiert
/// im Intro ([BrandMarkPainter] mit Fortschrittswerten).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: BrandMarkPainter(colors: brandMarkColors())),
    );
  }
}

/// Verlauf des Zeichens: hell oben links → Themenfarbe → zweite Themenfarbe unten rechts.
List<Color> brandMarkColors() => [
  Color.lerp(AppColors.accent, Colors.white, 0.35)!,
  AppColors.accent,
  AppColors.accentAlt,
];

/// Zeichnet das Zeichen in ein Quadrat. Alle Werte 0…1:
/// [draw] Kontur (zeichnet sich nach und nach), [fill] Füllung, [shine] Lichtstreif, der einmal
/// darüber huscht (außerhalb 0…1: keiner), [highlight] ruhiges Glanzlicht, [arc1]/[arc2] die Bögen,
/// [glow] Leuchten um das Zeichen.
class BrandMarkPainter extends CustomPainter {
  BrandMarkPainter({
    required this.colors,
    this.draw = 1,
    this.fill = 1,
    this.shine = -1,
    this.highlight = 1,
    this.arc1 = 1,
    this.arc2 = 1,
    this.glow = 0,
  });

  final List<Color> colors;
  final double draw;
  final double fill;
  final double shine;
  final double highlight;
  final double arc1;
  final double arc2;
  final double glow;

  /// Weiches Dreieck im Einheitsquadrat (leicht gewölbte Seiten, abgerundete Ecken).
  static Path _triangle(double s) {
    Offset p(double x, double y) => Offset(x * s, y * s);
    final top = p(0.17, 0.13);
    final bottom = p(0.17, 0.87);
    final tip = p(0.80, 0.50);
    const r = 0.085;
    Offset towards(Offset from, Offset to, double d) => from + (to - from) * (d * s / (to - from).distance);
    final path = Path()..moveTo(towards(top, tip, r).dx, towards(top, tip, r).dy);
    void edge(Offset from, Offset to, Offset control) {
      final end = towards(to, from, r);
      path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }

    void corner(Offset at, Offset next) {
      final end = towards(at, next, r);
      path.quadraticBezierTo(at.dx, at.dy, end.dx, end.dy);
    }

    edge(top, tip, p(0.53, 0.17));
    corner(tip, bottom);
    edge(tip, bottom, p(0.53, 0.83));
    corner(bottom, top);
    edge(bottom, top, p(0.12, 0.50));
    corner(top, tip);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final triangle = _triangle(s);
    final bounds = Offset.zero & Size(s, s);
    final gradient = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, colors, const [0, 0.5, 1]);

    if (glow > 0) {
      canvas.drawPath(
        triangle,
        Paint()
          ..shader = gradient
          ..color = Colors.white.withValues(alpha: 0.55 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12),
      );
    }

    if (fill > 0) {
      canvas.drawPath(
        triangle,
        Paint()
          ..shader = gradient
          ..color = Colors.white.withValues(alpha: fill.clamp(0, 1)),
      );
    }

    // Kontur, die sich zeichnet (verschwindet mit der Füllung).
    if (draw > 0 && fill < 1) {
      final stroke = Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 1 - fill.clamp(0, 1));
      final drawn = Path();
      for (final metric in triangle.computeMetrics()) {
        drawn.addPath(metric.extractPath(0, metric.length * draw.clamp(0, 1)), Offset.zero);
      }
      canvas.drawPath(drawn, stroke);
    }

    // Ruhiges Glanzlicht oben links (wie im Icon).
    if (highlight > 0 && fill > 0) {
      final shape = Path()
        ..moveTo(0.26 * s, 0.24 * s)
        ..quadraticBezierTo(0.48 * s, 0.24 * s, 0.62 * s, 0.33 * s)
        ..quadraticBezierTo(0.42 * s, 0.33 * s, 0.26 * s, 0.47 * s)
        ..close();
      canvas.drawPath(
        shape,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0.26 * s, 0.24 * s), Offset(0.5 * s, 0.45 * s), [
            Colors.white.withValues(alpha: 0.55 * highlight * fill),
            Colors.white.withValues(alpha: 0),
          ]),
      );
    }

    // Lichtstreif, der einmal schräg darüber huscht.
    if (shine >= 0 && shine <= 1) {
      canvas.save();
      canvas.clipPath(triangle);
      final x = (-0.4 + 1.8 * shine) * s;
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x - 0.3 * s, 0),
            Offset(x + 0.25 * s, 0.3 * s),
            [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.8), Colors.white.withValues(alpha: 0)],
            const [0, 0.5, 1],
          ),
      );
      canvas.restore();
    }

    // Zwei Bögen an der Spitze – wachsen aus ihr heraus.
    void arc(double t, double radius, Color color) {
      if (t <= 0) return;
      final center = Offset(0.78 * s, 0.5 * s);
      final r = radius * s * (0.6 + 0.4 * t);
      const sweep = math.pi * 0.42;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -sweep / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: color.a * t.clamp(0, 1)),
      );
    }

    arc(arc1, 0.13, Color.lerp(colors.first, Colors.white, 0.3)!);
    arc(arc2, 0.23, Colors.white.withValues(alpha: 0.28));
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.draw != draw ||
      old.fill != fill ||
      old.shine != shine ||
      old.highlight != highlight ||
      old.arc1 != arc1 ||
      old.arc2 != arc2 ||
      old.glow != glow ||
      old.colors != colors;
}
