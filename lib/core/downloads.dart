import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell.dart';
import 'download_folder.dart';
import 'platform/app_paths.dart';
import 'images.dart';
import 'jellyfin_api.dart';
import 'models.dart';
import 'session.dart';
import 'settings.dart';
import '../l10n/strings.dart';

enum DownloadStatus { queued, downloading, paused, done, failed }

/// Wie ein Titel heruntergeladen wird: Qualität und (bei kleinerer Fassung) Sprachen.
class DownloadOptions {
  const DownloadOptions({this.maxBitrate, this.audioLanguage, this.subtitleLanguages});

  /// Höchste Bitrate (bit/s); `null` = Originaldatei mit allen Ton- und Untertitelspuren.
  final int? maxBitrate;

  /// Tonspur der kleineren Fassung; `null` = wie beim Abspielen bevorzugt.
  final String? audioLanguage;

  /// Untertitel, die als Datei mitgeladen werden; `null` = alle.
  final List<String>? subtitleLanguages;
}

/// Ein heruntergeladener (oder herunterladender) Titel.
class DownloadEntry {
  const DownloadEntry({
    required this.itemId,
    required this.serverUrl,
    required this.userId,
    required this.name,
    required this.type,
    required this.folder,
    this.seriesName,
    this.seriesId,
    this.episodeLabel,
    this.sortIndex,
    this.mediaSourceId,
    this.status = DownloadStatus.queued,
    this.received = 0,
    this.total = 0,
    this.mediaFile,
    this.error,
    this.positionTicks = 0,
    this.played = false,
    this.watchedAt,
    this.needsSync = false,
    this.maxBitrate,
    this.audioLanguage,
    this.subtitleLanguages,
    this.converted = false,
    this.audioIndex,
    this.auto = false,
    this.expectedSize = 0,
  });

  final String itemId;
  final String serverUrl;
  final String userId;
  final String name;
  final String type;
  final String? seriesName;
  final String? seriesId;
  final String? episodeLabel;

  /// Reihenfolge innerhalb der Serie (Staffel × 10000 + Folge) – für Smart Downloads.
  final int? sortIndex;

  /// Heruntergeladene Fassung (bei mehreren Versionen), sonst `null` = erste.
  final String? mediaSourceId;

  /// Ordner mit Video, Infos (item.json) und Bildern.
  final String folder;
  final DownloadStatus status;
  final int received;

  /// Gesamtgröße; bei umgerechneten Fassungen bis zum Ende nur geschätzt.
  final int total;

  /// Fertige Videodatei (erst nach Abschluss gesetzt).
  final String? mediaFile;
  final String? error;

  /// Zuletzt lokal geschaute Stelle (auch ohne Verbindung zum Server).
  final int positionTicks;
  final bool played;
  final DateTime? watchedAt;

  /// Lokaler Fortschritt wurde noch nicht an den Server gemeldet.
  final bool needsSync;

  /// Gewünschte Qualität und Sprachen (siehe [DownloadOptions]).
  final int? maxBitrate;
  final String? audioLanguage;
  final List<String>? subtitleLanguages;

  /// Der Server hat eine kleinere Fassung erzeugt (nur eine Tonspur, Untertitel als Dateien).
  final bool converted;

  /// Jellyfin-Index der Tonspur in der umgerechneten Fassung.
  final int? audioIndex;

  /// Von Smart Downloads geladen (zählt zu deren Speichergrenze).
  final bool auto;

  /// Geschätzte Größe beim Vormerken (für die Speichergrenze, solange noch nichts geladen ist).
  final int expectedSize;

  /// Eindeutig je Konto: derselbe Titel kann von zwei Konten geladen sein.
  String get key => '$serverUrl|$userId|$itemId';

  double get progress => total > 0 ? (received / total).clamp(0, 1).toDouble() : 0;
  bool get isDone => status == DownloadStatus.done && mediaFile != null;
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  /// Belegter (bzw. am Ende belegter) Platz.
  int get sizeOnDisk => isDone ? total : received;

  String get posterPath => '$folder${Platform.pathSeparator}poster.jpg';
  String get backdropPath => '$folder${Platform.pathSeparator}backdrop.jpg';
  String get itemJsonPath => '$folder${Platform.pathSeparator}item.json';

  /// Mitgeladene Untertiteldatei für den Jellyfin-Streamindex.
  String? subtitleFile(int streamIndex) {
    try {
      final prefix = 'subtitle_$streamIndex.';
      return Directory(folder)
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith(prefix))
          .firstOrNull
          ?.path;
    } catch (_) {
      return null;
    }
  }

  DownloadEntry copyWith({
    DownloadStatus? status,
    int? received,
    int? total,
    String? Function()? mediaFile,
    String? Function()? error,
    String? mediaSourceId,
    int? positionTicks,
    bool? played,
    DateTime? watchedAt,
    bool? needsSync,
    bool? converted,
    int? Function()? audioIndex,
    String? seriesId,
    int? sortIndex,
  }) => DownloadEntry(
    itemId: itemId,
    serverUrl: serverUrl,
    userId: userId,
    name: name,
    type: type,
    folder: folder,
    seriesName: seriesName,
    seriesId: seriesId ?? this.seriesId,
    episodeLabel: episodeLabel,
    sortIndex: sortIndex ?? this.sortIndex,
    mediaSourceId: mediaSourceId ?? this.mediaSourceId,
    status: status ?? this.status,
    received: received ?? this.received,
    total: total ?? this.total,
    mediaFile: mediaFile != null ? mediaFile() : this.mediaFile,
    error: error != null ? error() : this.error,
    positionTicks: positionTicks ?? this.positionTicks,
    played: played ?? this.played,
    watchedAt: watchedAt ?? this.watchedAt,
    needsSync: needsSync ?? this.needsSync,
    maxBitrate: maxBitrate,
    audioLanguage: audioLanguage,
    subtitleLanguages: subtitleLanguages,
    converted: converted ?? this.converted,
    audioIndex: audioIndex != null ? audioIndex() : this.audioIndex,
    auto: auto,
    expectedSize: expectedSize,
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'serverUrl': serverUrl,
    'userId': userId,
    'name': name,
    'type': type,
    'seriesName': seriesName,
    'seriesId': seriesId,
    'episodeLabel': episodeLabel,
    'sortIndex': sortIndex,
    'mediaSourceId': mediaSourceId,
    'folder': folder,
    'status': status.name,
    'received': received,
    'total': total,
    'mediaFile': mediaFile,
    'error': error,
    'positionTicks': positionTicks,
    'played': played,
    'watchedAt': watchedAt?.toUtc().toIso8601String(),
    'needsSync': needsSync,
    'maxBitrate': maxBitrate,
    'audioLanguage': audioLanguage,
    'subtitleLanguages': subtitleLanguages,
    'converted': converted,
    'audioIndex': audioIndex,
    'auto': auto,
    'expectedSize': expectedSize,
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> j) => DownloadEntry(
    itemId: j['itemId'] as String,
    serverUrl: j['serverUrl'] as String,
    userId: j['userId'] as String,
    name: (j['name'] as String?) ?? '',
    type: (j['type'] as String?) ?? '',
    seriesName: j['seriesName'] as String?,
    seriesId: j['seriesId'] as String?,
    episodeLabel: j['episodeLabel'] as String?,
    sortIndex: (j['sortIndex'] as num?)?.toInt(),
    mediaSourceId: j['mediaSourceId'] as String?,
    folder: j['folder'] as String,
    status: DownloadStatus.values.asNameMap()[j['status']] ?? DownloadStatus.paused,
    received: (j['received'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    mediaFile: j['mediaFile'] as String?,
    error: j['error'] as String?,
    positionTicks: (j['positionTicks'] as num?)?.toInt() ?? 0,
    played: j['played'] == true,
    watchedAt: DateTime.tryParse((j['watchedAt'] as String?) ?? ''),
    needsSync: j['needsSync'] == true,
    maxBitrate: (j['maxBitrate'] as num?)?.toInt(),
    audioLanguage: j['audioLanguage'] as String?,
    subtitleLanguages: (j['subtitleLanguages'] as List?)?.whereType<String>().toList(),
    converted: j['converted'] == true,
    audioIndex: (j['audioIndex'] as num?)?.toInt(),
    auto: j['auto'] == true,
    expectedSize: (j['expectedSize'] as num?)?.toInt() ?? 0,
  );

  /// Gespeicherte Infos des Titels (für die Anzeige ohne Server) – mit dem
  /// lokal geschauten Fortschritt, falls der neuer ist.
  BaseItem? loadItem() {
    try {
      // Einmal von der Platte lesen (die Downloads-Seite baut sich bei jedem Fortschritt neu).
      final cached = _itemCache[itemJsonPath];
      final Map<String, dynamic> stored;
      if (cached != null) {
        stored = cached;
      } else {
        final file = File(itemJsonPath);
        if (!file.existsSync()) return null;
        stored = (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
        _itemCache[itemJsonPath] = stored;
      }
      final raw = {...stored};
      if (watchedAt != null) {
        raw['UserData'] = {
          ...((raw['UserData'] as Map?)?.cast<String, dynamic>() ?? const {}),
          'PlaybackPositionTicks': positionTicks,
          'Played': played,
        };
      }
      return BaseItem(raw);
    } catch (_) {
      return null;
    }
  }

  /// Gelesene item.json-Dateien (Pfad → Inhalt).
  static final _itemCache = <String, Map<String, dynamic>>{};

  /// Nach dem Schreiben oder Löschen neu lesen.
  static void forgetCachedItem(String itemJsonPath) => _itemCache.remove(itemJsonPath);
}

/// Bremst einen Datenstrom auf höchstens `limit` Bytes pro Sekunde.
class _RateLimiter {
  final _clock = Stopwatch()..start();
  int _bytes = 0;
  int _limit = 0;

  Future<void> take(int bytes, int limit) async {
    if (limit <= 0) {
      _limit = 0;
      return;
    }
    if (limit != _limit) {
      _limit = limit;
      _bytes = 0;
      _clock.reset();
    }
    _bytes += bytes;
    final ahead = Duration(microseconds: _bytes * 1000000 ~/ limit) - _clock.elapsed;
    if (ahead > Duration.zero) await Future<void>.delayed(ahead);
    // Regelmäßig neu anfangen – sonst holt der Download nach einer Pause im Netz zu viel auf einmal nach.
    if (_clock.elapsed > const Duration(seconds: 5)) {
      _bytes = 0;
      _clock.reset();
    }
  }
}

/// Lädt Titel im Hintergrund herunter (einer nach dem anderen), mit Pausieren,
/// Fortsetzen nach Abbruch (HTTP-Range) und Offline-Abspielen. Offline
/// Geschautes wird gemerkt und später an den Server gemeldet.
///
/// Außerdem: eigener Download-Ordner, nur über WLAN/LAN (nicht getaktet),
/// Geschwindigkeitsgrenze, Prüfung des freien Speicherplatzes, kleinere
/// Fassungen mit gewählter Sprache und Smart Downloads.
class DownloadManager extends Notifier<List<DownloadEntry>> {
  DownloadManager([this._rootOverride, this._isMetered]);

  final Directory? _rootOverride;

  /// Nur für Tests: statt Windows zu fragen, ob die Verbindung getaktet ist.
  final Future<bool> Function()? _isMetered;

  CancelToken? _cancel;
  String? _runningKey;
  Future<void>? _running;
  Timer? _saveTimer;
  Timer? _syncTimer;
  Timer? _networkTimer;
  Timer? _smartTimer;
  Timer? _smartSoon;
  bool _syncing = false;
  bool _pumping = false;
  bool _smartRunning = false;
  DateTime _lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  /// Alle Ordner, in denen je Downloads angelegt wurden (der Ordner ist änderbar –
  /// ältere Downloads bleiben, wo sie sind, und gelten weiter als sicher).
  final _roots = <String>{};

  /// Warten die Downloads gerade auf eine nicht getaktete Verbindung (WLAN/LAN)?
  final waitingForUnmetered = ValueNotifier<bool>(false);

  /// Platz, der auf dem Laufwerk mindestens frei bleibt.
  static const _reserveBytes = 1024 * 1024 * 1024;

  AppSettings get _settings => ref.read(settingsProvider);

  /// Aktueller Download-Ordner (Standard: Videos\Jellyflex).
  Directory get root =>
      _rootOverride ??
      Directory(
        _settings.downloadFolder ??
            (testDirectory != null ? AppPaths.join(testDirectory!.path, 'Jellyflex') : null) ??
            DownloadFolder.defaultPath,
      );

  /// Nur für Tests: Ordner für Liste und Downloads (nie die echten Daten des Benutzers).
  @visibleForTesting
  static Directory? testDirectory;

  /// Liste der Downloads – im App-Datenordner (in Tests im Testordner).
  File get _indexFile => File(AppPaths.join((_rootOverride ?? testDirectory ?? appDataDir).path, 'downloads.json'));

  /// Frühere Versionen speicherten die Liste im Download-Ordner.
  File get _legacyIndexFile => File(AppPaths.join(DownloadFolder.defaultPath, 'downloads.json'));

  @override
  List<DownloadEntry> build() {
    ref.onDispose(() {
      _cancel?.cancel('App beendet');
      _syncTimer?.cancel();
      _networkTimer?.cancel();
      _smartTimer?.cancel();
      _smartSoon?.cancel();
      // Noch nicht gespeicherte Änderungen nicht verlieren.
      if (_saveTimer?.isActive ?? false) {
        _saveTimer!.cancel();
        _save();
      }
    });
    // Nach dem Anmelden bzw. regelmäßig: offline Geschautes nachmelden.
    ref.listen(sessionProvider, (_, _) {
      _accountChanged();
      syncPending();
      runSmartSoon();
    });
    // Neuer Ordner: merken (alte Downloads bleiben gültig) und Liste speichern.
    ref.listen(settingsProvider.select((s) => s.downloadFolder), (_, _) {
      _roots.add(root.path);
      _set(state);
    });
    ref.listen(settingsProvider.select((s) => s.smartDownloads), (_, on) {
      if (on) runSmartSoon();
    });
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) => syncPending());
    _networkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkNetwork());
    _smartTimer = Timer.periodic(const Duration(minutes: 30), (_) => runSmart());
    _roots.add(root.path);

    try {
      var file = _indexFile;
      if (!file.existsSync() && _rootOverride == null && testDirectory == null && _legacyIndexFile.existsSync()) {
        file = _legacyIndexFile;
      }
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        final List<dynamic> raw;
        if (decoded is List) {
          // Altes Format: nur die Liste, alle Downloads im Ordner der Liste.
          raw = decoded;
          _roots.add(file.parent.path);
        } else {
          final map = (decoded as Map).cast<String, dynamic>();
          raw = (map['entries'] as List?) ?? const [];
          _followedSeries.addAll(((map['followed'] as List?) ?? const []).whereType<String>());
          _roots.addAll(((map['roots'] as List?) ?? const []).whereType<String>());
        }
        final list = raw
            .map((e) => DownloadEntry.fromJson((e as Map).cast<String, dynamic>()))
            // Die Liste liegt als Datei im Benutzerordner – Einträge, die auf fremde
            // Orte zeigen (verändert oder beschädigt), werden ignoriert.
            .where(_isSafeEntry)
            // Beim letzten Beenden unterbrochene Downloads gelten als wartend.
            .map((e) => e.status == DownloadStatus.downloading ? e.copyWith(status: DownloadStatus.queued) : e)
            .toList();
        // Wartende Downloads fortsetzen, sobald die App läuft.
        Future.microtask(() {
          if (!ref.mounted) return;
          // Liste ggf. am neuen Ort speichern.
          if (file.path != _indexFile.path) _set(state);
          _pump();
          syncPending();
          runSmartSoon();
        });
        return list;
      }
    } catch (_) {}
    return const [];
  }

  /// Gehört der Download zum angemeldeten Konto? Andere Konten (z. B. ein
  /// Kinderprofil) sehen fremde Downloads nicht.
  bool isMine(DownloadEntry e) {
    final session = ref.read(sessionProvider).value;
    return session != null && e.serverUrl == session.serverUrl && e.userId == session.userId;
  }

  /// Download eines Titels für das angemeldete Konto (oder `null`).
  DownloadEntry? entryFor(String itemId) => state.where((e) => e.itemId == itemId && isMine(e)).firstOrNull;

  /// Kennungen vom Server werden Ordnernamen – nur harmlose Zeichen zulassen.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _safeExt = RegExp(r'^[a-z0-9]{1,8}$');

  /// Kurze, gleichbleibende Kennung eines Kontos für Ordnernamen (64-Bit-FNV-1a,
  /// damit sich zwei Konten praktisch nie denselben Ordner teilen).
  static String _ownerTag(String serverUrl, String userId) {
    var hash = 0xcbf29ce484222325;
    for (final unit in '$serverUrl|$userId'.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3; // läuft wie gewünscht über (64 Bit)
    }
    String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return '${half(hash >>> 32)}${half(hash)}';
  }

  /// Name des Ordners eines Downloads (Titel + Konto).
  static String folderNameFor(String itemId, String serverUrl, String userId) => _folderName(itemId, serverUrl, userId);

  static String _folderName(String itemId, String serverUrl, String userId) =>
      '$itemId-${_ownerTag(serverUrl, userId)}';

  static String _norm(String p) {
    final s = Directory(p).absolute.path.toLowerCase();
    return Platform.isWindows ? s.replaceAll('/', '\\') : s;
  }

  /// Gespeicherter Eintrag plausibel? Kennung harmlos, Ordner heißt wie erwartet und
  /// liegt direkt in einem bekannten Download-Ordner, Videodatei in diesem Ordner.
  bool _isSafeEntry(DownloadEntry e) {
    if (!_safeId.hasMatch(e.itemId) || !_isKnownFolder(e)) return false;
    final media = e.mediaFile;
    if (media == null) return true;
    return _isInside(e.folder, media);
  }

  /// Nur solche Ordner werden je gelöscht.
  bool _isKnownFolder(DownloadEntry e) {
    final folder = _norm(e.folder);
    final name = _folderName(e.itemId, e.serverUrl, e.userId).toLowerCase();
    if (!folder.endsWith('${AppPaths.sep}$name')) return false;
    final parent = folder.substring(0, folder.length - name.length - 1);
    return _roots.any((r) => _norm(r) == parent);
  }

  /// Kontowechsel: Download des vorigen Kontos anhalten (er wartet, bis das
  /// Konto wieder angemeldet ist) und die Downloads des neuen Kontos starten.
  void _accountChanged() {
    final running = _runningKey;
    final entry = state.where((e) => e.key == running).firstOrNull;
    if (entry != null && !isMine(entry)) {
      _update(entry.key, (e) => e.copyWith(status: DownloadStatus.queued));
      _cancel?.cancel('Konto gewechselt');
      return; // Nach dem Abbruch startet _run den nächsten passenden Download.
    }
    _pump();
  }

  /// Liegt [path] innerhalb von [base] (Groß-/Kleinschreibung und / bzw. \ egal)?
  static bool _isInside(String base, String path) {
    final prefix = '${_norm(base)}${AppPaths.sep}';
    final target = _norm(path);
    return target.startsWith(prefix) && !target.substring(prefix.length).contains('..');
  }

  /// Standard-Optionen aus den Einstellungen.
  DownloadOptions get defaultOptions =>
      DownloadOptions(maxBitrate: _settings.downloadQuality, audioLanguage: _settings.audioLanguage);

  /// Titel (Film oder Folge) zum Herunterladen vormerken – optional eine bestimmte Fassung.
  /// [auto]: von Smart Downloads.
  Future<void> enqueue(BaseItem item, {String? mediaSourceId, DownloadOptions? options, bool auto = false}) async {
    if (item.isSeries || item.isSeason || item.isCollection) return;
    if (entryFor(item.id) != null) return;
    final session = ref.read(sessionProvider).value;
    if (session == null || !_safeId.hasMatch(item.id)) return;
    final o = options ?? defaultOptions;
    _roots.add(root.path);
    final folder = AppPaths.join(root.path, _folderName(item.id, session.serverUrl, session.userId));
    _set([
      ...state,
      DownloadEntry(
        itemId: item.id,
        serverUrl: session.serverUrl,
        userId: session.userId,
        name: item.name,
        type: item.type,
        seriesName: item.seriesName,
        seriesId: item.seriesId,
        episodeLabel: item.episodeLabel,
        sortIndex: item.isEpisode ? _order(item) : null,
        mediaSourceId: mediaSourceId,
        folder: folder,
        maxBitrate: o.maxBitrate,
        expectedSize: _estimateSize(item, o.maxBitrate, mediaSourceId),
        audioLanguage: o.audioLanguage,
        subtitleLanguages: o.subtitleLanguages,
        auto: auto,
      ),
    ]);
    _follow(state.last);
    _pump();
  }

  static int _order(BaseItem i) => (i.parentIndexNumber ?? 0) * 10000 + (i.indexNumber ?? 0);

  /// Alle Folgen einer Staffel vormerken. Liefert die Anzahl neuer Downloads.
  Future<int> enqueueAll(List<BaseItem> items, {DownloadOptions? options}) async {
    var added = 0;
    for (final item in items) {
      if (entryFor(item.id) != null) continue;
      await enqueue(item, options: options);
      if (entryFor(item.id) != null) added++;
    }
    return added;
  }

  void pause(String itemId) {
    final entry = entryFor(itemId);
    if (entry == null) return;
    // Erst den Status setzen, damit der laufende Download den Abbruch als Pause erkennt.
    _update(entry.key, (e) => e.copyWith(status: DownloadStatus.paused));
    if (_runningKey == entry.key) _cancel?.cancel('pausiert');
  }

  void resume(String itemId) {
    final entry = entryFor(itemId);
    if (entry == null) return;
    _update(entry.key, (e) => e.copyWith(status: DownloadStatus.queued, error: () => null));
    _pump();
  }

  /// Download abbrechen bzw. löschen – inklusive aller Dateien.
  Future<void> remove(String itemId) async {
    final entry = entryFor(itemId);
    if (entry == null) return;
    // Von Hand gelöscht und keine Folge der Serie mehr da: Smart Downloads folgen ihr nicht mehr.
    final seriesId = entry.seriesId;
    if (seriesId != null && !state.any((e) => e.key != entry.key && isMine(e) && e.seriesId == seriesId)) {
      _followedSeries.remove('${entry.serverUrl}|${entry.userId}|$seriesId');
    }
    await _removeEntry(entry);
  }

  Future<void> _removeEntry(DownloadEntry entry) async {
    _set(state.where((e) => e.key != entry.key).toList());
    if (_runningKey == entry.key) {
      _cancel?.cancel('gelöscht');
      // Windows kann geöffnete Dateien nicht löschen → erst den Download beenden lassen.
      try {
        await _running;
      } catch (_) {}
    }
    DownloadEntry.forgetCachedItem(entry.itemJsonPath);
    final dir = Directory(entry.folder);
    // Niemals außerhalb eines Download-Ordners löschen.
    if (!_isKnownFolder(entry)) {
      _pump();
      return;
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    _pump();
  }

  /// Belegter Speicherplatz aller Downloads (Bytes).
  int get usedBytes => state.where(isMine).fold(0, (sum, e) => sum + e.sizeOnDisk);

  /// Von Smart Downloads belegter Platz (Bytes).
  /// Unfertige zählen mit ihrer erwarteten Größe – sonst passen mehrere wartende
  /// Folgen scheinbar gleichzeitig unter die Grenze.
  int get smartUsedBytes => state
      .where((e) => isMine(e) && e.auto)
      .fold(0, (sum, e) => sum + (e.isDone ? e.total : [e.total, e.received, e.expectedSize].reduce(max)));

  /// Fertige Downloads, die schon (lokal oder laut Server) gesehen sind.
  ///
  /// Nur, was aus dem Download zu Ende geschaut wurde – dass der Server einen Titel
  /// als gesehen kennt, reicht nicht (wer einen alten Lieblingsfilm lädt, will ihn sehen).
  List<DownloadEntry> watchedDownloads() => [
    for (final e in state)
      if (isMine(e) && e.isDone && e.played) e,
  ];

  /// Alle gesehenen Downloads löschen (Fortschritt, der noch nicht beim Server ist, bleibt).
  Future<int> removeWatched() async {
    var removed = 0;
    for (final e in watchedDownloads()) {
      if (e.needsSync) continue;
      await _removeEntry(e);
      removed++;
    }
    return removed;
  }

  // --- Offline geschaut -------------------------------------------------------

  /// Merkt sich die Stelle, an der ein heruntergeladener Titel gerade läuft.
  /// [synced] = der Server hat den Stand bereits (Wiedergabe online gemeldet).
  void savePlayback(String itemId, {required int positionTicks, int? runtimeTicks, required bool synced}) {
    final entry = entryFor(itemId);
    if (entry == null) return;
    // Wie Jellyfin: unter 5 % zählt nicht als angefangen, ab 90 % als gesehen.
    final runtime = runtimeTicks ?? 0;
    final played = runtime > 0 && positionTicks >= runtime * 0.9;
    final position = played || (runtime > 0 && positionTicks < runtime * 0.05) ? 0 : positionTicks;
    _update(
      entry.key,
      (e) => e.copyWith(positionTicks: position, played: played, watchedAt: DateTime.now(), needsSync: !synced),
    );
    if (played && entry.type == 'Episode') runSmartSoon();
  }

  /// Offline geschauten Fortschritt an den Server melden (sofern erreichbar und
  /// dort nicht inzwischen woanders weitergeschaut wurde).
  Future<void> syncPending() async {
    if (_syncing) return;
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    final pending = state
        .where((e) => e.needsSync && e.serverUrl == session.serverUrl && e.userId == session.userId)
        .toList();
    if (pending.isEmpty) return;
    _syncing = true;
    final api = ref.read(apiProvider);
    try {
      for (final entry in pending) {
        final watchedAt = entry.watchedAt ?? DateTime.now();
        try {
          final item = await api.getItem(entry.itemId);
          final serverDate = DateTime.tryParse((item.userData.raw['LastPlayedDate'] as String?) ?? '');
          if (serverDate == null || serverDate.isBefore(watchedAt)) {
            await api.updateUserData(entry.itemId, {
              'PlaybackPositionTicks': entry.positionTicks,
              'Played': entry.played,
              'LastPlayedDate': watchedAt.toUtc().toIso8601String(),
            });
          }
          _update(entry.key, (e) => e.watchedAt == entry.watchedAt ? e.copyWith(needsSync: false) : e);
        } catch (e) {
          debugPrint('Offline-Fortschritt noch nicht gemeldet (${entry.name}): $e');
          break; // Server vermutlich nicht erreichbar – später erneut.
        }
      }
    } finally {
      _syncing = false;
    }
  }

  /// Nächste heruntergeladene Folge derselben Serie (für "Nächste Folge" offline).
  BaseItem? nextDownloadedEpisode(BaseItem episode) {
    final seriesId = episode.seriesId;
    if (seriesId == null) return null;
    final current = _order(episode);
    final candidates =
        [
            for (final e in state)
              if (isMine(e) && e.isDone && e.type == 'Episode' && e.itemId != episode.id) ?e.loadItem(),
          ].where((i) => i.seriesId == seriesId && _order(i) > current).toList()
          ..sort((a, b) => _order(a).compareTo(_order(b)));
    return candidates.firstOrNull;
  }

  // --- Smart Downloads ------------------------------------------------------

  /// Smart Downloads gleich (gebündelt) prüfen – z. B. nach dem Ende einer Folge.
  void runSmartSoon() {
    _smartSoon?.cancel();
    _smartSoon = Timer(const Duration(seconds: 3), runSmart);
  }

  /// Für jede Serie mit heruntergeladenen Folgen: die nächsten ungesehenen Folgen
  /// bereithalten (Anzahl und Speichergrenze aus den Einstellungen) und gesehene
  /// Folgen löschen. Neue Downloads warten wie alle anderen auf WLAN/LAN.
  Future<void> runSmart() async {
    final settings = _settings;
    if (!settings.smartDownloads || _smartRunning || !ref.mounted) return;
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    final account = session.accountKey;
    // Gefolgte Serien: alle mit heruntergeladenen Folgen – und solche, deren letzte
    // Folge gerade gelöscht wurde (sonst endete die Serie, wenn der Platz kurz knapp war).
    final seriesIds = {
      ..._followedSeries.where((k) => k.startsWith('$account|')).map((k) => k.substring(account.length + 1)),
      for (final e in state)
        if (isMine(e) && e.type == 'Episode' && e.seriesId != null) e.seriesId!,
    };
    if (seriesIds.isEmpty) return;
    _smartRunning = true;
    final api = ref.read(apiProvider);
    final limit = settings.smartMaxGb * 1024 * 1024 * 1024;
    // Nach jeder Wartezeit: noch dasselbe Konto? Sonst nichts mehr anfassen.
    bool stillMine() => ref.mounted && ref.read(sessionProvider).value?.accountKey == account;
    try {
      for (final seriesId in seriesIds) {
        final List<BaseItem> episodes;
        try {
          episodes = (await api.getSeriesEpisodes(seriesId)).where((e) => (e.parentIndexNumber ?? 1) > 0).toList()
            ..sort((a, b) => _order(a).compareTo(_order(b)));
        } catch (e) {
          debugPrint('Smart Downloads: Server nicht erreichbar ($e)');
          return;
        }
        if (!stillMine()) return;
        // Gesehen – laut Server oder offline (noch nicht gemeldet).
        bool watched(BaseItem ep) => ep.userData.played || (entryFor(ep.id)?.played ?? false);

        // Erst aufräumen (macht Platz für die nächsten Folgen). Gelöscht wird nur, was der
        // Server als gesehen kennt – so geht nie Fortschritt verloren, der dort nicht ankam.
        // Selbst geladene Folgen nur, wenn sie aus dem Download zu Ende geschaut wurden
        // (wer eine schon gesehene Folge bewusst lädt, will sie noch einmal sehen).
        for (final ep in episodes.where((e) => e.userData.played)) {
          if (!stillMine()) return;
          final entry = entryFor(ep.id);
          if (entry == null || entry.needsSync || !entry.isDone) continue;
          if (!entry.played && !entry.auto) continue;
          await _removeEntry(entry);
        }

        // Nach der zuletzt gesehenen Folge weiter.
        final lastWatched = episodes.lastIndexWhere(watched);
        final upcoming = episodes.skip(lastWatched + 1).where((e) => !watched(e)).take(settings.smartEpisodes);
        for (final ep in upcoming) {
          if (!stillMine()) return;
          if (entryFor(ep.id) != null) continue;
          final size = _estimateSize(ep, settings.downloadQuality);
          if (limit > 0 && smartUsedBytes + size > limit) break;
          await enqueue(ep, auto: true);
        }
      }
    } finally {
      _smartRunning = false;
    }
  }

  /// Serien, denen Smart Downloads folgen ("Konto|Serie"), auch ohne aktuelle Downloads.
  final _followedSeries = <String>{};

  void _follow(DownloadEntry e) {
    if (e.type == 'Episode' && e.seriesId != null) _followedSeries.add('${e.serverUrl}|${e.userId}|${e.seriesId}');
  }

  /// Geschätzte Größe eines Downloads (Bytes).
  static int _estimateSize(BaseItem item, int? maxBitrate, [String? mediaSourceId]) {
    final sources = item.mediaSources;
    final source = sources.where((s) => s.id == mediaSourceId).firstOrNull ?? sources.firstOrNull;
    final runtime = item.runTimeTicks ?? source?.runTimeTicks ?? 0;
    final seconds = runtime / 10000000;
    if (maxBitrate != null && seconds > 0 && ((source?.bitrate ?? 0) == 0 || source!.bitrate! > maxBitrate)) {
      return (seconds * maxBitrate / 8).round();
    }
    if ((source?.size ?? 0) > 0) return source!.size!;
    return seconds > 0 && (source?.bitrate ?? 0) > 0 ? (seconds * source!.bitrate! / 8).round() : 0;
  }

  /// Geschätzte Größe für die Anzeige vor dem Download.
  int estimateSize(BaseItem item, DownloadOptions options, {String? mediaSourceId}) =>
      _estimateSize(item, options.maxBitrate, mediaSourceId);

  // --- Netzwerk -------------------------------------------------------------

  Future<bool> _networkBlocked() async {
    if (!_settings.downloadsUnmeteredOnly) return false;
    return (_isMetered ?? AppShell.isMeteredConnection)();
  }

  /// Getaktete Verbindung? Dann laufenden Download anhalten (er wartet) – sonst weiter.
  Future<void> _checkNetwork() async {
    if (!ref.mounted) return;
    final hasWork = state.any((e) => isMine(e) && e.isActive);
    if (!hasWork) {
      waitingForUnmetered.value = false;
      return;
    }
    final blocked = await _networkBlocked();
    if (!ref.mounted) return;
    waitingForUnmetered.value = blocked;
    if (blocked && _runningKey != null) {
      final key = _runningKey!;
      _update(key, (e) => e.copyWith(status: DownloadStatus.queued));
      _cancel?.cancel('getaktete Verbindung');
    } else if (!blocked) {
      _pump();
    }
  }

  /// Sofort nachsehen (z. B. nach Änderung der Einstellung).
  void recheckNetwork() => _checkNetwork();

  // --- Interna --------------------------------------------------------------

  Future<void> _pump() async {
    // App beendet (bzw. Anmeldung gewechselt): nichts mehr starten.
    if (!ref.mounted || _runningKey != null || _pumping) return;
    // Nur Downloads des angemeldeten Kontos laufen lassen.
    if (!state.any((e) => e.status == DownloadStatus.queued && isMine(e))) return;
    _pumping = true;
    try {
      final blocked = await _networkBlocked();
      if (!ref.mounted) return;
      waitingForUnmetered.value = blocked;
      if (blocked || _runningKey != null) return;
      final next = state.where((e) => e.status == DownloadStatus.queued && isMine(e)).firstOrNull;
      if (next == null) return;
      _running = _run(next);
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(DownloadEntry entry) async {
    final session = ref.read(sessionProvider).value;
    // Nur mit dem Konto fortsetzen, das den Download begonnen hat.
    if (session == null || session.serverUrl != entry.serverUrl || session.userId != entry.userId) {
      _update(entry.key, (e) => e.copyWith(status: DownloadStatus.paused, error: () => tr.otherAccountSignedIn));
      return;
    }
    final api = ref.read(apiProvider);
    final cancel = CancelToken();
    _runningKey = entry.key;
    _cancel = cancel;
    _update(entry.key, (e) => e.copyWith(status: DownloadStatus.downloading, error: () => null));

    try {
      await Directory(entry.folder).create(recursive: true);
      final item = await api.getItem(entry.itemId);
      final sources = item.mediaSources;
      final source = sources.where((s) => s.id == entry.mediaSourceId).firstOrNull ?? sources.firstOrNull;
      if (source == null) throw Exception(tr.noFileFound);
      await File(entry.itemJsonPath).writeAsString(jsonEncode(item.raw));
      DownloadEntry.forgetCachedItem(entry.itemJsonPath);

      // Kleinere Fassung nur, wenn die Datei wirklich größer ist als gewünscht.
      final maxBitrate = entry.maxBitrate;
      final converted = maxBitrate != null && ((source.bitrate ?? 0) == 0 || source.bitrate! > maxBitrate);
      final audioIndex = converted ? _audioIndexFor(source, entry.audioLanguage) : null;
      _update(
        entry.key,
        (e) => e.copyWith(
          converted: converted,
          audioIndex: () => audioIndex,
          seriesId: item.seriesId,
          sortIndex: item.isEpisode ? _order(item) : null,
        ),
      );

      await _downloadImages(api, item, entry, cancel);
      await _downloadSubtitles(api, item, source, entry, cancel, converted: converted);
      if (cancel.isCancelled) return;

      // Dateiendung vom Server nur übernehmen, wenn sie harmlos ist.
      final container = converted ? 'mkv' : (source.container ?? '').split(',').first.toLowerCase();
      final ext = _safeExt.hasMatch(container) ? container : 'mkv';
      final target = File(AppPaths.join(entry.folder, 'media.$ext'));
      final part = File('${target.path}.part');
      // Umgerechnete Fassungen lassen sich nicht fortsetzen – dann von vorn.
      if (converted && await part.exists()) await part.delete();
      final already = await part.exists() ? await part.length() : 0;

      // Genug Platz? (mit Reserve, damit das Laufwerk nicht vollläuft)
      final expected = converted ? _estimateSize(item, maxBitrate, source.id) : (source.size ?? 0);
      final free = DownloadFolder.freeBytes(entry.folder);
      if (free != null && expected > 0 && expected - already > free - _reserveBytes) {
        throw Exception(tr.notEnoughSpace(formatBytes(expected - already), formatBytes(free)));
      }

      final url = converted
          ? api.downloadTranscodeUrl(item.id, mediaSourceId: source.id, maxBitrate: maxBitrate, audioIndex: audioIndex)
          : api.streamUrl(item.id, mediaSourceId: source.id);
      final dio = Dio(BaseOptions(headers: {'Authorization': api.authorizationHeader}));
      final response = await dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {if (already > 0) 'Range': 'bytes=$already-'},
          // 416 = die Teildatei ist schon vollständig (Abbruch kurz vor dem Umbenennen).
          validateStatus: (s) => s != null && ((s >= 200 && s < 300) || (s == 416 && already > 0)),
        ),
        cancelToken: cancel,
      );

      var received = 0;
      var total = 0;
      if (response.statusCode == 416) {
        received = total = already;
      } else {
        // Server ignoriert Range → von vorn beginnen.
        final resumed = response.statusCode == 206;
        final contentLength = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
        received = resumed ? already : 0;
        total = contentLength > 0 ? (resumed ? already : 0) + contentLength : 0;
        // Ohne Größenangabe (umgerechnet): geschätzte Größe für den Fortschritt.
        final shownTotal = total > 0 ? total : expected;
        final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
        final limiter = _RateLimiter();
        try {
          var unflushed = 0;
          var sinceSpaceCheck = 0;
          await for (final chunk in response.data!.stream) {
            if (cancel.isCancelled) break;
            sink.add(chunk);
            received += chunk.length;
            // Regelmäßig auf die Festplatte warten – sonst sammelt sich bei schnellem
            // Netz und langsamer Platte viel Video im Arbeitsspeicher.
            unflushed += chunk.length;
            if (unflushed >= 8 * 1024 * 1024) {
              await sink.flush();
              unflushed = 0;
            }
            // Laufwerk wird knapp (z. B. weil anderes gleichzeitig Platz braucht) → abbrechen.
            sinceSpaceCheck += chunk.length;
            if (sinceSpaceCheck >= 256 * 1024 * 1024) {
              sinceSpaceCheck = 0;
              final left = DownloadFolder.freeBytes(entry.folder);
              if (left != null && left < _reserveBytes ~/ 4) throw Exception(tr.diskAlmostFull);
            }
            _reportProgress(entry.key, received, shownTotal > received ? shownTotal : received);
            await limiter.take(chunk.length, _settings.downloadSpeedLimit);
          }
        } finally {
          await sink.close();
        }
      }
      // Abgebrochen (Pause/Löschen): Teildatei bleibt für später liegen.
      if (cancel.isCancelled) return;
      if (total > 0 && received < total) {
        throw Exception(tr.connectionInterrupted(formatBytes(received), formatBytes(total)));
      }
      // Umgerechnet (ohne Größenangabe): deutlich kleiner als erwartet = abgebrochen,
      // nicht fertig. Neu laden statt einen halben Film zu behalten.
      if (converted && total == 0 && expected > 0 && received < expected ~/ 4) {
        await part.delete();
        throw Exception(tr.connectionInterrupted(formatBytes(received), formatBytes(expected)));
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      _update(
        entry.key,
        (e) => e.copyWith(
          status: DownloadStatus.done,
          received: received,
          total: received,
          mediaFile: () => target.path,
          mediaSourceId: source.id,
        ),
      );
    } catch (e) {
      // Pausiert oder gelöscht – Status wurde schon gesetzt. Beim Abbruch kann
      // auch ein anderer Fehler als DioException entstehen (abgebrochene Verbindung).
      if (!cancel.isCancelled) {
        final message = switch (e) {
          DioException(:final response?) => tr.serverError(response.statusCode),
          DioException() => tr.noConnectionToServer,
          FileSystemException(:final osError?) => osError.message,
          _ => '$e'.replaceFirst('Exception: ', ''),
        };
        _update(entry.key, (x) => x.copyWith(status: DownloadStatus.failed, error: () => message));
      }
    } finally {
      _runningKey = null;
      _cancel = null;
      _pump();
    }
  }

  /// Tonspur für die kleinere Fassung: gewünschte Sprache, sonst die Standardspur.
  static int? _audioIndexFor(MediaSource source, String? language) {
    if (language != null) {
      final match = source.embeddedStreams('Audio').where((s) => sameLanguage(s.language, language)).firstOrNull;
      if (match != null) return match.index;
    }
    return source.defaultAudioStreamIndex ?? source.embeddedStreams('Audio').firstOrNull?.index;
  }

  /// Text-Untertitel lassen sich als Datei laden (Bild-Untertitel wie PGS nicht).
  static const _textSubtitleCodecs = {'srt', 'subrip', 'ass', 'ssa', 'vtt', 'webvtt', 'mov_text', 'text'};

  /// Nebendateien: kurze Zeitlimits und abbrechbar (Pause/Löschen wartet sonst ewig).
  static final _sideOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  );

  Future<void> _downloadImages(JellyfinApi api, BaseItem item, DownloadEntry entry, CancelToken cancel) async {
    // Mit Anmeldung – manche Server (bzw. Proxys davor) geben Bilder nur so heraus.
    final dio = Dio(_sideOptions.copyWith(headers: {'Authorization': api.authorizationHeader}));
    final poster = api.imageUrlOrNull(Images.poster(item), fillWidth: 400, fillHeight: 600);
    final backdrop = api.imageUrlOrNull(Images.landscape(item), maxWidth: 1280);
    for (final (url, path) in [(poster, entry.posterPath), (backdrop, entry.backdropPath)]) {
      if (url == null) continue;
      try {
        await dio.download(url, path, cancelToken: cancel);
      } catch (_) {}
    }
  }

  /// Originaldatei: externe Untertitel (eingebettete stecken in der Datei).
  /// Kleinere Fassung: alle gewählten Text-Untertitel – auch eingebettete – als Datei.
  Future<void> _downloadSubtitles(
    JellyfinApi api,
    BaseItem item,
    MediaSource source,
    DownloadEntry entry,
    CancelToken cancel, {
    required bool converted,
  }) async {
    final dio = Dio(_sideOptions.copyWith(headers: {'Authorization': api.authorizationHeader}));
    final wanted = entry.subtitleLanguages;
    for (final s in source.mediaStreams.where((s) => s.type == 'Subtitle')) {
      final String url;
      if (converted) {
        if (!_textSubtitleCodecs.contains(s.codec?.toLowerCase())) continue;
        if (wanted != null && !wanted.any((l) => sameLanguage(l, s.language))) continue;
        final codec = s.codec?.toLowerCase();
        url = api.subtitleUrl(
          item.id,
          source.id,
          s,
          format: codec == 'ass' || codec == 'ssa' ? 'ass' : (codec == 'vtt' || codec == 'webvtt' ? 'vtt' : 'srt'),
        );
      } else {
        if (!s.isExternal) continue;
        url = api.subtitleUrl(item.id, source.id, s);
      }
      final ext = Uri.parse(url).path.split('.').last.toLowerCase();
      if (!_safeExt.hasMatch(ext)) continue;
      try {
        await dio.download(url, AppPaths.join(entry.folder, 'subtitle_${s.index}.$ext'), cancelToken: cancel);
      } catch (_) {}
    }
  }

  void _reportProgress(String key, int received, int total) {
    final now = DateTime.now();
    if (now.difference(_lastProgressUpdate) < const Duration(milliseconds: 400)) return;
    _lastProgressUpdate = now;
    _update(key, (e) => e.copyWith(received: received, total: total));
  }

  void _update(String key, DownloadEntry Function(DownloadEntry e) change) {
    if (!ref.mounted) return;
    _set([for (final e in state) e.key == key ? change(e) : e]);
  }

  void _set(List<DownloadEntry> entries) {
    // Ein abgebrochener Download meldet sich evtl. erst nach dem Beenden der App.
    if (!ref.mounted) return;
    state = entries;
    // Index gebündelt speichern (nicht bei jedem Fortschritts-Update).
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    try {
      final file = _indexFile;
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(
        jsonEncode({
          'version': 2,
          'roots': [..._roots],
          'entries': [for (final e in state) e.toJson()],
          'followed': [..._followedSeries],
        }),
        flush: true,
      );
      tmp.renameSync(file.path);
    } catch (_) {}
  }
}

final downloadsProvider = NotifierProvider<DownloadManager, List<DownloadEntry>>(DownloadManager.new);

/// Downloads des angemeldeten Kontos.
final myDownloadsProvider = Provider<List<DownloadEntry>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const [];
  return [
    for (final e in ref.watch(downloadsProvider))
      if (e.serverUrl == session.serverUrl && e.userId == session.userId) e,
  ];
});

/// Download eines Titels für das angemeldete Konto (oder `null`).
final downloadedProvider = Provider.family<DownloadEntry?, String>((ref, itemId) {
  return ref.watch(myDownloadsProvider).where((e) => e.itemId == itemId).firstOrNull;
});

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  return '${tr.decimal(bytes / (1024 * 1024 * 1024), 1)} GB';
}
