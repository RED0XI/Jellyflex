import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

import '../features/player/player_screen.dart';
import 'error_report.dart';
import 'images.dart';
import 'jellyfin_api.dart';
import 'models.dart';
import 'platform/app_paths.dart';
import 'session.dart';
import 'settings.dart';
import 'version.dart';

/// Leistungstest, den der Benutzer selbst startet (Einstellungen → Über).
///
/// Misst mit dem echten Server: Antwortzeiten, Bibliotheken, Suche, Bilder,
/// Netz-Durchsatz, flüssiges Scrollen, Wiedergabe und Arbeitsspeicher. Das
/// Ergebnis ist ein JSON-Bericht ohne persönliche Angaben – keine Adresse,
/// keine Namen, keine Titel, keine IDs; nur Typen, Anzahlen und Zeiten.
/// Verschickt wird nichts.
class PerformanceCheck {
  PerformanceCheck({
    required this.api,
    required this.session,
    required this.settings,
    required this.router,
    required this.onProgress,
    this.playback = true,
  });

  final JellyfinApi api;
  final AuthSession session;
  final AppSettings settings;
  final GoRouter router;

  /// Auch kurz einen Film abspielen (stumm, 20 s).
  final bool playback;

  /// Aktueller Schritt (Text) und Fortschritt 0–1.
  final void Function(String step, double progress) onProgress;

  static const _steps = 9;
  int _step = 0;
  final _report = <String, Object?>{};

  /// Größte Bibliothek (für Scrollen) und ein Film (für Durchsatz und Wiedergabe).
  BaseItem? _scrollLibrary;
  BaseItem? _movie;

  void _progress(String step) => onProgress(step, _step++ / _steps);

  Future<Map<String, Object?>> run() async {
    final total = Stopwatch()..start();
    _report['format'] = 1;
    _report['created'] = DateTime.now().toIso8601String().substring(0, 19);
    _report['system'] = _system();
    _report['memoryStartMb'] = _rssMb();

    await _section('server', 'Server', _server);
    await _section('home', 'Startseite', _home);
    await _section('libraries', 'Bibliotheken', _libraries);
    await _section('search', 'Suche', _search);
    await _section('images', 'Bilder', _images);
    await _section('throughput', 'Netz', _throughput);
    await _section('scrolling', 'Scrollen', _scrolling);
    if (playback) {
      await _section('playback', 'Wiedergabe', _playback);
    } else {
      _step++;
      _report['playback'] = {'skipped': true};
    }
    _progress('Arbeitsspeicher');
    _report['memory'] = {
      'currentMb': _rssMb(),
      'peakMb': ProcessInfo.maxRss ~/ (1024 * 1024),
      'imageCacheMb': PaintingBinding.instance.imageCache.currentSizeBytes ~/ (1024 * 1024),
      'imageCacheCount': PaintingBinding.instance.imageCache.currentSize,
    };
    _report['durationS'] = total.elapsed.inSeconds;
    onProgress('', 1);
    return _report;
  }

  /// Bericht als Text – zur Sicherheit noch einmal bereinigt.
  String encode(Map<String, Object?> report) =>
      scrubReport(const JsonEncoder.withIndent('  ').convert(report), session: session);

  /// Ordner für den Bericht; Tests setzen einen eigenen.
  @visibleForTesting
  static Directory? saveFolder;

  /// Speichert unter `Downloads/jellyflex-leistungstest-JJJJMMTTHHMM.json`.
  Future<File> save(Map<String, Object?> report) async {
    final folder = saveFolder ?? Directory(AppPaths.downloads);
    await folder.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(RegExp('[-:T]'), '');
    final file = File(AppPaths.join(folder.path, 'jellyflex-leistungstest-$stamp.json'));
    await file.writeAsString(encode(report));
    return file;
  }

  /// Ein Abschnitt; schlägt er fehl, steht nur die Art des Fehlers im Bericht.
  Future<void> _section(String key, String label, Future<Map<String, Object?>> Function() measure) async {
    _progress(label);
    try {
      _report[key] = await measure();
    } catch (e) {
      _report[key] = {'error': _describe(e)};
    }
  }

  static String _describe(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      return 'http ${status ?? e.type.name}';
    }
    if (e is TimeoutException) return 'timeout';
    return e.runtimeType.toString();
  }

  static int _rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  Map<String, Object?> _system() {
    final view = ui.PlatformDispatcher.instance.implicitView;
    final display = view?.display;
    return {
      'appVersion': appVersion,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'cpuCores': Platform.numberOfProcessors,
      'releaseBuild': kReleaseMode,
      if (display != null) ...{
        'displayPx': '${display.size.width.round()}x${display.size.height.round()}',
        'displayHz': display.refreshRate.round(),
        'pixelRatio': display.devicePixelRatio,
      },
      if (view != null) 'windowPx': '${view.physicalSize.width.round()}x${view.physicalSize.height.round()}',
      'settings': {
        'layout': settings.layoutId,
        'theme': settings.themeId,
        'maxBitrate': settings.maxBitrate,
        'imageCacheMb': settings.imageCacheMb,
        'hoverPreview': settings.hoverPreview,
        'bannerTrailers': settings.bannerTrailers,
        'ambilight': settings.ambilight.name,
      },
    };
  }

  /// Misst eine Anfrage: Zeit in ms und (ungepackte) Größe der Antwort in KB.
  Future<({T value, double ms, double kb})> _timed<T>(Future<T> Function() request) async {
    var bytes = 0;
    final probe = InterceptorsWrapper(
      onResponse: (res, handler) {
        final data = res.data;
        if (data is Map || data is List) bytes += utf8.encode(jsonEncode(data)).length;
        handler.next(res);
      },
    );
    api.dio.interceptors.add(probe);
    final watch = Stopwatch()..start();
    try {
      final value = await request().timeout(const Duration(seconds: 30));
      return (value: value, ms: _ms(watch), kb: _round(bytes / 1024));
    } finally {
      api.dio.interceptors.remove(probe);
    }
  }

  static double _ms(Stopwatch watch) => _round(watch.elapsedMicroseconds / 1000);
  static double _round(num value) => (value * 10).round() / 10;

  /// Kennzahlen einer Messreihe.
  static Map<String, Object?> stats(List<num> values) {
    if (values.isEmpty) return {'n': 0};
    final sorted = [...values]..sort();
    num at(double q) => sorted[((sorted.length - 1) * q).round()];
    return {
      'n': sorted.length,
      'min': _round(sorted.first),
      'median': _round(at(0.5)),
      'p90': _round(at(0.9)),
      'max': _round(sorted.last),
      'avg': _round(sorted.reduce((a, b) => a + b) / sorted.length),
    };
  }

  // --- Abschnitte ---------------------------------------------------------------

  Future<Map<String, Object?>> _server() async {
    final pings = <double>[];
    for (var i = 0; i < 10; i++) {
      final watch = Stopwatch()..start();
      await api.dio.get<String>('/System/Ping', options: Options(responseType: ResponseType.plain));
      pings.add(_ms(watch));
    }
    final info = await api.dio.get<dynamic>('/System/Info/Public');
    final version = info.data is Map ? (info.data as Map)['Version'] : null;
    return {
      'https': session.serverUrl.startsWith('https'),
      'version': version is String ? version : null,
      'pingMs': stats(pings),
    };
  }

  Future<Map<String, Object?>> _home() async {
    final result = <String, Object?>{};
    final views = await _timed(api.getUserViews);
    result['views'] = {'ms': views.ms, 'kb': views.kb, 'count': views.value.length};
    for (final (key, request) in [
      ('resume', () => api.getResume()),
      ('nextUp', () => api.getNextUp()),
      ('featured', () => api.getFeatured()),
    ]) {
      final r = await _timed(request);
      result[key] = {'ms': r.ms, 'kb': r.kb, 'count': r.value.length};
    }
    final latest = <Map<String, Object?>>[];
    for (final view in views.value.take(6)) {
      final r = await _timed(() => api.getLatest(view.id));
      latest.add({'type': view.collectionType ?? 'mixed', 'ms': r.ms, 'kb': r.kb, 'count': r.value.length});
    }
    result['latest'] = latest;
    // Alles wie beim Öffnen der Startseite gleichzeitig.
    final watch = Stopwatch()..start();
    await Future.wait([
      api.getResume(),
      api.getNextUp(),
      api.getFeatured(),
      for (final view in views.value.take(6)) api.getLatest(view.id),
    ]);
    result['allParallelMs'] = _ms(watch);
    return result;
  }

  Future<Map<String, Object?>> _libraries() async {
    final views = await api.getUserViews();
    var countData = const <dynamic, dynamic>{};
    try {
      final counts = await api.dio.get<dynamic>('/Items/Counts', queryParameters: {'userId': api.userId});
      if (counts.data is Map) countData = counts.data as Map;
    } on DioException {
      // Ohne Gesamtzahlen geht es auch.
    }
    final libraries = <Map<String, Object?>>[];
    var largest = 0;
    for (final view in views) {
      final type = view.collectionType;
      final include = switch (type) {
        'movies' => 'Movie',
        'tvshows' => 'Series',
        _ => null,
      };
      if (include == null) {
        libraries.add({'type': type ?? 'mixed', 'measured': false});
        continue;
      }
      // Wie die Bibliotheksseite: Seiten zu 100, höchstens 20 Seiten.
      final first = await _timed(
        () => api.getLibraryPage(
          parentId: view.id,
          includeItemTypes: include,
          sortBy: 'SortName',
          sortOrder: 'Ascending',
        ),
      );
      final pages = <double>[first.ms];
      final kb = <double>[first.kb];
      final total = first.value.totalCount;
      for (var start = 100; start < total && pages.length < 20; start += 100) {
        final page = await _timed(
          () => api.getLibraryPage(
            parentId: view.id,
            includeItemTypes: include,
            sortBy: 'SortName',
            sortOrder: 'Ascending',
            startIndex: start,
          ),
        );
        pages.add(page.ms);
        kb.add(page.kb);
      }
      if (total > largest) {
        largest = total;
        _scrollLibrary = view;
      }
      if (type == 'movies' && _movie == null && first.value.items.isNotEmpty) {
        // Ein Film, den der Benutzer nicht angefangen hat – damit "Weiterschauen" unberührt bleibt.
        _movie = first.value.items.firstWhere(
          (m) => m.userData.playbackPositionTicks == 0,
          orElse: () => first.value.items.first,
        );
      }
      // Detailseite: ein Eintrag mit allen Feldern.
      double? detailMs;
      if (first.value.items.isNotEmpty) {
        final detail = await _timed(() => api.getItem(first.value.items.first.id));
        detailMs = detail.ms;
      }
      libraries.add({'type': type, 'items': total, 'pageMs': stats(pages), 'pageKb': stats(kb), 'detailMs': detailMs});
    }
    return {
      'counts': {
        for (final key in ['MovieCount', 'SeriesCount', 'EpisodeCount', 'BoxSetCount'])
          if (countData[key] is int) key: countData[key],
      },
      'list': libraries,
    };
  }

  Future<Map<String, Object?>> _search() async {
    final results = <Map<String, Object?>>[];
    final times = <double>[];
    for (final term in ['a', 'the', 'star', 'love', 'man', 'zz']) {
      final r = await _timed(() => api.search(term));
      times.add(r.ms);
      results.add({'termLength': term.length, 'ms': r.ms, 'kb': r.kb, 'results': r.value.length});
    }
    return {'ms': stats(times), 'terms': results};
  }

  /// Bilder direkt vom Server (am Zwischenspeicher vorbei) und das Dekodieren.
  Future<Map<String, Object?>> _images() async {
    final library = _scrollLibrary;
    if (library == null) return {'skipped': 'no library'};
    final page = await api.getLibraryPage(
      parentId: library.id,
      includeItemTypes: library.collectionType == 'tvshows' ? 'Series' : 'Movie',
      sortBy: 'Random',
      sortOrder: 'Ascending',
      limit: 24,
    );
    final urls = [
      for (final item in page.items) ?api.imageUrlOrNull(Images.poster(item), fillWidth: 300, fillHeight: 450),
    ];
    final download = <double>[];
    final decode = <double>[];
    final kb = <double>[];
    Future<void> load(String url) async {
      final watch = Stopwatch()..start();
      final res = await api.dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      download.add(_ms(watch));
      final bytes = Uint8List.fromList(res.data ?? const []);
      kb.add(bytes.length / 1024);
      final decodeWatch = Stopwatch()..start();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decode.add(_ms(decodeWatch));
      frame.image.dispose();
      codec.dispose();
    }

    // Erst einzeln, dann sechs gleichzeitig (wie beim Scrollen durch ein Raster).
    for (final url in urls.take(12)) {
      await load(url);
    }
    final single = stats(download);
    download.clear();
    final watch = Stopwatch()..start();
    final rest = urls.skip(12).toList();
    for (var i = 0; i < rest.length; i += 6) {
      await Future.wait(rest.skip(i).take(6).map(load));
    }
    return {
      'singleMs': single,
      'parallel6Ms': stats(download),
      'parallelTotalMs': _ms(watch),
      'parallelCount': rest.length,
      'kb': stats(kb),
      'decodeMs': stats(decode),
    };
  }

  /// Wie schnell kommen Videodaten an? Bis 40 MB oder 10 s vom Anfang eines Films.
  Future<Map<String, Object?>> _throughput() async {
    final movie = _movie;
    if (movie == null) return {'skipped': 'no movie'};
    final info = await api.getPlaybackInfo(movie.id);
    final source = info.mediaSources.firstOrNull;
    if (source == null) return {'skipped': 'no source'};
    final cancel = CancelToken();
    final watch = Stopwatch()..start();
    var bytes = 0;
    double? firstByteMs;
    try {
      final res = await api.dio.get<ResponseBody>(
        api.streamUrl(movie.id, mediaSourceId: source.id),
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancel,
      );
      await for (final chunk in res.data!.stream.timeout(const Duration(seconds: 10))) {
        firstByteMs ??= _ms(watch);
        bytes += chunk.length;
        if (bytes >= 40 * 1024 * 1024 || watch.elapsed > const Duration(seconds: 10)) break;
      }
    } finally {
      cancel.cancel();
    }
    final seconds = watch.elapsedMicroseconds / 1e6;
    return {
      'firstByteMs': firstByteMs,
      'mb': _round(bytes / 1024 / 1024),
      'seconds': _round(seconds),
      'mbit': _round(bytes * 8 / 1e6 / seconds),
      'fileMbit': source.bitrate == null ? null : _round(source.bitrate! / 1e6),
    };
  }

  /// Öffnet die größte Bibliothek, scrollt hinunter und wieder hinauf und
  /// zählt, wie lange jedes Bild zum Zeichnen brauchte.
  Future<Map<String, Object?>> _scrolling() async {
    final library = _scrollLibrary;
    if (library == null) return {'skipped': 'no library'};
    final memoryBefore = _rssMb();
    router.push(Uri(path: '/library/${library.id}', queryParameters: {'type': ?library.collectionType}).toString());
    try {
      await Future<void>.delayed(const Duration(seconds: 3));
      final scrollable = _currentScrollable();
      if (scrollable == null) return {'skipped': 'no scroll view'};
      final position = scrollable.position;
      final timings = <ui.FrameTiming>[];
      void collect(List<ui.FrameTiming> t) => timings.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final watch = Stopwatch()..start();
      // 10 s mit etwa 2500 px/s hinunter (das Raster lädt unterwegs nach), dann zügig hinauf.
      for (var i = 0; i < 10 && position.pixels < position.maxScrollExtent; i++) {
        await position.animateTo(
          (position.pixels + 2500).clamp(0, position.maxScrollExtent),
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
      }
      final scrolledPx = position.pixels;
      await position.animateTo(0, duration: const Duration(seconds: 3), curve: Curves.easeInOut);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      final hz = ui.PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 60;
      final budgetMs = 1000 / hz;
      double ms(Duration d) => d.inMicroseconds / 1000;
      final build = [for (final t in timings) ms(t.buildDuration)];
      final raster = [for (final t in timings) ms(t.rasterDuration)];
      final total = [for (final t in timings) ms(t.totalSpan)];
      final slow = [for (var i = 0; i < timings.length; i++) build[i] > budgetMs || raster[i] > budgetMs]
          .where((s) => s);
      return {
        'scrolledPx': scrolledPx.round(),
        'seconds': _round(watch.elapsedMilliseconds / 1000),
        'frames': timings.length,
        'budgetMs': _round(budgetMs),
        'slowFrames': slow.length,
        'smoothPercent': timings.isEmpty ? null : _round(100 - slow.length * 100 / timings.length),
        'buildMs': stats(build),
        'rasterMs': stats(raster),
        'totalMs': stats(total),
        'memoryBeforeMb': memoryBefore,
        'memoryAfterMb': _rssMb(),
      };
    } finally {
      if (router.canPop()) router.pop();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Die längste senkrechte Liste der obersten Seite.
  static ScrollableState? _currentScrollable() {
    ScrollableState? best;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final route = ModalRoute.of(element);
        if ((route?.isCurrent ?? false) &&
            state.position.axis == Axis.vertical &&
            state.position.hasContentDimensions &&
            state.position.maxScrollExtent > (best?.position.maxScrollExtent ?? 0)) {
          best = state;
        }
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return best;
  }

  /// Spielt den Film 20 s stumm im Fenster und liest aus mpv Dekoder und verlorene Bilder.
  Future<Map<String, Object?>> _playback() async {
    final movie = _movie;
    if (movie == null) return {'skipped': 'no movie'};
    Player? player;
    final previousHook = PlayerScreen.debugBeforeOpen;
    PlayerScreen.debugBeforeOpen = (p) async {
      player = p;
      await previousHook?.call(p);
    };
    final memoryBefore = _rssMb();
    final watch = Stopwatch()..start();
    router.push('/play/${movie.id}?start=0');
    try {
      for (var i = 0; i < 300 && player == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final p = player;
      if (p == null) return {'error': 'player did not open'};
      final native = p.platform;
      if (native is NativePlayer) await native.setProperty('mute', 'yes');
      // Bis das erste Bild läuft (höchstens 30 s).
      while (watch.elapsed < const Duration(seconds: 30) && (p.state.position == Duration.zero || p.state.buffering)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final startMs = _ms(watch);
      Future<String> prop(String name) async {
        if (native is! NativePlayer) return '?';
        try {
          return await native.getProperty(name);
        } catch (_) {
          return '?';
        }
      }

      await Future<void>.delayed(const Duration(seconds: 3));
      final dropsBefore = int.tryParse(await prop('frame-drop-count')) ?? 0;
      final decoderBefore = int.tryParse(await prop('decoder-frame-drop-count')) ?? 0;
      final positionBefore = p.state.position;
      var stalls = 0;
      var wasBuffering = false;
      final measure = Stopwatch()..start();
      while (measure.elapsed < const Duration(seconds: 20)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (p.state.buffering && !wasBuffering) stalls++;
        wasBuffering = p.state.buffering;
      }
      final played = p.state.position - positionBefore;
      final fps = double.tryParse(await prop('container-fps')) ?? 0;
      return {
        'startMs': startMs,
        'codec': await prop('video-codec'),
        'resolution': '${await prop('video-params/w')}x${await prop('video-params/h')}',
        'gamma': await prop('video-params/gamma'),
        'hwdec': await prop('hwdec-current'),
        'fps': _round(fps),
        'playedS': _round(played.inMilliseconds / 1000),
        'measuredS': 20,
        'stalls': stalls,
        'droppedFrames': (int.tryParse(await prop('frame-drop-count')) ?? 0) - dropsBefore,
        'decoderDroppedFrames': (int.tryParse(await prop('decoder-frame-drop-count')) ?? 0) - decoderBefore,
        'expectedFrames': (fps * played.inMilliseconds / 1000).round(),
        'cacheS': double.tryParse(await prop('demuxer-cache-duration'))?.round(),
        'memoryBeforeMb': memoryBefore,
        'memoryDuringMb': _rssMb(),
      };
    } finally {
      PlayerScreen.debugBeforeOpen = previousHook;
      if (router.canPop()) router.pop();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}
