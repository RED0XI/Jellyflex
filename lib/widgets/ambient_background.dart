import 'package:flutter/material.dart';

import '../theme.dart';

/// Langsam wandernde Farbflächen im Hintergrund.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_anim.value);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8 + t * 0.5, -0.7 + t * 0.3),
              radius: 1.1,
              colors: [AppColors.accent.withValues(alpha: 0.28), AppColors.background.withValues(alpha: 0)],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.9 - t * 0.4, 0.8 - t * 0.3),
              radius: 1.0,
              colors: [AppColors.accentAlt.withValues(alpha: 0.20), AppColors.background.withValues(alpha: 0)],
            ),
          ),
        );
      },
    );
  }
}
