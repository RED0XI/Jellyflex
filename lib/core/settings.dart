import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import 'format.dart';
import 'home_rows.dart';
import 'image_cache.dart';
import 'layouts.dart';
import '../theme.dart';
import 'themes.dart';
import 'ui_sounds.dart';
import 'platform/app_paths.dart';

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
    this.themeMusic = false,
    this.homeRows = HomeRows.all,
    this.updateCheck = false,
    this.seasonalThemes = true,
    this.ambilight = AmbilightMode.window,
    this.quizHighscore = 0,
    this.language = AppLanguage.en,
    this.themeId = 'midnight',
    this.soundEffects = true,
    this.playerVolume = 100,
    this.downloadFolder,
    this.downloadFolderAsked = false,
    this.downloadsUnmeteredOnly = true,
    this.downloadSpeedLimit = 0,
    this.downloadQuality,
    this.downloadAskOptions = true,
    this.smartDownloads = false,
    this.smartEpisodes = 2,
    this.smartMaxGb = 0,
    this.pinLockMinutes = 0,
    this.autoUpdate = true,
    this.lastSeenVersion,
    this.setupDone = true,
    this.hoverPreview = true,
  });

  /// Zuletzt eingestellte Lautstärke im Player (0–100).
  final double playerVolume;

  /// Eigener Download-Ordner; `null` = Videos\Jellyflex.
  final String? downloadFolder;

  /// Beim ersten Download wurde nach dem Ordner gefragt.
  final bool downloadFolderAsked;

  /// Nur über nicht getaktete Verbindungen (WLAN/LAN) laden – nicht über mobile Daten oder Hotspot.
  final bool downloadsUnmeteredOnly;

  /// Höchstens so viele Bytes pro Sekunde laden; 0 = unbegrenzt.
  final int downloadSpeedLimit;

  /// Höchste Bitrate für Downloads; `null` = Originaldatei.
  final int? downloadQuality;

  /// Vor jedem Download Qualität und Sprachen abfragen.
  final bool downloadAskOptions;

  /// Smart Downloads: gesehene Folgen löschen, die nächsten laden.
  final bool smartDownloads;

  /// So viele ungesehene Folgen je Serie bereithalten.
  final int smartEpisodes;

  /// Höchstens so viel Platz (GB) für Smart Downloads; 0 = unbegrenzt.
  final int smartMaxGb;

  /// Profil mit PIN nach so vielen Minuten ohne Eingabe sperren; 0 = aus.
  final int pinLockMinutes;

  /// Gefundene Updates im Hintergrund laden, prüfen und beim Beenden installieren.
  final bool autoUpdate;

  /// Version, deren Neuigkeiten zuletzt gezeigt wurden (für "Was ist neu").
  final String? lastSeenVersion;

  /// Ersteinrichtung abgeschlossen (frisch installiert: nein – dann kommt der Assistent).
  final bool setupDone;

  /// Karten blättern beim Darüberfahren durch Szenen des Titels.
  final bool hoverPreview;

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

  /// Titelmusik auf Detailseiten (Standard: aus).
  final bool themeMusic;

  /// Reihen der Startseite (Reihenfolge, "!" = ausgeblendet), siehe [HomeRows].
  final List<String> homeRows;

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
    bool? themeMusic,
    List<String>? homeRows,
    bool? updateCheck,
    bool? seasonalThemes,
    AmbilightMode? ambilight,
    int? quizHighscore,
    AppLanguage? language,
    String? themeId,
    bool? soundEffects,
    double? playerVolume,
    String? Function()? downloadFolder,
    bool? downloadFolderAsked,
    bool? downloadsUnmeteredOnly,
    int? downloadSpeedLimit,
    int? Function()? downloadQuality,
    bool? downloadAskOptions,
    bool? smartDownloads,
    int? smartEpisodes,
    int? smartMaxGb,
    int? pinLockMinutes,
    bool? autoUpdate,
    String? Function()? lastSeenVersion,
    bool? setupDone,
    bool? hoverPreview,
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
    themeMusic: themeMusic ?? this.themeMusic,
    homeRows: homeRows ?? this.homeRows,
    updateCheck: updateCheck ?? this.updateCheck,
    seasonalThemes: seasonalThemes ?? this.seasonalThemes,
    ambilight: ambilight ?? this.ambilight,
    quizHighscore: quizHighscore ?? this.quizHighscore,
    language: language ?? this.language,
    themeId: themeId ?? this.themeId,
    soundEffects: soundEffects ?? this.soundEffects,
    playerVolume: playerVolume ?? this.playerVolume,
    downloadFolder: downloadFolder != null ? downloadFolder() : this.downloadFolder,
    downloadFolderAsked: downloadFolderAsked ?? this.downloadFolderAsked,
    downloadsUnmeteredOnly: downloadsUnmeteredOnly ?? this.downloadsUnmeteredOnly,
    downloadSpeedLimit: downloadSpeedLimit ?? this.downloadSpeedLimit,
    downloadQuality: downloadQuality != null ? downloadQuality() : this.downloadQuality,
    downloadAskOptions: downloadAskOptions ?? this.downloadAskOptions,
    smartDownloads: smartDownloads ?? this.smartDownloads,
    smartEpisodes: smartEpisodes ?? this.smartEpisodes,
    smartMaxGb: smartMaxGb ?? this.smartMaxGb,
    pinLockMinutes: pinLockMinutes ?? this.pinLockMinutes,
    autoUpdate: autoUpdate ?? this.autoUpdate,
    lastSeenVersion: lastSeenVersion != null ? lastSeenVersion() : this.lastSeenVersion,
    setupDone: setupDone ?? this.setupDone,
    hoverPreview: hoverPreview ?? this.hoverPreview,
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
    'themeMusic': themeMusic,
    'homeRows': homeRows,
    'updateCheck': updateCheck,
    'seasonalThemes': seasonalThemes,
    'ambilight': ambilight.name,
    'quizHighscore': quizHighscore,
    'language': language.name,
    'themeId': themeId,
    'soundEffects': soundEffects,
    'playerVolume': playerVolume,
    'downloadFolder': downloadFolder,
    'downloadFolderAsked': downloadFolderAsked,
    'downloadsUnmeteredOnly': downloadsUnmeteredOnly,
    'downloadSpeedLimit': downloadSpeedLimit,
    'downloadQuality': downloadQuality,
    'downloadAskOptions': downloadAskOptions,
    'smartDownloads': smartDownloads,
    'smartEpisodes': smartEpisodes,
    'smartMaxGb': smartMaxGb,
    'pinLockMinutes': pinLockMinutes,
    'autoUpdate': autoUpdate,
    'lastSeenVersion': lastSeenVersion,
    'setupDone': setupDone,
    'hoverPreview': hoverPreview,
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
    themeMusic: json['themeMusic'] as bool? ?? false,
    homeRows: HomeRows.encode(HomeRows.parse([for (final r in (json['homeRows'] as List?) ?? HomeRows.all) '$r'])),
    seasonalThemes: json['seasonalThemes'] as bool? ?? true,
    ambilight: AmbilightMode.values.asNameMap()[json['ambilight']] ?? AmbilightMode.window,
    quizHighscore: (json['quizHighscore'] as num?)?.toInt() ?? 0,
    language: AppLanguage.values.asNameMap()[json['language']] ?? AppLanguage.en,
    themeId: json['themeId'] as String? ?? 'midnight',
    soundEffects: json['soundEffects'] as bool? ?? true,
    playerVolume: ((json['playerVolume'] as num?)?.toDouble() ?? 100).clamp(0, 100).toDouble(),
    downloadFolder: json['downloadFolder'] as String?,
    downloadFolderAsked: json['downloadFolderAsked'] as bool? ?? false,
    downloadsUnmeteredOnly: json['downloadsUnmeteredOnly'] as bool? ?? true,
    downloadSpeedLimit: ((json['downloadSpeedLimit'] as num?)?.toInt() ?? 0).clamp(0, 1 << 40),
    downloadQuality: (json['downloadQuality'] as num?)?.toInt(),
    downloadAskOptions: json['downloadAskOptions'] as bool? ?? true,
    smartDownloads: json['smartDownloads'] as bool? ?? false,
    smartEpisodes: ((json['smartEpisodes'] as num?)?.toInt() ?? 2).clamp(1, 10),
    smartMaxGb: ((json['smartMaxGb'] as num?)?.toInt() ?? 0).clamp(0, 100000),
    pinLockMinutes: ((json['pinLockMinutes'] as num?)?.toInt() ?? 0).clamp(0, 24 * 60),
    autoUpdate: json['autoUpdate'] as bool? ?? true,
    lastSeenVersion: json['lastSeenVersion'] as String?,
    // Ältere Versionen kannten den Assistenten nicht – wer schon Einstellungen hat, ist eingerichtet.
    setupDone: json['setupDone'] as bool? ?? true,
    hoverPreview: json['hoverPreview'] as bool? ?? true,
  );
}

/// Ordner für Einstellungen und eigene Dateien (z. B. das eigene Logo).
Directory get appDataDir => AppPaths.appData;

/// Lädt/speichert die Einstellungen als JSON unter `%APPDATA%\Jellyflex\settings.json`
/// (macOS: `~/Library/Application Support/Jellyflex/settings.json`).
class SettingsController extends Notifier<AppSettings> {
  SettingsController([this._fileOverride]);

  final File? _fileOverride;

  File get _file => _fileOverride ?? File(AppPaths.join(appDataDir.path, 'settings.json'));

  /// Gab es beim Start schon Einstellungen? (Nein = frisch installiert.)
  bool existedOnStart = false;

  @override
  AppSettings build() {
    // Tests mit eigener Einstellungsdatei bekommen auch einen eigenen Bild-Zwischenspeicher.
    if (_fileOverride case final file?) {
      ImageDiskCache.instance.directory = Directory(AppPaths.join(file.parent.path, 'images'));
    }
    try {
      existedOnStart = _file.existsSync();
      if (existedOnStart) {
        final loaded = AppSettings.fromJson(jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>);
        _apply(loaded);
        return loaded;
      }
    } catch (_) {
      // Kaputte Datei → Standardwerte.
    }
    // Frisch installiert: mit dem Einrichtungs-Assistenten beginnen.
    _apply(const AppSettings(setupDone: false));
    return const AppSettings(setupDone: false);
  }

  /// Einstellungen, die außerhalb von Widgets gelten (globale Werte).
  void _apply(AppSettings s) {
    appLanguage = s.language;
    appPalette = paletteById(s.themeId);
    appLayout = layoutById(s.layoutId);
    UiSounds.enabled = s.soundEffects;
    ImageDiskCache.instance.maxBytes = s.imageCacheMb * 1024 * 1024;
  }

  /// Aktuelle Einstellungen (auch dort lesbar, wo kein `ref` mehr verfügbar ist).
  AppSettings get current => state;

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
