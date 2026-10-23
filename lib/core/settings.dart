import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import 'format.dart';
import 'image_cache.dart';
import 'layouts.dart';
import '../theme.dart';
import 'themes.dart';
import 'ui_sounds.dart';

/// Wählbare Sprachen für Ton und Untertitel (ISO 639-2, wie Jellyfin/mpv sie liefern).
const settingsLanguages = ['ger', 'eng', 'jpn', 'fre', 'spa', 'ita', 'tur', 'kor', 'rus', 'por', 'chi'];

/// Qualitätsstufen (bit/s); `null` = Original ohne Umrechnung.
List<(int?, String)> get qualityOptions => [
  (null, tr.original),
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
  final ka = languageKey(a);
  return ka != null && ka == languageKey(b);
}

/// Ambilight: aus, nur im Fenster oder auch im Vollbild.
enum AmbilightMode { off, window, always }

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
    this.screensaverMinutes = 5,
    this.imageCacheMb = 300,
    this.layoutId = 'cinema',
    this.recentSearches = const [],
    this.updateCheck = false,
    this.seasonalThemes = true,
    this.ambilight = AmbilightMode.window,
    this.quizHighscore = 0,
    this.language = AppLanguage.en,
    this.themeId = 'midnight',
    this.soundEffects = true,
  });

  /// Klänge bei "Überrasch mich" und im Quiz.
  final bool soundEffects;

  /// Farbschema (siehe lib/core/themes.dart).
  final String themeId;

  /// Sprache der Oberfläche (Standard: Englisch).
  final AppLanguage language;

  /// Bester Punktestand im Film-Quiz.
  final int quizHighscore;

  /// Farbiges Leuchten aus dem Bild in den schwarzen Balken neben/über dem Video.
  final AmbilightMode ambilight;

  /// Halloween, Weihnachten … mit passender Reihe und kleinen Effekten.
  final bool seasonalThemes;

  /// Bildschirmschoner nach so vielen Minuten ohne Eingabe; 0 = aus.
  final int screensaverMinutes;

  /// Obergrenze des Bild-Zwischenspeichers auf der Festplatte (MB, 0 = aus).
  final int imageCacheMb;

  /// Layout (Aufbau der Oberfläche), siehe [appLayouts].
  final String layoutId;

  /// Letzte Suchbegriffe (nur auf diesem Gerät, höchstens 8).
  final List<String> recentSearches;

  /// Beim Start nach einer neuen Version fragen (Standard: aus).
  final bool updateCheck;

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
    int? screensaverMinutes,
    int? imageCacheMb,
    String? layoutId,
    List<String>? recentSearches,
    bool? updateCheck,
    bool? seasonalThemes,
    AmbilightMode? ambilight,
    int? quizHighscore,
    AppLanguage? language,
    String? themeId,
    bool? soundEffects,
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
    screensaverMinutes: screensaverMinutes ?? this.screensaverMinutes,
    imageCacheMb: imageCacheMb ?? this.imageCacheMb,
    layoutId: layoutId ?? this.layoutId,
    recentSearches: recentSearches ?? this.recentSearches,
    updateCheck: updateCheck ?? this.updateCheck,
    seasonalThemes: seasonalThemes ?? this.seasonalThemes,
    ambilight: ambilight ?? this.ambilight,
    quizHighscore: quizHighscore ?? this.quizHighscore,
    language: language ?? this.language,
    themeId: themeId ?? this.themeId,
    soundEffects: soundEffects ?? this.soundEffects,
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
    'screensaverMinutes': screensaverMinutes,
    'imageCacheMb': imageCacheMb,
    'layoutId': layoutId,
    'recentSearches': recentSearches,
    'updateCheck': updateCheck,
    'seasonalThemes': seasonalThemes,
    'ambilight': ambilight.name,
    'quizHighscore': quizHighscore,
    'language': language.name,
    'themeId': themeId,
    'soundEffects': soundEffects,
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
    screensaverMinutes: (json['screensaverMinutes'] as num?)?.toInt() ?? 5,
    imageCacheMb: ((json['imageCacheMb'] as num?)?.toInt() ?? 300).clamp(0, 5000),
    updateCheck: json['updateCheck'] as bool? ?? false,
    layoutId: json['layoutId'] as String? ?? 'cinema',
    recentSearches: [
      for (final s in (json['recentSearches'] as List?) ?? const [])
        if (s is String && s.trim().isNotEmpty) s.trim(),
    ].take(8).toList(),
    seasonalThemes: json['seasonalThemes'] as bool? ?? true,
    ambilight: AmbilightMode.values.asNameMap()[json['ambilight']] ?? AmbilightMode.window,
    quizHighscore: (json['quizHighscore'] as num?)?.toInt() ?? 0,
    language: AppLanguage.values.asNameMap()[json['language']] ?? AppLanguage.en,
    themeId: json['themeId'] as String? ?? 'midnight',
    soundEffects: json['soundEffects'] as bool? ?? true,
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
    // Tests mit eigener Einstellungsdatei bekommen auch einen eigenen Bild-Zwischenspeicher.
    if (_fileOverride case final file?) ImageDiskCache.instance.directory = Directory('${file.parent.path}\\images');
    try {
      if (_file.existsSync()) {
        final loaded = AppSettings.fromJson(jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>);
        _apply(loaded);
        return loaded;
      }
    } catch (_) {
      // Kaputte Datei → Standardwerte.
    }
    _apply(const AppSettings());
    return const AppSettings();
  }

  /// Einstellungen, die außerhalb von Widgets gelten (globale Werte).
  void _apply(AppSettings s) {
    appLanguage = s.language;
    appPalette = paletteById(s.themeId);
    appLayout = layoutById(s.layoutId);
    UiSounds.enabled = s.soundEffects;
    ImageDiskCache.instance.maxBytes = s.imageCacheMb * 1024 * 1024;
  }

  void update(AppSettings Function(AppSettings s) change) {
    final next = change(state);
    _apply(next);
    if (next.imageCacheMb < state.imageCacheMb) ImageDiskCache.instance.trim();
    state = next;
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state.toJson()));
    } catch (_) {
      // Speichern fehlgeschlagen – Einstellung gilt trotzdem für diese Sitzung.
    }
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
