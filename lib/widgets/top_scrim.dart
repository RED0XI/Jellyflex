import 'package:flutter/material.dart';

import '../theme.dart';

/// Dunkler Verlauf unter der Titelleiste, der beim Scrollen einblendet –
/// damit Inhalte nicht unter Zurück-Pfeil und Fensterknöpfen "durchscheinen".
class TopScrim extends StatelessWidget {
  const TopScrim({super.key, required this.scroll, this.height});

  final ScrollController scroll;

  /// Standard: Titelleiste (auf iPhone/iPad mit Statusleiste) und etwas Luft.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height ?? topInset(context) + 28,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: scroll,
          builder: (context, _) {
            final offset = scroll.hasClients ? scroll.offset : 0.0;
            final t = (offset / 120).clamp(0.0, 1.0);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.6, 1],
                  colors: [
                    AppColors.background.withValues(alpha: 0.95 * t),
                    AppColors.background.withValues(alpha: 0.8 * t),
                    AppColors.background.withValues(alpha: 0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
