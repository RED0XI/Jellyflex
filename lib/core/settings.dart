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

/// Qualitätsstufen (bit/s); `null` = Original ohne Umrechnung.
const qualityOptions = <(int?, String)>[
  (null, 'Original'),
  (40000000, '40 Mbit/s · 4K'),
  (20000000, '20 Mbit/s · 1080p'),
  (10000000, '10 Mbit/s · 1080p'),
  (6000000, '6 Mbit/s · 720p'),
  (3000000, '3 Mbit/s · 720p'),
  (1500000, '1,5 Mbit/s · 480p'),
];

String qualityLabel(int? bitrate) =>
    qualityOptions.where((q) => q.$1 == bitrate).firstOrNull?.$2 ?? '${(bitrate! / 1000000).toStringAsFixed(1)} Mbit/s';

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
    this.maxBitrate,
    this.bannerTrailers = true,
    this.appName,
    this.logoPath,
  });

  /// Eigener App-Name (Titelleiste, Fenstertitel, Anmeldung …); `null` = "Jellyflex".
  final String? appName;

  /// Eigenes Logo (Kopie im App-Datenordner); `null` = Standard.
  final String? logoPath;

  /// Trailer stumm im Startseiten-Banner abspielen.
  final bool bannerTrailers;

  /// Höchste Bitrate in bit/s für die Wiedergabe. `null` = Original (Direct Play).
  final int? maxBitrate;

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
    int? Function()? maxBitrate,
    bool? bannerTrailers,
    String? Function()? appName,
    String? Function()? logoPath,
  }) => AppSettings(
    audioLanguage: audioLanguage != null ? audioLanguage() : this.audioLanguage,
    subtitleLanguage: subtitleLanguage != null ? subtitleLanguage() : this.subtitleLanguage,
    autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
    nextEpisodeCountdown: nextEpisodeCountdown ?? this.nextEpisodeCountdown,
    episodeImagesInRows: episodeImagesInRows ?? this.episodeImagesInRows,
    subtitleScale: subtitleScale ?? this.subtitleScale,
    subtitleBackground: subtitleBackground ?? this.subtitleBackground,
    maxBitrate: maxBitrate != null ? maxBitrate() : this.maxBitrate,
    bannerTrailers: bannerTrailers ?? this.bannerTrailers,
    appName: appName != null ? appName() : this.appName,
    logoPath: logoPath != null ? logoPath() : this.logoPath,
  );

  Map<String, dynamic> toJson() => {
    'audioLanguage': audioLanguage,
    'subtitleLanguage': subtitleLanguage,
    'autoSkipIntro': autoSkipIntro,
    'nextEpisodeCountdown': nextEpisodeCountdown,
    'episodeImagesInRows': episodeImagesInRows,
    'subtitleScale': subtitleScale,
    'subtitleBackground': subtitleBackground,
    'maxBitrate': maxBitrate,
    'bannerTrailers': bannerTrailers,
    'appName': appName,
    'logoPath': logoPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    audioLanguage: json['audioLanguage'] as String?,
    subtitleLanguage: json['subtitleLanguage'] as String?,
    autoSkipIntro: json['autoSkipIntro'] as bool? ?? false,
    nextEpisodeCountdown: json['nextEpisodeCountdown'] as bool? ?? true,
    episodeImagesInRows: json['episodeImagesInRows'] as bool? ?? true,
    subtitleScale: (json['subtitleScale'] as num?)?.toDouble() ?? 1.0,
    subtitleBackground: json['subtitleBackground'] as bool? ?? false,
    maxBitrate: (json['maxBitrate'] as num?)?.toInt(),
    bannerTrailers: json['bannerTrailers'] as bool? ?? true,
    appName: json['appName'] as String?,
    logoPath: json['logoPath'] as String?,
  );
}

/// Ordner für Einstellungen und eigene Dateien (z. B. das eigene Logo).
Directory get appDataDir => Directory('${Platform.environment['APPDATA'] ?? Directory.systemTemp.path}\\Jellyflex');

/// Lädt/speichert die Einstellungen als JSON unter `%APPDATA%\Jellyflex\settings.json`.
class SettingsController extends Notifier<AppSettings> {
  SettingsController([this._fileOverride]);

  final File? _fileOverride;

  File get _file => _fileOverride ?? File('${appDataDir.path}\\settings.json');

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
