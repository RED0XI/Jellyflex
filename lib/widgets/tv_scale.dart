import 'package:flutter/material.dart';

import '../core/platform/platform_info.dart';

/// Fernseher melden sich als kleiner Bildschirm (Android TV: 960×540 Punkte bei Full HD).
/// Die Oberfläche ist für Fenster ab 1024 Breite gebaut – auf dem Fernseher wird sie
/// deshalb wie auf einer 1280×720-Fläche aufgebaut und passend verkleinert gezeichnet.
/// Bilder werden weiter in der echten Bildschirmauflösung geladen.
class TvScale extends StatelessWidget {
  const TvScale({super.key, required this.child});

  /// Breite, für die die Oberfläche auf dem Fernseher aufgebaut wird.
  static const designWidth = 1280.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isTv) return child;
    final media = MediaQuery.of(context);
    final scale = media.size.width / designWidth;
    if (scale >= 1) return child;
    final size = media.size / scale;
    return MediaQuery(
      data: media.copyWith(
        size: size,
        devicePixelRatio: media.devicePixelRatio * scale,
        padding: media.padding / scale,
        viewPadding: media.viewPadding / scale,
        viewInsets: media.viewInsets / scale,
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    );
  }
}
