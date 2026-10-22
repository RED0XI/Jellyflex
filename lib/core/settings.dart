import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'format.dart';

/// Wählbare Sprachen (ISO 639-2, wie Jellyfin/mpv sie liefern).
const settingsLanguages = <String, String>{
  'ger': 'Deutsch',
  'eng': 'Englisch',
  'jpn': 'Japanisch',
  'fre': 'Französisch',
  'spa': 'Spanisch',
  'ita': 'Italienisch',
  'tur': 'Türkisch',
  'kor': 'Koreanisch',
  'rus': 'Russisch',
  'por': 'Portugiesisch',
  'chi': 'Chinesisch',
};

/// Sonderwert für "Untertitel standardmäßig aus".
const subtitlesOff = 'off';

/// Gleiche Sprache, egal ob "ger", "deu" oder "de".
bool sameLanguage(String? a, String? b) {
  if (a == null || b == null) return false;
  final na = languageName(a);
  return na != 'Unbekannt' && na == languageName(b);
}

class AppSettings {
  const AppSettings({
    this.audioLanguage,
    this.subtitleLanguage,
    this.autoSkipIntro = false,
    this.nextEpisodeCountdown = true,
    this.episodeImagesInRows = true,
    this.subtitleScale = 1.0,
    this.subtitleBackground = false,
  });

  /// `null` = Jellyfin-Einstellung des Benutzers verwenden.
  final String? audioLanguage;

  /// `null` = Jellyfin-Einstellung, [subtitlesOff] = aus, sonst Sprachcode.
  final String? subtitleLanguage;

  /// Intro & Rückblick automatisch überspringen (sonst nur Knopf).
  final bool autoSkipIntro;

  /// Am Ende einer Folge automatisch die nächste starten (mit Countdown).
  final bool nextEpisodeCountdown;

  /// Bei "Weiterschauen" das Standbild der Folge statt des Serienbilds zeigen.
  final bool episodeImagesInRows;

  /// Untertitelgröße (1.0 = normal).
  final double subtitleScale;

  /// Untertitel auf halbtransparentem Kasten (besser lesbar).
  final bool subtitleBackground;

  AppSettings copyWith({
    String? Function()? audioLanguage,
    String? Function()? subtitleLanguage,
    bool? autoSkipIntro,
    bool? nextEpisodeCountdown,
    bool? episodeImagesInRows,
    double? subtitleScale,
    bool? subtitleBackground,
  }) => AppSettings(
    audioLanguage: audioLanguage != null ? audioLanguage() : this.audioLanguage,
    subtitleLanguage: subtitleLanguage != null ? subtitleLanguage() : this.subtitleLanguage,
    autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
    nextEpisodeCountdown: nextEpisodeCountdown ?? this.nextEpisodeCountdown,
    episodeImagesInRows: episodeImagesInRows ?? this.episodeImagesInRows,
    subtitleScale: subtitleScale ?? this.subtitleScale,
    subtitleBackground: subtitleBackground ?? this.subtitleBackground,
  );

  Map<String, dynamic> toJson() => {
    'audioLanguage': audioLanguage,
    'subtitleLanguage': subtitleLanguage,
    'autoSkipIntro': autoSkipIntro,
    'nextEpisodeCountdown': nextEpisodeCountdown,
    'episodeImagesInRows': episodeImagesInRows,
    'subtitleScale': subtitleScale,
    'subtitleBackground': subtitleBackground,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    audioLanguage: json['audioLanguage'] as String?,
    subtitleLanguage: json['subtitleLanguage'] as String?,
    autoSkipIntro: json['autoSkipIntro'] as bool? ?? false,
    nextEpisodeCountdown: json['nextEpisodeCountdown'] as bool? ?? true,
    episodeImagesInRows: json['episodeImagesInRows'] as bool? ?? true,
    subtitleScale: (json['subtitleScale'] as num?)?.toDouble() ?? 1.0,
    subtitleBackground: json['subtitleBackground'] as bool? ?? false,
  );
}

/// Lädt/speichert die Einstellungen als JSON unter `%APPDATA%\Jellyflex\settings.json`.
class SettingsController extends Notifier<AppSettings> {
  SettingsController([this._fileOverride]);

  final File? _fileOverride;

  File get _file =>
      _fileOverride ??
      File('${Platform.environment['APPDATA'] ?? Directory.systemTemp.path}\\Jellyflex\\settings.json');

  @override
  AppSettings build() {
    try {
      if (_file.existsSync()) {
        return AppSettings.fromJson(jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>);
      }
    } catch (_) {
      // Kaputte Datei → Standardwerte.
    }
    return const AppSettings();
  }

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state.toJson()));
    } catch (_) {
      // Speichern fehlgeschlagen – Einstellung gilt trotzdem für diese Sitzung.
    }
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
