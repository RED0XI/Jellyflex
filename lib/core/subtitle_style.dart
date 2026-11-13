import 'dart:io' show Platform;

import 'models.dart';

/// Schriften für Untertitel – nur solche, die das Betriebssystem mitbringt (keine Downloads).
enum SubtitleFont {
  standard(apple: 'Helvetica Neue', windows: 'Segoe UI'),
  clear(apple: 'Verdana', windows: 'Verdana'),
  serif(apple: 'Georgia', windows: 'Georgia'),
  mono(apple: 'Menlo', windows: 'Consolas'),
  rounded(apple: 'Arial Rounded MT Bold', windows: 'Trebuchet MS');

  const SubtitleFont({required this.apple, required this.windows});

  final String apple;
  final String windows;

  /// Name der Schrift auf diesem System (für mpv und die Vorschau).
  String get family => Platform.isMacOS || Platform.isIOS ? apple : windows;
}

/// Was den Text vom Bild abhebt.
enum SubtitleEdge { outline, thick, shadow, box, none }

/// Wählbare Textfarben (ARGB).
const subtitleColors = [0xFFFFFFFF, 0xFFFFE14D, 0xFF7FE7FF, 0xFF8CFF9E, 0xFFFFB3D1];

/// Aussehen der Untertitel. Text-Untertitel (SRT, WebVTT …) folgen allem; ASS bringt einen eigenen
/// Stil mit und folgt nur mit [forceOnStyled]; Bild-Untertitel (PGS) lassen sich nur vergrößern
/// und verschieben.
class SubtitleStyle {
  const SubtitleStyle({
    this.scale = 1.0,
    this.font = SubtitleFont.standard,
    this.bold = true,
    this.color = 0xFFFFFFFF,
    this.edge = SubtitleEdge.outline,
    this.boxOpacity = 0.7,
    this.raise = 0,
    this.forceOnStyled = false,
  });

  /// Größe (1.0 = normal).
  final double scale;
  final SubtitleFont font;
  final bool bold;

  /// Textfarbe (ARGB).
  final int color;
  final SubtitleEdge edge;

  /// Deckkraft des Kastens bei [SubtitleEdge.box] (0–1).
  final double boxOpacity;

  /// So viele Prozent der Bildhöhe weiter oben als normal (0–40).
  final int raise;

  /// Auch ASS-Untertitel in diesem Stil zeigen (kann Schilder und Effekte verschieben).
  final bool forceOnStyled;

  static const minScale = 0.6;
  static const maxScale = 2.2;
  static const maxRaise = 40;

  SubtitleStyle copyWith({
    double? scale,
    SubtitleFont? font,
    bool? bold,
    int? color,
    SubtitleEdge? edge,
    double? boxOpacity,
    int? raise,
    bool? forceOnStyled,
  }) => SubtitleStyle(
    scale: scale ?? this.scale,
    font: font ?? this.font,
    bold: bold ?? this.bold,
    color: color ?? this.color,
    edge: edge ?? this.edge,
    boxOpacity: boxOpacity ?? this.boxOpacity,
    raise: raise ?? this.raise,
    forceOnStyled: forceOnStyled ?? this.forceOnStyled,
  );

  Json toJson() => {
    'scale': scale,
    'font': font.name,
    'bold': bold,
    'color': color,
    'edge': edge.name,
    'boxOpacity': boxOpacity,
    'raise': raise,
    'forceOnStyled': forceOnStyled,
  };

  factory SubtitleStyle.fromJson(Map<String, dynamic> json) => SubtitleStyle(
    scale: ((json['scale'] as num?)?.toDouble() ?? 1.0).clamp(minScale, maxScale),
    font: SubtitleFont.values.asNameMap()[json['font']] ?? SubtitleFont.standard,
    bold: json['bold'] as bool? ?? true,
    color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
    edge: SubtitleEdge.values.asNameMap()[json['edge']] ?? SubtitleEdge.outline,
    boxOpacity: ((json['boxOpacity'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
    raise: ((json['raise'] as num?)?.toInt() ?? 0).clamp(0, maxRaise),
    forceOnStyled: json['forceOnStyled'] as bool? ?? false,
  );

  /// Eigenschaften für mpv. Die Standardwerte sind eine ruhige Systemschrift mit schmalem Rand
  /// und weichem Schatten statt der groben mpv-Vorgabe.
  ///
  /// [legacyBox]: mpv vor 0.38 (media_kit unter Windows) kennt `sub-border-style` nicht – dort
  /// entsteht der Kasten allein dadurch, dass `sub-back-color` nicht durchsichtig ist. Die Farbe
  /// darf dann nur beim Kasten gesetzt sein, sonst bekäme jeder Untertitel einen.
  Map<String, String> toMpv({bool legacyBox = false}) {
    String hex(int argb) => '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final boxAlpha = (boxOpacity * 255).round().clamp(0, 255);
    return {
      'sub-font': font.family,
      'sub-bold': bold ? 'yes' : 'no',
      'sub-font-size': '34',
      'sub-color': hex(color),
      'sub-border-color': '#E6000000',
      'sub-border-size': switch (edge) {
        SubtitleEdge.outline || SubtitleEdge.box => '1.6',
        SubtitleEdge.thick => '3.2',
        SubtitleEdge.shadow || SubtitleEdge.none => '0',
      },
      'sub-shadow-color': edge == SubtitleEdge.shadow ? '#CC000000' : '#80000000',
      'sub-shadow-offset': switch (edge) {
        SubtitleEdge.outline || SubtitleEdge.thick || SubtitleEdge.box => '1.2',
        SubtitleEdge.shadow => '2.4',
        SubtitleEdge.none => '0',
      },
      'sub-blur': '0.3',
      'sub-margin-y': '36',
      'sub-pos': '${100 - raise}',
      'sub-scale': scale.toStringAsFixed(2),
      if (!legacyBox) 'sub-border-style': edge == SubtitleEdge.box ? 'background-box' : 'outline-and-shadow',
      'sub-back-color': legacyBox && edge != SubtitleEdge.box ? '#00000000' : hex(boxAlpha << 24),
      'sub-ass-override': forceOnStyled ? 'force' : 'scale',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle &&
      other.scale == scale &&
      other.font == font &&
      other.bold == bold &&
      other.color == color &&
      other.edge == edge &&
      other.boxOpacity == boxOpacity &&
      other.raise == raise &&
      other.forceOnStyled == forceOnStyled;

  @override
  int get hashCode => Object.hash(scale, font, bold, color, edge, boxOpacity, raise, forceOnStyled);
}

/// Eigene Untertitel-Regeln einer Bibliothek (z. B. "Anime": immer Deutsch, groß und gelb).
/// `null` heißt jeweils: wie in den allgemeinen Einstellungen.
class LibrarySubtitles {
  const LibrarySubtitles({this.style, this.language});

  final SubtitleStyle? style;

  /// Sprachcode oder `subtitlesOff` (siehe settings.dart).
  final String? language;

  bool get isEmpty => style == null && language == null;

  Json toJson() => {'style': ?style?.toJson(), 'language': ?language};

  factory LibrarySubtitles.fromJson(Map<String, dynamic> json) => LibrarySubtitles(
    style: json['style'] is Map ? SubtitleStyle.fromJson((json['style'] as Map).cast<String, dynamic>()) : null,
    language: json['language'] as String?,
  );

  @override
  bool operator ==(Object other) => other is LibrarySubtitles && other.style == style && other.language == language;

  @override
  int get hashCode => Object.hash(style, language);
}
