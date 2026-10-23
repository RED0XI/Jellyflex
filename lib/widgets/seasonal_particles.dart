import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/seasons.dart';

/// Dezente Effekte zur Saison: Herbstlaub und Fledermäuse, Schnee, Funkeln,
/// aufsteigende Herzen. Läuft endlos, reagiert nicht auf Klicks.
class SeasonalParticles extends StatefulWidget {
  const SeasonalParticles({super.key, required this.season});

  final Season season;

  @override
  State<SeasonalParticles> createState() => _SeasonalParticlesState();
}

class _SeasonalParticlesState extends State<SeasonalParticles> with SingleTickerProviderStateMixin {
  // Eine lange Schleife; jedes Teilchen hat eigene Geschwindigkeit und Phase.
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

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
              CustomPaint(painter: _ParticlePainter(widget.season, _loop.value * 60), size: Size.infinite),
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
      size = 0.5 + _r(i, 4),
      sway = _r(i, 5) * math.pi * 2,
      kind = (_r(i, 6) * 100).floor();

  final double x;
  final double phase;
  final double speed;
  final double size;
  final double sway;
  final int kind;

  static double _r(int i, int salt) => math.Random(i * 7919 + salt * 104729).nextDouble();
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.season, this.seconds);

  final Season season;

  /// Laufzeit in Sekunden (0–60, dann von vorn).
  final double seconds;

  static final _particles = List.generate(70, _Particle.new);

  @override
  void paint(Canvas canvas, Size size) {
    switch (season) {
      case Season.halloween:
        _leaves(canvas, size);
        _bats(canvas, size);
      case Season.christmas:
        _snow(canvas, size);
      case Season.newYear:
        _sparkles(canvas, size);
      case Season.valentine:
        _hearts(canvas, size);
    }
  }

  /// Position 0..1 entlang der Fallstrecke für ein Teilchen.
  double _progress(_Particle p, double cycleSeconds) => ((seconds * p.speed / cycleSeconds) + p.phase) % 1.0;

  void _snow(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final t = _progress(p, 14);
      final y = -10 + t * (size.height + 20);
      final x = p.x * size.width + math.sin(seconds * 0.8 * p.speed + p.sway) * 18;
      paint.color = Colors.white.withValues(alpha: 0.25 + 0.45 * p.size / 1.5);
      canvas.drawCircle(Offset(x, y), 1.2 + p.size * 2.2, paint);
    }
  }

  void _leaves(Canvas canvas, Size size) {
    const colors = [Color(0xFFE8822A), Color(0xFFC0471B), Color(0xFFF2B33D), Color(0xFF8E3B1F)];
    final paint = Paint();
    for (final p in _particles.take(26)) {
      final t = _progress(p, 18);
      final y = -20 + t * (size.height + 40);
      final x = p.x * size.width + math.sin(seconds * 0.6 + p.sway) * 40;
      paint.color = colors[p.kind % colors.length].withValues(alpha: 0.55);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seconds * p.speed * 1.5 + p.sway);
      final s = 4 + p.size * 4;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 2.2, height: s), paint);
      canvas.restore();
    }
  }

  void _bats(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCC14101C);
    for (var i = 0; i < 3; i++) {
      final p = _particles[i];
      // Fliegt alle ~20 s quer durchs Bild, leicht auf und ab.
      final t = ((seconds / (16 + i * 4)) + p.phase) % 1.0;
      final x = -60 + t * (size.width + 120);
      final y = size.height * (0.12 + 0.18 * i) + math.sin(t * math.pi * 6 + i) * 20;
      final flap = math.sin(seconds * 14 + i * 2);
      final w = 16.0 + i * 3;
      canvas.save();
      canvas.translate(x, y);
      final wings = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-w * 0.5, -w * 0.5 * flap - 4, -w, -w * 0.25 * flap)
        ..quadraticBezierTo(-w * 0.6, 2, -w * 0.3, 4)
        ..quadraticBezierTo(-w * 0.15, 1, 0, 5)
        ..quadraticBezierTo(w * 0.15, 1, w * 0.3, 4)
        ..quadraticBezierTo(w * 0.6, 2, w, -w * 0.25 * flap)
        ..quadraticBezierTo(w * 0.5, -w * 0.5 * flap - 4, 0, 0)
        ..close();
      canvas.drawPath(wings, paint);
      canvas.drawCircle(const Offset(0, 2), 3.5, paint);
      canvas.restore();
    }
  }

  void _sparkles(Canvas canvas, Size size) {
    for (final p in _particles.take(40)) {
      // Funkeln: an fester Stelle auf- und abblenden.
      final pulse = (math.sin(seconds * (1.5 + p.speed * 2) + p.phase * 20) + 1) / 2;
      if (pulse < 0.4) continue;
      final c = Offset(p.x * size.width, p.sway / (math.pi * 2) * size.height * 0.7);
      final r = (2 + p.size * 4) * pulse;
      final paint = Paint()..color = const Color(0xFFFFD86B).withValues(alpha: 0.75 * pulse);
      final star = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..lineTo(c.dx + r * 0.4, c.dy - r * 0.4)
        ..lineTo(c.dx + r * 2, c.dy)
        ..lineTo(c.dx + r * 0.4, c.dy + r * 0.4)
        ..lineTo(c.dx, c.dy + r * 2)
        ..lineTo(c.dx - r * 0.4, c.dy + r * 0.4)
        ..lineTo(c.dx - r * 2, c.dy)
        ..lineTo(c.dx - r * 0.4, c.dy - r * 0.4)
        ..close();
      canvas.drawPath(star, paint);
    }
  }

  void _hearts(Canvas canvas, Size size) {
    for (final p in _particles.take(24)) {
      final t = _progress(p, 16);
      final y = size.height + 20 - t * (size.height + 40);
      final x = p.x * size.width + math.sin(seconds * 0.7 + p.sway) * 24;
      final s = 5 + p.size * 6;
      final paint = Paint()..color = const Color(0xFFFF5C8A).withValues(alpha: 0.5 * (1 - t * 0.6));
      final heart = Path()
        ..moveTo(x, y + s * 0.9)
        ..cubicTo(x - s * 1.6, y - s * 0.2, x - s * 0.7, y - s * 1.3, x, y - s * 0.4)
        ..cubicTo(x + s * 0.7, y - s * 1.3, x + s * 1.6, y - s * 0.2, x, y + s * 0.9)
        ..close();
      canvas.drawPath(heart, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.seconds != seconds || old.season != season;
}
