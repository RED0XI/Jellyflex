// Geschwindigkeits-Messung gegen den Demo-Server mit simuliert langsamem Netz
// (jedes Bild kommt 120 ms verzögert): erster Start, zweiter Start (Bilder aus
// dem Zwischenspeicher?), Detailseite, flüssiges Scrollen, Arbeitsspeicher.
// Ergebnis: build/perf/<PERF_LABEL>.json
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/perf_test.dart -d windows --dart-define=PERF_LABEL=vorher

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

const _label = String.fromEnvironment('PERF_LABEL', defaultValue: 'messung');

Future<Map<String, dynamic>> _images({int? delay, bool reset = false}) async {
  final query = [if (delay != null) 'delay=$delay', if (reset) 'reset=1'].join('&');
  final request = await HttpClient().getUrl(Uri.parse('$demoServer/debug/images?$query'));
  final response = await request.close();
  return jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
}

/// Wartet, bis mindestens [min] Bilder gebaut und alle davon geladen sind. Liefert die Zeit in ms.
Future<int> _untilImagesLoaded(WidgetTester tester, Stopwatch watch, {int min = 4}) async {
  while (watch.elapsedMilliseconds < 20000) {
    await tester.pump(const Duration(milliseconds: 20));
    final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    if (images.length >= min && images.every((i) => i.image != null)) return watch.elapsedMilliseconds;
  }
  final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  debugPrint('Bilder: ${images.length}, davon ungeladen: ${images.where((i) => i.image == null).length}');
  return -1;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Geschwindigkeit', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_perf_');
    final results = <String, Object>{'label': _label, 'time': DateTime.now().toIso8601String()};

    Widget app() => ProviderScope(
      overrides: [
        sessionProvider.overrideWith(DemoSession.new),
        settingsProvider.overrideWith(() => testSettings(temp)),
      ],
      child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
    );

    Future<void> start(String name) async {
      // Wie ein frischer App-Start: keine Bilder im Arbeitsspeicher.
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await tester.runAsync(() => _images(reset: true));
      final watch = Stopwatch()..start();
      await tester.pumpWidget(app());
      results['${name}_bilder_ms'] = await _untilImagesLoaded(tester, watch);
      await pumpFor(tester, const Duration(seconds: 2));
      results['${name}_bild_anfragen'] = (await tester.runAsync(() => _images()))!['requests'] as int;
    }

    try {
      await tester.runAsync(() => _images(delay: 120));
      await start('start1');
      await start('start2');

      // Detailseite öffnen.
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final router = container.read(routerProvider);
      var watch = Stopwatch()..start();
      router.push('/item/movie3');
      results['details_bilder_ms'] = await _untilImagesLoaded(tester, watch, min: 3);
      router.pop();
      await pumpFor(tester, const Duration(seconds: 1));

      // Scrollen auf der Startseite: Zeit je Bild (Aufbau + Zeichnen).
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> t) => timings.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollable, const Offset(0, 300));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }
      await pumpFor(tester, const Duration(seconds: 1));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      if (timings.isNotEmpty) {
        final build = timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()..sort();
        final raster = timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()..sort();
        double p90(List<double> l) => l[(l.length * 0.9).floor().clamp(0, l.length - 1)];
        results['scroll_bilder'] = timings.length;
        results['scroll_aufbau_p90_ms'] = double.parse(p90(build).toStringAsFixed(2));
        results['scroll_zeichnen_p90_ms'] = double.parse(p90(raster).toStringAsFixed(2));
      }

      results['arbeitsspeicher_mb'] = (ProcessInfo.currentRss / 1024 / 1024).round();
      results['arbeitsspeicher_max_mb'] = (ProcessInfo.maxRss / 1024 / 1024).round();
      results['bildspeicher_mb'] = (PaintingBinding.instance.imageCache.currentSizeBytes / 1024 / 1024).round();

      final out = File('build/perf/$_label.json')..createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
      debugPrint('PERF ${jsonEncode(results)}');
      expect(results['start1_bilder_ms'], isNot(-1), reason: 'Startseite hat ihre Bilder geladen');
    } finally {
      await tester.runAsync(() => _images(delay: 0));
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
