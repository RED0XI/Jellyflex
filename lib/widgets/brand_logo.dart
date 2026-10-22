import 'package:flutter/material.dart';

import '../theme.dart';

/// Schriftzug "Jellyflex" mit Farbverlauf.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
      child: Text(
        'Jellyflex',
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
      ),
    );
  }
}
