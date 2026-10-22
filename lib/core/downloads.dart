import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'images.dart';
import 'jellyfin_api.dart';
import 'models.dart';
import 'session.dart';

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
    this.status = DownloadStatus.queued,
    this.received = 0,
    this.total = 0,
    this.mediaFile,
    this.error,
  });

  final String itemId;
  final String serverUrl;
  final String userId;
  final String name;
  final String type;
  final String? seriesName;
  final String? episodeLabel;

  /// Ordner mit Video, Infos (item.json) und Bildern.
  final String folder;
  final DownloadStatus status;
  final int received;
  final int total;

  /// Fertige Videodatei (erst nach Abschluss gesetzt).
  final String? mediaFile;
  final String? error;

  double get progress => total > 0 ? (received / total).clamp(0, 1).toDouble() : 0;
  bool get isDone => status == DownloadStatus.done && mediaFile != null;
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  String get posterPath => '$folder${Platform.pathSeparator}poster.jpg';
  String get backdropPath => '$folder${Platform.pathSeparator}backdrop.jpg';
  String get itemJsonPath => '$folder${Platform.pathSeparator}item.json';

  DownloadEntry copyWith({
    DownloadStatus? status,
    int? received,
    int? total,
    String? Function()? mediaFile,
    String? Function()? error,
  }) => DownloadEntry(
    itemId: itemId,
    serverUrl: serverUrl,
    userId: userId,
    name: name,
    type: type,
    folder: folder,
    seriesName: seriesName,
    episodeLabel: episodeLabel,
    status: status ?? this.status,
    received: received ?? this.received,
    total: total ?? this.total,
    mediaFile: mediaFile != null ? mediaFile() : this.mediaFile,
    error: error != null ? error() : this.error,
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'serverUrl': serverUrl,
    'userId': userId,
    'name': name,
    'type': type,
    'seriesName': seriesName,
    'episodeLabel': episodeLabel,
    'folder': folder,
    'status': status.name,
    'received': received,
    'total': total,
    'mediaFile': mediaFile,
    'error': error,
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> j) => DownloadEntry(
    itemId: j['itemId'] as String,
    serverUrl: j['serverUrl'] as String,
    userId: j['userId'] as String,
    name: (j['name'] as String?) ?? '',
    type: (j['type'] as String?) ?? '',
    seriesName: j['seriesName'] as String?,
    episodeLabel: j['episodeLabel'] as String?,
    folder: j['folder'] as String,
    status: DownloadStatus.values.asNameMap()[j['status']] ?? DownloadStatus.paused,
    received: (j['received'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    mediaFile: j['mediaFile'] as String?,
    error: j['error'] as String?,
  );

  /// Gespeicherte Infos des Titels (für die Anzeige ohne Server).
  BaseItem? loadItem() {
    try {
      final file = File(itemJsonPath);
      if (!file.existsSync()) return null;
      return BaseItem((jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Lädt Titel im Hintergrund herunter (einer nach dem anderen), mit Pausieren,
/// Fortsetzen nach Abbruch (HTTP-Range) und Offline-Abspielen.
class DownloadManager extends Notifier<List<DownloadEntry>> {
  DownloadManager([this._rootOverride]);

  final Directory? _rootOverride;
  CancelToken? _cancel;
  String? _runningId;
  Timer? _saveTimer;
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
      _saveTimer?.cancel();
    });
    try {
      if (_indexFile.existsSync()) {
        final list = (jsonDecode(_indexFile.readAsStringSync()) as List)
            .map((e) => DownloadEntry.fromJson((e as Map).cast<String, dynamic>()))
            // Beim letzten Beenden unterbrochene Downloads gelten als pausiert.
            .map((e) => e.status == DownloadStatus.downloading ? e.copyWith(status: DownloadStatus.queued) : e)
            .toList();
        // Wartende Downloads fortsetzen, sobald die App läuft.
        Future.microtask(_pump);
        return list;
      }
    } catch (_) {}
    return const [];
  }

  DownloadEntry? entryFor(String itemId) => state.where((e) => e.itemId == itemId).firstOrNull;

  /// Titel (Film oder Folge) zum Herunterladen vormerken.
  Future<void> enqueue(BaseItem item) async {
    if (item.isSeries || item.isSeason || item.isCollection) return;
    if (entryFor(item.id) != null) return;
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    final folder = '${root.path}\\${item.id}';
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
        folder: folder,
      ),
    ]);
    _pump();
  }

  /// Alle Folgen einer Staffel vormerken.
  Future<void> enqueueAll(List<BaseItem> items) async {
    for (final item in items) {
      await enqueue(item);
    }
  }

  void pause(String itemId) {
    if (_runningId == itemId) _cancel?.cancel('pausiert');
    _update(itemId, (e) => e.copyWith(status: DownloadStatus.paused));
  }

  void resume(String itemId) {
    _update(itemId, (e) => e.copyWith(status: DownloadStatus.queued, error: () => null));
    _pump();
  }

  /// Download abbrechen bzw. löschen – inklusive aller Dateien.
  Future<void> remove(String itemId) async {
    final entry = entryFor(itemId);
    if (entry == null) return;
    if (_runningId == itemId) _cancel?.cancel('gelöscht');
    _set(state.where((e) => e.itemId != itemId).toList());
    try {
      final dir = Directory(entry.folder);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    _pump();
  }

  /// Belegter Speicherplatz aller Downloads (Bytes).
  int get usedBytes => state.fold(0, (sum, e) => sum + (e.isDone ? e.total : e.received));

  // --- Interna --------------------------------------------------------------

  void _pump() {
    if (_runningId != null) return;
    final next = state.where((e) => e.status == DownloadStatus.queued).firstOrNull;
    if (next == null) return;
    _run(next);
  }

  Future<void> _run(DownloadEntry entry) async {
    final session = ref.read(sessionProvider).value;
    // Nur mit dem Konto fortsetzen, das den Download begonnen hat.
    if (session == null || session.serverUrl != entry.serverUrl || session.userId != entry.userId) {
      _update(entry.itemId, (e) => e.copyWith(status: DownloadStatus.paused, error: () => 'Anderes Konto angemeldet'));
      return;
    }
    final api = ref.read(apiProvider);
    _runningId = entry.itemId;
    _cancel = CancelToken();
    _update(entry.itemId, (e) => e.copyWith(status: DownloadStatus.downloading, error: () => null));

    try {
      await Directory(entry.folder).create(recursive: true);
      final item = await api.getItem(entry.itemId);
      final source = item.mediaSources.firstOrNull;
      if (source == null) throw Exception('Keine Datei gefunden');
      await File(entry.itemJsonPath).writeAsString(jsonEncode(item.raw));
      await _downloadImages(api, item, entry);
      await _downloadSubtitles(api, item, source, entry);

      final ext = (source.container ?? 'mkv').split(',').first;
      final target = File('${entry.folder}\\media.$ext');
      final part = File('${target.path}.part');
      final already = await part.exists() ? await part.length() : 0;

      final dio = Dio(BaseOptions(headers: {'Authorization': api.authorizationHeader}));
      final response = await dio.get<ResponseBody>(
        api.streamUrl(item.id, mediaSourceId: source.id),
        options: Options(responseType: ResponseType.stream, headers: {if (already > 0) 'Range': 'bytes=$already-'}),
        cancelToken: _cancel,
      );
      // Server ignoriert Range → von vorn beginnen.
      final resumed = response.statusCode == 206;
      final contentLength = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
      var received = resumed ? already : 0;
      final total = resumed ? already + contentLength : contentLength;
      final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;
          _reportProgress(entry.itemId, received, total);
        }
      } finally {
        await sink.close();
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      _update(
        entry.itemId,
        (e) =>
            e.copyWith(status: DownloadStatus.done, received: received, total: received, mediaFile: () => target.path),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Pausiert oder gelöscht – Status wurde schon gesetzt.
      } else {
        _update(
          entry.itemId,
          (x) => x.copyWith(status: DownloadStatus.failed, error: () => e.message ?? 'Netzwerkfehler'),
        );
      }
    } catch (e) {
      _update(entry.itemId, (x) => x.copyWith(status: DownloadStatus.failed, error: () => '$e'));
    } finally {
      _runningId = null;
      _cancel = null;
      _pump();
    }
  }

  Future<void> _downloadImages(JellyfinApi api, BaseItem item, DownloadEntry entry) async {
    final dio = Dio();
    final poster = api.imageUrlOrNull(Images.poster(item), fillWidth: 400, fillHeight: 600);
    final backdrop = api.imageUrlOrNull(Images.landscape(item), maxWidth: 1280);
    for (final (url, path) in [(poster, entry.posterPath), (backdrop, entry.backdropPath)]) {
      if (url == null) continue;
      try {
        await dio.download(url, path);
      } catch (_) {}
    }
  }

  Future<void> _downloadSubtitles(JellyfinApi api, BaseItem item, MediaSource source, DownloadEntry entry) async {
    final dio = Dio(BaseOptions(headers: {'Authorization': api.authorizationHeader}));
    for (final s in source.mediaStreams.where((s) => s.type == 'Subtitle' && s.isExternal)) {
      final url = api.subtitleUrl(item.id, source.id, s);
      try {
        await dio.download(url, '${entry.folder}\\subtitle_${s.index}.${url.split('.').last}');
      } catch (_) {}
    }
  }

  void _reportProgress(String itemId, int received, int total) {
    final now = DateTime.now();
    if (now.difference(_lastProgressUpdate) < const Duration(milliseconds: 400)) return;
    _lastProgressUpdate = now;
    _update(itemId, (e) => e.copyWith(received: received, total: total));
  }

  void _update(String itemId, DownloadEntry Function(DownloadEntry e) change) {
    _set([for (final e in state) e.itemId == itemId ? change(e) : e]);
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

/// Fertiger Download eines Titels (oder `null`).
final downloadedProvider = Provider.family<DownloadEntry?, String>((ref, itemId) {
  final entries = ref.watch(downloadsProvider);
  return entries.where((e) => e.itemId == itemId).firstOrNull;
});

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} GB';
}
