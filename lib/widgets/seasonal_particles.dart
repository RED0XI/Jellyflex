import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/seasons.dart';

/// Dezente Effekte zur Saison über dem Banner: Halloween mit Nebel, Glut und Herbstlaub,
/// Weihnachten mit Schnee in drei Tiefen, Silvester mit goldenen Lichtern, Valentinstag
/// mit weichen Herzen. Läuft endlos, reagiert nicht auf Klicks.
class SeasonalParticles extends StatefulWidget {
  const SeasonalParticles({super.key, required this.season});

  final Season season;

  @override
  State<SeasonalParticles> createState() => _SeasonalParticlesState();
}

class _SeasonalParticlesState extends State<SeasonalParticles> with SingleTickerProviderStateMixin {
  // Eine lange Schleife; jedes Teilchen hat eigene Geschwindigkeit und Phase.
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) =>
              CustomPaint(painter: _ParticlePainter(widget.season, _loop.value * 120), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle(int i)
    : x = _r(i, 1),
      phase = _r(i, 2),
      speed = 0.35 + _r(i, 3) * 0.65,
      size = _r(i, 4),
      sway = _r(i, 5) * math.pi * 2,
      kind = (_r(i, 6) * 100).floor();

  final double x;
  final double phase;
  final double speed;

  /// 0..1 – auch "Nähe" (große Teilchen sind näher, schneller, unschärfer).
  final double size;
  final double sway;
  final int kind;

  static double _r(int i, int salt) => math.Random(i * 7919 + salt * 104729).nextDouble();
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.season, this.seconds);

  final Season season;

  /// Laufzeit in Sekunden (0–120, dann von vorn).
  final double seconds;

  static final _particles = List.generate(80, _Particle.new);

  @override
  void paint(Canvas canvas, Size size) {
    switch (season) {
      case Season.halloween:
        _mist(canvas, size, const [Color(0xFF5B2A86), Color(0xFFE8822A), Color(0xFF2B1A4A)]);
        _leaves(canvas, size);
        _embers(canvas, size);
      case Season.christmas:
        _glow(canvas, size, const Color(0xFF9CC9FF), Alignment.topCenter);
        _snow(canvas, size);
      case Season.newYear:
        _glow(canvas, size, const Color(0xFFFFC857), Alignment.topRight);
        _bokeh(canvas, size, const [Color(0xFFFFD86B), Color(0xFFFFF1C1), Color(0xFFE8B04A)]);
        _sparkles(canvas, size);
      case Season.valentine:
        _bokeh(canvas, size, const [Color(0xFFFF5C8A), Color(0xFFFF9EBB), Color(0xFFB83B6B)]);
        _hearts(canvas, size);
    }
  }

  /// Position 0..1 entlang der Strecke für ein Teilchen.
  double _progress(_Particle p, double cycleSeconds) => ((seconds * p.speed / cycleSeconds) + p.phase) % 1.0;

  /// Großes weiches Leuchten aus einer Ecke.
  void _glow(Canvas canvas, Size size, Color color, Alignment from) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: from,
          radius: 0.9,
          colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  /// Langsam treibender Nebel aus großen, sehr unscharfen Flecken im unteren Bereich.
  void _mist(Canvas canvas, Size size, List<Color> colors) {
    for (var i = 0; i < 6; i++) {
      final p = _particles[i];
      final t = ((seconds / (90 + i * 15)) + p.phase) % 1.0;
      final x = -0.2 * size.width + t * size.width * 1.4;
      final y = size.height * (0.55 + 0.35 * p.size);
      final r = 160 + p.size * 200;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.10 + 0.06 * math.sin(seconds * 0.2 + i))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// Glut-Funken, die von unten aufsteigen und verglimmen.
  void _embers(Canvas canvas, Size size) {
    for (final p in _particles.skip(10).take(34)) {
      final t = _progress(p, 22);
      final y = size.height + 10 - t * size.height * 0.9;
      final x = p.x * size.width + math.sin(seconds * 0.9 * p.speed + p.sway) * 22;
      final fade = (1 - t) * (0.6 + 0.4 * math.sin(seconds * 6 * p.speed + p.phase * 9));
      final r = 1.0 + p.size * 1.8;
      final color = Color.lerp(const Color(0xFFFFB347), const Color(0xFFFF5A1F), p.size)!;
      canvas.drawCircle(
        Offset(x, y),
        r * 3,
        Paint()
          ..color = color.withValues(alpha: 0.18 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2.5),
      );
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color.withValues(alpha: 0.85 * fade));
    }
  }

  /// Wenige fallende Blätter in gedeckten Herbstfarben, mit Blattform und Mittelrippe.
  void _leaves(Canvas canvas, Size size) {
    const colors = [Color(0xFFB5541C), Color(0xFF8C3A1A), Color(0xFFC98B2B), Color(0xFF6E2E1A)];
    for (final p in _particles.skip(50).take(10)) {
      final t = _progress(p, 26);
      final y = -30 + t * (size.height + 60);
      final x = p.x * size.width + math.sin(seconds * 0.5 + p.sway) * 50;
      final s = 7 + p.size * 7;
      final color = colors[p.kind % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(seconds * 0.8 * p.speed + p.sway) * 1.2);
      // Leichtes Kippen im Fall: Breite schwankt.
      canvas.scale(0.55 + 0.45 * math.cos(seconds * p.speed + p.phase * 6).abs(), 1);
      final leaf = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.9, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.9, -s * 0.2, 0, -s)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
      canvas.drawLine(
        Offset(0, -s * 0.9),
        Offset(0, s * 1.2),
        Paint()
          ..color = const Color(0x553A1A0E)
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    }
  }

  /// Schnee in drei Tiefen: ferne Flocken klein und langsam, nahe groß, schneller und weich.
  void _snow(Canvas canvas, Size size) {
    for (final p in _particles) {
      final near = p.size;
      final t = _progress(p, 26 - near * 12);
      final y = -10 + t * (size.height + 20);
      final x = p.x * size.width + math.sin(seconds * (0.4 + near * 0.6) + p.sway) * (10 + near * 22);
      final r = 0.8 + near * near * 4.2;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.25 + 0.4 * (1 - near * 0.4));
      if (near > 0.7) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// Weiche, runde Lichtpunkte (Bokeh), die langsam nach oben treiben.
  void _bokeh(Canvas canvas, Size size, List<Color> colors) {
    for (final p in _particles.take(16)) {
      final t = _progress(p, 60);
      final y = size.height * (1.05 - t * 1.1);
      final x = p.x * size.width + math.sin(seconds * 0.15 + p.sway) * 40;
      final r = 14 + p.size * 34;
      final fade = math.sin(t * math.pi);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = colors[p.kind % colors.length].withValues(alpha: 0.10 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
      );
    }
  }

  void _sparkles(Canvas canvas, Size size) {
    for (final p in _particles.skip(20).take(36)) {
      // Funkeln: an fester Stelle auf- und abblenden.
      final pulse = (math.sin(seconds * (1.2 + p.speed * 1.6) + p.phase * 20) + 1) / 2;
      if (pulse < 0.45) continue;
      final c = Offset(p.x * size.width, p.sway / (math.pi * 2) * size.height * 0.75);
      final r = (1.5 + p.size * 3) * pulse;
      final color = const Color(0xFFFFE08A);
      canvas.drawCircle(
        c,
        r * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.25 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
      );
      final star = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..lineTo(c.dx + r * 0.3, c.dy - r * 0.3)
        ..lineTo(c.dx + r * 2, c.dy)
        ..lineTo(c.dx + r * 0.3, c.dy + r * 0.3)
        ..lineTo(c.dx, c.dy + r * 2)
        ..lineTo(c.dx - r * 0.3, c.dy + r * 0.3)
        ..lineTo(c.dx - r * 2, c.dy)
        ..lineTo(c.dx - r * 0.3, c.dy - r * 0.3)
        ..close();
      canvas.drawPath(star, Paint()..color = color.withValues(alpha: 0.8 * pulse));
    }
  }

  void _hearts(Canvas canvas, Size size) {
    for (final p in _particles.skip(30).take(16)) {
      final t = _progress(p, 20);
      final y = size.height + 20 - t * (size.height + 40);
      final x = p.x * size.width + math.sin(seconds * 0.6 + p.sway) * 26;
      final s = 4 + p.size * 7;
      final heart = Path()
        ..moveTo(x, y + s * 0.9)
        ..cubicTo(x - s * 1.6, y - s * 0.2, x - s * 0.7, y - s * 1.3, x, y - s * 0.4)
        ..cubicTo(x + s * 0.7, y - s * 1.3, x + s * 1.6, y - s * 0.2, x, y + s * 0.9)
        ..close();
      canvas.drawPath(
        heart,
        Paint()
          ..color = const Color(0xFFFF6F98).withValues(alpha: 0.45 * math.sin(t * math.pi))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size > 0.6 ? 1.6 : 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.seconds != seconds || old.season != season;
}
