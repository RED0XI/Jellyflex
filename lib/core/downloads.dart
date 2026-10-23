import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'images.dart';
import 'jellyfin_api.dart';
import 'models.dart';
import 'session.dart';
import '../l10n/strings.dart';

enum DownloadStatus { queued, downloading, paused, done, failed }

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
    this.episodeLabel,
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
  });

  final String itemId;
  final String serverUrl;
  final String userId;
  final String name;
  final String type;
  final String? seriesName;
  final String? episodeLabel;

  /// Heruntergeladene Fassung (bei mehreren Versionen), sonst `null` = erste.
  final String? mediaSourceId;

  /// Ordner mit Video, Infos (item.json) und Bildern.
  final String folder;
  final DownloadStatus status;
  final int received;
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

  /// Eindeutig je Konto: derselbe Titel kann von zwei Konten geladen sein.
  String get key => '$serverUrl|$userId|$itemId';

  double get progress => total > 0 ? (received / total).clamp(0, 1).toDouble() : 0;
  bool get isDone => status == DownloadStatus.done && mediaFile != null;
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  String get posterPath => '$folder${Platform.pathSeparator}poster.jpg';
  String get backdropPath => '$folder${Platform.pathSeparator}backdrop.jpg';
  String get itemJsonPath => '$folder${Platform.pathSeparator}item.json';

  /// Mitgeladene externe Untertiteldatei für den Jellyfin-Streamindex.
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
  }) => DownloadEntry(
    itemId: itemId,
    serverUrl: serverUrl,
    userId: userId,
    name: name,
    type: type,
    folder: folder,
    seriesName: seriesName,
    episodeLabel: episodeLabel,
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
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'serverUrl': serverUrl,
    'userId': userId,
    'name': name,
    'type': type,
    'seriesName': seriesName,
    'episodeLabel': episodeLabel,
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
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> j) => DownloadEntry(
    itemId: j['itemId'] as String,
    serverUrl: j['serverUrl'] as String,
    userId: j['userId'] as String,
    name: (j['name'] as String?) ?? '',
    type: (j['type'] as String?) ?? '',
    seriesName: j['seriesName'] as String?,
    episodeLabel: j['episodeLabel'] as String?,
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
  );

  /// Gespeicherte Infos des Titels (für die Anzeige ohne Server) – mit dem
  /// lokal geschauten Fortschritt, falls der neuer ist.
  BaseItem? loadItem() {
    try {
      final file = File(itemJsonPath);
      if (!file.existsSync()) return null;
      final raw = (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
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
}

/// Lädt Titel im Hintergrund herunter (einer nach dem anderen), mit Pausieren,
/// Fortsetzen nach Abbruch (HTTP-Range) und Offline-Abspielen. Offline
/// Geschautes wird gemerkt und später an den Server gemeldet.
class DownloadManager extends Notifier<List<DownloadEntry>> {
  DownloadManager([this._rootOverride]);

  final Directory? _rootOverride;
  CancelToken? _cancel;
  String? _runningKey;
  Future<void>? _running;
  Timer? _saveTimer;
  Timer? _syncTimer;
  bool _syncing = false;
  DateTime _lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  /// Standardordner: Videos\Jellyflex im Benutzerprofil.
  Directory get root =>
      _rootOverride ??
      Directory('${Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}\\Videos\\Jellyflex');

  File get _indexFile => File('${root.path}\\downloads.json');

  @override
  List<DownloadEntry> build() {
    ref.onDispose(() {
      _cancel?.cancel('App beendet');
      _syncTimer?.cancel();
      // Noch nicht gespeicherte Änderungen nicht verlieren.
      if (_saveTimer?.isActive ?? false) {
        _saveTimer!.cancel();
        _save();
      }
    });
    // Nach dem Anmelden bzw. regelmäßig: offline Geschautes nachmelden.
    ref.listen(sessionProvider, (_, _) => syncPending());
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) => syncPending());

    try {
      if (_indexFile.existsSync()) {
        final list = (jsonDecode(_indexFile.readAsStringSync()) as List)
            .map((e) => DownloadEntry.fromJson((e as Map).cast<String, dynamic>()))
            // Beim letzten Beenden unterbrochene Downloads gelten als wartend.
            .map((e) => e.status == DownloadStatus.downloading ? e.copyWith(status: DownloadStatus.queued) : e)
            .toList();
        // Wartende Downloads fortsetzen, sobald die App läuft.
        Future.microtask(() {
          _pump();
          syncPending();
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

  /// Kurze, gleichbleibende Kennung eines Kontos für Ordnernamen (FNV-1a).
  static String _ownerTag(String serverUrl, String userId) {
    var hash = 0x811c9dc5;
    for (final unit in '$serverUrl|$userId'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Liegt [path] wirklich im Download-Ordner (und ist nicht der Ordner selbst)?
  bool _insideRoot(String path) {
    final base = '${root.absolute.path.toLowerCase().replaceAll('/', '\\')}\\';
    final target = Directory(path).absolute.path.toLowerCase().replaceAll('/', '\\');
    return target.startsWith(base) && !target.substring(base.length).contains('..');
  }

  /// Titel (Film oder Folge) zum Herunterladen vormerken – optional eine bestimmte Fassung.
  Future<void> enqueue(BaseItem item, {String? mediaSourceId}) async {
    if (item.isSeries || item.isSeason || item.isCollection) return;
    if (entryFor(item.id) != null) return;
    final session = ref.read(sessionProvider).value;
    if (session == null || !_safeId.hasMatch(item.id)) return;
    final folder = '${root.path}\\${item.id}-${_ownerTag(session.serverUrl, session.userId)}';
    _set([
      ...state,
      DownloadEntry(
        itemId: item.id,
        serverUrl: session.serverUrl,
        userId: session.userId,
        name: item.name,
        type: item.type,
        seriesName: item.seriesName,
        episodeLabel: item.episodeLabel,
        mediaSourceId: mediaSourceId,
        folder: folder,
      ),
    ]);
    _pump();
  }

  /// Alle Folgen einer Staffel vormerken. Liefert die Anzahl neuer Downloads.
  Future<int> enqueueAll(List<BaseItem> items) async {
    var added = 0;
    for (final item in items) {
      if (entryFor(item.id) != null) continue;
      await enqueue(item);
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
    _set(state.where((e) => e.key != entry.key).toList());
    if (_runningKey == entry.key) {
      _cancel?.cancel('gelöscht');
      // Windows kann geöffnete Dateien nicht löschen → erst den Download beenden lassen.
      try {
        await _running;
      } catch (_) {}
    }
    final dir = Directory(entry.folder);
    // Niemals außerhalb des Download-Ordners löschen.
    if (!_insideRoot(dir.path)) {
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
  int get usedBytes => state.where(isMine).fold(0, (sum, e) => sum + (e.isDone ? e.total : e.received));

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
    int order(BaseItem i) => (i.parentIndexNumber ?? 0) * 10000 + (i.indexNumber ?? 0);
    final current = order(episode);
    final candidates = [
      for (final e in state)
        if (isMine(e) && e.isDone && e.type == 'Episode' && e.itemId != episode.id) ?e.loadItem(),
    ].where((i) => i.seriesId == seriesId && order(i) > current).toList()..sort((a, b) => order(a).compareTo(order(b)));
    return candidates.firstOrNull;
  }

  // --- Interna --------------------------------------------------------------

  void _pump() {
    if (_runningKey != null) return;
    // Nur Downloads des angemeldeten Kontos laufen lassen.
    final next = state.where((e) => e.status == DownloadStatus.queued && isMine(e)).firstOrNull;
    if (next == null) return;
    _running = _run(next);
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
      await _downloadImages(api, item, entry, cancel);
      await _downloadSubtitles(api, item, source, entry, cancel);
      if (cancel.isCancelled) return;

      // Dateiendung vom Server nur übernehmen, wenn sie harmlos ist.
      final container = (source.container ?? '').split(',').first.toLowerCase();
      final ext = _safeExt.hasMatch(container) ? container : 'mkv';
      final target = File('${entry.folder}\\media.$ext');
      final part = File('${target.path}.part');
      final already = await part.exists() ? await part.length() : 0;

      final dio = Dio(BaseOptions(headers: {'Authorization': api.authorizationHeader}));
      final response = await dio.get<ResponseBody>(
        api.streamUrl(item.id, mediaSourceId: source.id),
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
        final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
        try {
          var unflushed = 0;
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
            _reportProgress(entry.key, received, total);
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

  /// Nebendateien: kurze Zeitlimits und abbrechbar (Pause/Löschen wartet sonst ewig).
  static final _sideOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  );

  Future<void> _downloadImages(JellyfinApi api, BaseItem item, DownloadEntry entry, CancelToken cancel) async {
    final dio = Dio(_sideOptions);
    final poster = api.imageUrlOrNull(Images.poster(item), fillWidth: 400, fillHeight: 600);
    final backdrop = api.imageUrlOrNull(Images.landscape(item), maxWidth: 1280);
    for (final (url, path) in [(poster, entry.posterPath), (backdrop, entry.backdropPath)]) {
      if (url == null) continue;
      try {
        await dio.download(url, path, cancelToken: cancel);
      } catch (_) {}
    }
  }

  Future<void> _downloadSubtitles(
    JellyfinApi api,
    BaseItem item,
    MediaSource source,
    DownloadEntry entry,
    CancelToken cancel,
  ) async {
    final dio = Dio(_sideOptions.copyWith(headers: {'Authorization': api.authorizationHeader}));
    for (final s in source.mediaStreams.where((s) => s.type == 'Subtitle' && s.isExternal)) {
      final url = api.subtitleUrl(item.id, source.id, s);
      final ext = url.split('.').last.toLowerCase();
      if (!_safeExt.hasMatch(ext)) continue;
      try {
        await dio.download(url, '${entry.folder}\\subtitle_${s.index}.$ext', cancelToken: cancel);
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
    _set([for (final e in state) e.key == key ? change(e) : e]);
  }

  void _set(List<DownloadEntry> entries) {
    state = entries;
    // Index gebündelt speichern (nicht bei jedem Fortschritts-Update).
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    try {
      root.createSync(recursive: true);
      _indexFile.writeAsStringSync(jsonEncode([for (final e in state) e.toJson()]));
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
