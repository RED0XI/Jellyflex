import 'package:flutter/material.dart';

import 'core/layouts.dart';
import 'core/themes.dart';

/// Aktives Farbschema (wird aus den Einstellungen gesetzt).
AppPalette appPalette = appPalettes.first;

/// Farben des aktiven Themes – überall in der App verwendet.
abstract final class AppColors {
  static Color get background => appPalette.background;
  static Color get surface => appPalette.surface;
  static Color get surfaceHigh => appPalette.surfaceHigh;
  static Color get border => appPalette.border;
  static Color get accent => appPalette.accent;
  static Color get accentAlt => appPalette.accentAlt;
  static Color get textPrimary => appPalette.textPrimary;
  static Color get textSecondary => appPalette.textSecondary;
  static Color get textMuted => appPalette.textMuted;
  static Color get button => appPalette.button;
  static Color get onButton => appPalette.onButton;

  static LinearGradient get accentGradient => gradientOf(appPalette);

  /// Akzent-Verlauf eines bestimmten Themes (z. B. für Vorschauen).
  static LinearGradient gradientOf(AppPalette p) =>
      LinearGradient(colors: [p.accent, p.accentAlt], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

/// Schriftart der App: die des Betriebssystems (keine Downloads).
const appFontFamily = 'Segoe UI Variable Text';
const appFontFallback = ['Segoe UI', 'Arial'];

/// Horizontaler Seitenabstand, den alle Screens teilen.
const double kPageGutter = 56;

/// Höhe der eigenen Fenster-Titelleiste.
const double kTitleBarHeight = 36;

/// [key] nur, damit sich das Ergebnis bei einem Theme-/Layout-Wechsel ändert.
ThemeData buildTheme([String? key]) {
  final font = appLayout.bodyFont ?? appFontFamily;
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: appFontFallback,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
  );

  // Schrift des Systems (Windows 11: Segoe UI Variable) – nichts wird aus dem
  // Internet geladen, und die App bleibt kleiner.
  final textTheme = base.textTheme
      .apply(fontFamily: font, fontFamilyFallback: appFontFallback)
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

  return base.copyWith(
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.06),
    // Für alle Plattformen gleich (Tests melden sich z. B. als Android).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: _FadeScaleTransitionsBuilder(),
        TargetPlatform.macOS: _FadeScaleTransitionsBuilder(),
        TargetPlatform.linux: _FadeScaleTransitionsBuilder(),
        TargetPlatform.android: _FadeScaleTransitionsBuilder(),
      },
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(6)),
      textStyle: textTheme.bodySmall,
      waitDuration: const Duration(milliseconds: 500),
    ),
    // Hinweise unten (SnackBars): dunkler Kasten mit heller Schrift – Flutters Standard
    // ist dunkle Schrift auf hellem Grund, was auf eigenem dunklem Grund unlesbar wird.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      actionTextColor: AppColors.accent,
      closeIconColor: AppColors.textSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: textTheme.bodyMedium,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textMuted),
    ),
  );
}

/// Ausgangspunkt für die nächste Seite (z. B. die angeklickte Karte):
/// Die Seite wächst aus diesem Rechteck heraus und schrumpft beim Schließen
/// wieder hinein.
void expandFrom(Rect globalRect) {
  _pendingOrigin = (globalRect, DateTime.now());
}

(Rect, DateTime)? _pendingOrigin;
final _routeOrigins = Expando<Rect>('Ausgangspunkt der Seite');

/// Sanfter Übergang zwischen Seiten: einblenden + minimal heranzoomen –
/// bzw. aus der angeklickten Karte herauswachsen (siehe [expandFrom]).
class _FadeScaleTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeScaleTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Ein frisch geöffneter Ausgangspunkt gehört zur gerade aufgehenden Seite.
    final pending = _pendingOrigin;
    if (pending != null &&
        _routeOrigins[route] == null &&
        animation.status == AnimationStatus.forward &&
        DateTime.now().difference(pending.$2) < const Duration(milliseconds: 600)) {
      _routeOrigins[route] = pending.$1;
      _pendingOrigin = null;
    }
    final origin = _routeOrigins[route];
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    if (origin == null) {
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: child),
      );
    }
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final size = MediaQuery.sizeOf(context);
        final full = Offset.zero & size;
        // Ausgangspunkt in Koordinaten der Seite (die Seitenleiste verschiebt sie).
        final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
        final start = overlay is RenderBox && overlay.hasSize
            ? origin.shift(-overlay.localToGlobal(Offset.zero))
            : origin;
        final rect = Rect.lerp(start, full, t)!;
        // Inhalt in voller Größe, nur der sichtbare Ausschnitt wächst mit.
        return Opacity(
          opacity: (t * 2.2).clamp(0.0, 1.0),
          child: ClipPath(
            clipper: _RectClipper(RRect.fromRectAndRadius(rect, Radius.circular(18 * (1 - t)))),
            child: child,
          ),
        );
      },
    );
  }
}

class _RectClipper extends CustomClipper<Path> {
  _RectClipper(this.rect);

  final RRect rect;

  @override
  Path getClip(Size size) => Path()..addRRect(rect);

  @override
  bool shouldReclip(_RectClipper old) => old.rect != rect;
}
