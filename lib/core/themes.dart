import 'package:flutter/painting.dart';

/// Ein komplettes Farbschema der App: Hintergründe, Flächen, Akzentfarben, Text.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.accent,
    required this.accentAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.button,
    required this.onButton,
  });

  /// Schlüssel zum Speichern in den Einstellungen.
  final String id;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;

  /// Hauptfarbe (Knöpfe, Fortschritt, Auswahl) und zweite Farbe für Verläufe.
  final Color accent;
  final Color accentAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Hauptknopf ("Abspielen") und Schrift darauf.
  final Color button;
  final Color onButton;
}

/// Alle Themes – das erste ist der Standard.
const appPalettes = <AppPalette>[
  // Tiefes Blauschwarz, Violett → Blau (das ursprüngliche Jellyflex-Aussehen).
  AppPalette(
    id: 'midnight',
    background: Color(0xFF0A0B10),
    surface: Color(0xFF14161F),
    surfaceHigh: Color(0xFF1E2130),
    border: Color(0xFF2A2E3F),
    accent: Color(0xFF8B5CF6),
    accentAlt: Color(0xFF00A4DC),
    textPrimary: Color(0xFFF5F6FA),
    textSecondary: Color(0xFFA3A8B8),
    textMuted: Color(0xFF6B7080),
    button: Color(0xFFEDEEF3),
    onButton: Color(0xFF0A0B10),
  ),
  // Reines Schwarz für OLED-Bildschirme, klares Weiß → Eisblau.
  AppPalette(
    id: 'oled',
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0F),
    surfaceHigh: Color(0xFF18181C),
    border: Color(0xFF26262C),
    accent: Color(0xFFE8EAF0),
    accentAlt: Color(0xFF7DD3FC),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9EA1AA),
    textMuted: Color(0xFF62656E),
    button: Color(0xFFFFFFFF),
    onButton: Color(0xFF000000),
  ),
  // Kinosaal: dunkler Samt, Rot → Orange.
  AppPalette(
    id: 'cinema',
    background: Color(0xFF0B0708),
    surface: Color(0xFF181012),
    surfaceHigh: Color(0xFF24171A),
    border: Color(0xFF3A2328),
    accent: Color(0xFFE50914),
    accentAlt: Color(0xFFFF7A3D),
    textPrimary: Color(0xFFFAF5F5),
    textSecondary: Color(0xFFB8A6A8),
    textMuted: Color(0xFF7A6668),
    button: Color(0xFFE50914),
    onButton: Color(0xFFFFFFFF),
  ),
  // Nordisch kühl: Nachtblau, Eiscyan → Lavendel.
  AppPalette(
    id: 'frost',
    background: Color(0xFF08101C),
    surface: Color(0xFF0F1A2B),
    surfaceHigh: Color(0xFF17253A),
    border: Color(0xFF243650),
    accent: Color(0xFF67E8F9),
    accentAlt: Color(0xFFA5B4FC),
    textPrimary: Color(0xFFF0F6FF),
    textSecondary: Color(0xFF9DB0C8),
    textMuted: Color(0xFF61748C),
    button: Color(0xFF67E8F9),
    onButton: Color(0xFF08101C),
  ),
  // Sonnenuntergang: dunkle Pflaume, Orange → Pink.
  AppPalette(
    id: 'sunset',
    background: Color(0xFF120A10),
    surface: Color(0xFF1F121B),
    surfaceHigh: Color(0xFF2B1A26),
    border: Color(0xFF412638),
    accent: Color(0xFFFF8A4C),
    accentAlt: Color(0xFFFF3D8B),
    textPrimary: Color(0xFFFFF5F2),
    textSecondary: Color(0xFFC4A8B4),
    textMuted: Color(0xFF86697A),
    button: Color(0xFFFF8A4C),
    onButton: Color(0xFF1A0A08),
  ),
  // 80er-Neon: tiefes Violett, Pink → Cyan.
  AppPalette(
    id: 'synthwave',
    background: Color(0xFF0C0420),
    surface: Color(0xFF170A33),
    surfaceHigh: Color(0xFF221245),
    border: Color(0xFF34205E),
    accent: Color(0xFFFF2E97),
    accentAlt: Color(0xFF00E5FF),
    textPrimary: Color(0xFFFDF4FF),
    textSecondary: Color(0xFFB9A3D6),
    textMuted: Color(0xFF7A6599),
    button: Color(0xFFFF2E97),
    onButton: Color(0xFFFFFFFF),
  ),
  // Wald bei Nacht: Smaragd → Limette.
  AppPalette(
    id: 'emerald',
    background: Color(0xFF06100C),
    surface: Color(0xFF0D1C16),
    surfaceHigh: Color(0xFF142820),
    border: Color(0xFF1F3B30),
    accent: Color(0xFF34D399),
    accentAlt: Color(0xFFBEF264),
    textPrimary: Color(0xFFF2FBF6),
    textSecondary: Color(0xFF9DB8AC),
    textMuted: Color(0xFF61796E),
    button: Color(0xFF34D399),
    onButton: Color(0xFF06100C),
  ),
  // Film noir mit Gold: warmes Schwarz, Gold → Champagner.
  AppPalette(
    id: 'noir',
    background: Color(0xFF0B0A08),
    surface: Color(0xFF17150F),
    surfaceHigh: Color(0xFF221F16),
    border: Color(0xFF3A3424),
    accent: Color(0xFFE2B04A),
    accentAlt: Color(0xFFF7DFA0),
    textPrimary: Color(0xFFFAF7EF),
    textSecondary: Color(0xFFBDB39C),
    textMuted: Color(0xFF7E7562),
    button: Color(0xFFE2B04A),
    onButton: Color(0xFF0B0A08),
  ),
];

/// Theme zu einer gespeicherten Kennung (unbekannt → Standard).
AppPalette paletteById(String? id) => appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
