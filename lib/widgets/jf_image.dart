import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../theme.dart';

/// Breite für bildschirmfüllende Bilder in festen Stufen (für den Server-Cache).
int screenImageWidth(BuildContext context) {
  final px = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
  for (final size in const [1280, 1920, 2560]) {
    if (px <= size) return size;
  }
  return 3840;
}

/// Netzwerkbild mit BlurHash-Platzhalter und weichem Einblenden.
/// So sieht man nie leere, graue Kacheln.
class JfImage extends StatelessWidget {
  const JfImage({
    super.key,
    required this.url,
    this.blurHash,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholderColor,
    this.fallback,
  });

  final String? url;
  final String? blurHash;
  final BoxFit fit;
  final Alignment alignment;

  /// Standard: Flächenfarbe des Themes.
  final Color? placeholderColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = blurHash != null
        ? BlurHash(hash: blurHash!, imageFit: BoxFit.cover)
        : ColoredBox(color: placeholderColor ?? AppColors.surfaceHigh);

    if (url == null) {
      return Stack(fit: StackFit.expand, children: [placeholder, ?fallback]);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        Image.network(
          url!,
          fit: fit,
          alignment: alignment,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
