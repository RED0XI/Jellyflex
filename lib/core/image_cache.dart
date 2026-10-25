import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'platform/app_paths.dart';

/// Bilder vom Server (Poster, Hintergründe …) auf der Festplatte zwischenspeichern:
/// Beim nächsten Start sind sie sofort da und müssen nicht erneut geladen werden.
///
/// - Feste Obergrenze ([maxBytes]); darüber werden die am längsten nicht
///   benutzten Bilder gelöscht.
/// - Nur Bilder, keine Zugangsdaten (Bildadressen von Jellyfin brauchen kein Token).
/// - Liegt in %LOCALAPPDATA% bzw. ~/Library/Caches (wird nicht synchronisiert/gesichert)
///   und lässt sich in den Einstellungen leeren.
class ImageDiskCache {
  ImageDiskCache._();

  static final instance = ImageDiskCache._();

  /// Größte Bilddatei, die angenommen wird (Schutz vor riesigen Antworten).
  static const maxImageBytes = 20 * 1024 * 1024;

  Directory directory = Directory(AppPaths.join(AppPaths.cache.path, 'ImageCache'));

  /// Obergrenze in Bytes; 0 = nichts auf der Festplatte speichern.
  int maxBytes = 300 * 1024 * 1024;

  late final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 20)
    // Nicht mit Dutzenden gleichzeitigen Verbindungen auf den Server einprügeln.
    ..maxConnectionsPerHost = 12;

  /// Vom Server geladene Bilder (nicht aus dem Zwischenspeicher) – für Messungen.
  int downloads = 0;

  int? _knownSize;
  Future<void>? _trimming;

  /// Bild laden: von der Festplatte, sonst vom Server (und dann speichern).
  /// [headers] z. B. für die Anmeldung bei Bildern, die sie verlangen (Trickplay).
  Future<Uint8List> load(String url, {Map<String, String> headers = const {}}) async {
    final file = _fileFor(url);
    if (maxBytes > 0) {
      final cached = await _read(file, url);
      if (cached != null) return cached;
    }
    final bytes = await _download(url, headers);
    if (maxBytes > 0) unawaited(_write(file, url, bytes));
    return bytes;
  }

  /// Gespeichertes Bild verwerfen (z. B. weil es sich nicht dekodieren ließ).
  Future<void> forget(String url) async {
    try {
      await _fileFor(url).delete();
    } catch (_) {}
  }

  /// Belegter Platz in Bytes.
  Future<int> sizeBytes() async {
    var total = 0;
    try {
      await for (final f in directory.list()) {
        if (f is File) total += await f.length();
      }
    } catch (_) {}
    _knownSize = total;
    return total;
  }

  /// Alles löschen (auch aus dem Arbeitsspeicher).
  Future<void> clear() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // Einzelne Dateien können gerade gelesen werden – der Rest ist trotzdem weg.
    }
    _knownSize = 0;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// Auf die Obergrenze kürzen (älteste zuerst, bis 90 % der Grenze).
  Future<void> trim() => _trimming ??= _trim().whenComplete(() => _trimming = null);

  // --- Interna --------------------------------------------------------------

  /// Dateiname aus der Adresse (64-Bit-FNV-1a). Die Adresse steht zusätzlich in
  /// der Datei, damit eine (sehr unwahrscheinliche) Namensgleichheit nie ein
  /// falsches Bild liefert.
  File _fileFor(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return File(AppPaths.join(directory.path, '${half(hash >>> 32)}${half(hash)}.img'));
  }

  Future<Uint8List?> _read(File file, String url) async {
    try {
      final data = await file.readAsBytes();
      if (data.length < 4) return null;
      final urlLength = ByteData.sublistView(data, 0, 4).getUint32(0);
      if (4 + urlLength > data.length || utf8.decode(data.sublist(4, 4 + urlLength)) != url) return null;
      // Zuletzt benutzt merken (für das Aufräumen) – höchstens einmal am Tag schreiben.
      unawaited(_touch(file));
      return Uint8List.sublistView(data, 4 + urlLength);
    } catch (_) {
      return null; // nicht vorhanden oder beschädigt → neu laden
    }
  }

  Future<void> _touch(File file) async {
    try {
      final now = DateTime.now();
      if (now.difference(await file.lastModified()).inHours >= 24) await file.setLastModified(now);
    } catch (_) {}
  }

  Future<Uint8List> _download(String url, Map<String, String> headers) async {
    downloads++;
    final origin = Uri.parse(url);
    var uri = origin;
    HttpClientResponse response;
    // Weiterleitungen nur innerhalb desselben Servers – Bilder sollen nie bei anderen Diensten
    // landen (die so erfahren könnten, was man sich gerade ansieht).
    for (var hops = 0; ; hops++) {
      final request = await _client.getUrl(uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      response = await request.close().timeout(const Duration(seconds: 30));
      if (!response.isRedirect) break;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>().catchError((_) {});
      final next = location == null ? null : uri.resolve(location);
      if (next == null || hops >= 3 || !_sameOrigin(next, origin)) {
        throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
      }
      uri = next;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().catchError((_) {});
      throw NetworkImageLoadException(statusCode: response.statusCode, uri: Uri.parse(url));
    }
    if (response.contentLength > maxImageBytes) {
      await response.drain<void>().catchError((_) {});
      throw const FormatException('Bild zu groß');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      builder.add(chunk);
      if (builder.length > maxImageBytes) throw const FormatException('Bild zu groß');
    }
    return builder.takeBytes();
  }

  static bool _sameOrigin(Uri a, Uri b) => a.scheme == b.scheme && a.host == b.host && a.port == b.port;

  Future<void> _write(File file, String url, Uint8List bytes) async {
    try {
      await directory.create(recursive: true);
      final urlBytes = utf8.encode(url);
      final header = ByteData(4)..setUint32(0, urlBytes.length);
      // Erst vollständig schreiben, dann umbenennen – nie halbe Dateien im Speicher.
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(
        (BytesBuilder(copy: false)
              ..add(header.buffer.asUint8List())
              ..add(urlBytes)
              ..add(bytes))
            .takeBytes(),
        flush: true,
      );
      await temp.rename(file.path);
      _knownSize = (_knownSize ?? await sizeBytes()) + bytes.length + urlBytes.length + 4;
      if (_knownSize! > maxBytes) await trim();
    } catch (_) {
      // Zwischenspeichern ist nur eine Beschleunigung – Fehler sind egal.
    }
  }

  Future<void> _trim() async {
    try {
      if (!await directory.exists()) return;
      final files = <(File, int, DateTime)>[];
      var total = 0;
      await for (final f in directory.list()) {
        if (f is! File) continue;
        final stat = await f.stat();
        files.add((f, stat.size, stat.modified));
        total += stat.size;
      }
      final target = maxBytes * 9 ~/ 10;
      if (total > maxBytes) {
        files.sort((a, b) => a.$3.compareTo(b.$3));
        for (final (file, size, _) in files) {
          if (total <= target) break;
          try {
            await file.delete();
            total -= size;
          } catch (_) {}
        }
      }
      _knownSize = total;
    } catch (_) {}
  }
}

/// Netzwerkbild mit Festplatten-Zwischenspeicher (siehe [ImageDiskCache]).
/// Wie `NetworkImage`, nur dass schon geladene Bilder beim nächsten Start
/// direkt von der Festplatte kommen.
@immutable
class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  const CachedNetworkImage(this.url, {this.headers = const {}});

  final String url;

  /// Zusätzliche Kopfzeilen (z. B. Anmeldung); gehören nicht zum Schlüssel des Bildes.
  final Map<String, String> headers;

  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedNetworkImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(key, decode), scale: 1, debugLabel: url);

  Future<ui.Codec> _load(CachedNetworkImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await ImageDiskCache.instance.load(url, headers: headers);
      if (bytes.isEmpty) throw StateError('Leeres Bild');
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Fehlgeschlagene Bilder weder im Speicher noch auf der Platte behalten –
      // später erneut versuchen.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      unawaited(ImageDiskCache.instance.forget(url));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedNetworkImage("$url")';
}
