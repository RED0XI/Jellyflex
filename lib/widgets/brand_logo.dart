import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding.dart';
import '../core/settings.dart';
import '../theme.dart';

/// App-Name mit Farbverlauf – mit eigenem Logo davor, falls in den
/// Einstellungen eins gewählt wurde.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final logo = customLogo(settings);
    final name = ShaderMask(
      shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
      child: Text(
        appDisplayName(settings),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
      ),
    );
    if (logo == null) return name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.file(
            logo,
            height: size * 1.35,
            // Nur so groß dekodieren wie nötig – auch bei riesigen Bilddateien.
            cacheHeight: (size * 1.35 * MediaQuery.devicePixelRatioOf(context)).ceil(),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        SizedBox(width: size * 0.4),
        Flexible(child: name),
      ],
    );
  }
}
