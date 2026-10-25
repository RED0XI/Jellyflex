import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/rating_source.dart';
import '../l10n/strings.dart';

/// Bewertungen mit dem Zeichen ihrer Quelle: IMDb bzw. TMDB fürs Publikum,
/// Tomate (frisch ab 60 %) bzw. Matsch für die Kritiker von Rotten Tomatoes.
/// Die Zeichen sind nachgezeichnet (keine Bilddateien), nur zur Kennzeichnung der Quelle.
class RatingBadges extends ConsumerWidget {
  const RatingBadges({super.key, required this.item, this.critics = true, this.spacing = 16});

  final BaseItem item;

  /// Auch die Kritiker-Wertung zeigen (im Banner nicht).
  final bool critics;
  final double spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = item.communityRating;
    final critic = critics ? item.criticRating : null;
    if (community == null && critic == null) return const SizedBox.shrink();
    final source = ratingSourceFor(item, ref.watch(ratingSourcesProvider).value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (community != null)
          Tooltip(
            message: switch (source) {
              RatingSource.imdb => tr.imdbRating,
              RatingSource.tmdb => tr.tmdbRating,
              RatingSource.unknown => tr.audienceRating,
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                switch (source) {
                  RatingSource.imdb => const ImdbLogo(),
                  RatingSource.tmdb => const TmdbLogo(),
                  RatingSource.unknown => const Icon(Icons.star_rounded, color: Color(0xFFFFC94D), size: 20),
                },
                const SizedBox(width: 6),
                Text(community.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (community != null && critic != null) SizedBox(width: spacing),
        if (critic != null)
          Tooltip(
            message: tr.rottenTomatoesRating,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TomatoIcon(fresh: critic >= 60),
                const SizedBox(width: 5),
                Text('${critic.round()} %', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Gelbes Kästchen mit "IMDb".
class ImdbLogo extends StatelessWidget {
  const ImdbLogo({super.key, this.height = 18});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: height * 0.24),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: const Color(0xFFF5C518), borderRadius: BorderRadius.circular(height * 0.18)),
    child: Text(
      'IMDb',
      style: TextStyle(
        color: Colors.black,
        fontSize: height * 0.66,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: -0.4,
        shadows: const [],
      ),
    ),
  );
}

/// "TMDB" in Dunkelblau auf dem grün-blauen Verlauf von TheMovieDb.
class TmdbLogo extends StatelessWidget {
  const TmdbLogo({super.key, this.height = 18});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: height * 0.3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF90CEA1), Color(0xFF3CBEC9), Color(0xFF01B4E4)]),
      borderRadius: BorderRadius.circular(height / 2),
    ),
    child: Text(
      'TMDB',
      style: TextStyle(
        color: const Color(0xFF0D253F),
        fontSize: height * 0.58,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0.3,
        shadows: const [],
      ),
    ),
  );
}

/// Rote Tomate mit Blättchen (frisch) oder grüner Matschfleck (durchgefallen).
class TomatoIcon extends StatelessWidget {
  const TomatoIcon({super.key, required this.fresh, this.size = 20});

  final bool fresh;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: fresh ? const _FreshTomatoPainter() : const _SplatPainter());
}

class _FreshTomatoPainter extends CustomPainter {
  const _FreshTomatoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final body = Rect.fromCenter(center: Offset(s / 2, s * 0.58), width: s * 0.92, height: s * 0.8);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFFFF6A3D), Color(0xFFFA320A), Color(0xFFD02A06)],
          stops: [0, 0.55, 1],
        ).createShader(body),
    );
    // Glanzpunkt.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.34, s * 0.44), width: s * 0.16, height: s * 0.1),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Grüner Stern aus Blättern oben.
    final leaves = Path();
    final c = Offset(s / 2, s * 0.22);
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? s * 0.24 : s * 0.08;
      final a = -math.pi / 2 + i * math.pi / points;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r * 0.7);
      i == 0 ? leaves.moveTo(p.dx, p.dy) : leaves.lineTo(p.dx, p.dy);
    }
    leaves.close();
    canvas.drawPath(leaves, Paint()..color = const Color(0xFF00912D));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplatPainter extends CustomPainter {
  const _SplatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = const Color(0xFF0AC855);
    final c = Offset(s / 2, s / 2);
    canvas.drawCircle(c, s * 0.3, paint);
    // Spritzer rundherum, unregelmäßig.
    const blobs = [
      (0.0, 0.40, 0.11),
      (1.1, 0.42, 0.08),
      (2.0, 0.38, 0.12),
      (3.0, 0.43, 0.07),
      (4.1, 0.40, 0.10),
      (5.2, 0.42, 0.08),
    ];
    for (final (angle, distance, radius) in blobs) {
      canvas.drawCircle(c + Offset(math.cos(angle), math.sin(angle)) * (s * distance), s * radius, paint);
      canvas.drawCircle(c + Offset(math.cos(angle), math.sin(angle)) * (s * distance * 0.7), s * radius * 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
