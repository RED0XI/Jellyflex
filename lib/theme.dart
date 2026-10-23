import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Horizontaler Seitenabstand, den alle Screens teilen.
const double kPageGutter = 56;

/// Höhe der eigenen Fenster-Titelleiste.
const double kTitleBarHeight = 36;

/// [themeId] nur, damit sich das Ergebnis bei einem Theme-Wechsel ändert.
ThemeData buildTheme([String? themeId]) {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

  return base.copyWith(
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.06),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.windows: _FadeScaleTransitionsBuilder()},
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(6)),
      textStyle: textTheme.bodySmall,
      waitDuration: const Duration(milliseconds: 500),
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

/// Sanfter Übergang zwischen Seiten: einblenden + minimal heranzoomen.
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
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: child),
    );
  }
}
