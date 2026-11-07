// Flüssigkeit auf einem echten Gerät (iPhone, iPad, Fernseher): echtes Wischen auf der
// Startseite, einer Bibliothek und einer Detailseite, gemessen an den echten Frames.
// Ergebnis: build/integration_response_data.json (+ Ausgabe "DEVICE_PERF …") und beim
// Demo-Server unter build/device_reports/<PERF_LABEL>.json.
//
// Voraussetzung:  dart run tool/mock_server.dart --lan
// Start (iPhone): flutter drive --profile -d <Gerät> --driver=test_driver/integration_test.dart \
//                   --target=integration_test/device_perf_test.dart \
//                   --dart-define=DEMO_SERVER=http://<IP des Macs>:8097
// Drahtlos ohne Debugger (iPhone):
//   flutter build ios --profile -t integration_test/device_perf_test.dart --dart-define=…
//   xcrun devicectl device install app --device <ID> build/ios/iphoneos/Runner.app
//   xcrun devicectl device process launch --device <ID> io.github.red0xi.jellyflex

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/power.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

const _label = String.fromEnvironment('PERF_LABEL', defaultValue: 'device');

/// Kennzahlen aus den Frames einer Szene.
Map<String, Object> _summary(List<FrameTiming> t, double budgetMs) {
  if (t.isEmpty) return {'frames': 0};
  List<double> ms(Duration Function(FrameTiming) f) => t.map((x) => f(x).inMicroseconds / 1000).toList()..sort();
  double pct(List<double> l, double p) => l[(l.length * p).floor().clamp(0, l.length - 1)];
  double r(double v) => double.parse(v.toStringAsFixed(2));
  final build = ms((x) => x.buildDuration);
  final raster = ms((x) => x.rasterDuration);
  final total = ms((x) => x.totalSpan);
  return {
    'frames': t.length,
    'build_p50': r(pct(build, .5)),
    'build_p90': r(pct(build, .9)),
    'build_max': r(build.last),
    'raster_p50': r(pct(raster, .5)),
    'raster_p90': r(pct(raster, .9)),
    'raster_max': r(raster.last),
    'total_p90': r(pct(total, .9)),
    // Frames, die ihr Zeitfenster verpasst haben (Ruckler).
    'janky': t
        .where(
          (x) => x.buildDuration.inMicroseconds / 1000 > budgetMs || x.rasterDuration.inMicroseconds / 1000 > budgetMs,
        )
        .length,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Echte Frames im Takt des Displays statt künstlicher Test-Frames.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  MediaKit.ensureInitialized();

  testWidgets('Flüssigkeit auf dem Gerät', (tester) async {
    if (!await demoServerRunning()) return;
    await Power.init();
    final temp = Directory.systemTemp.createTempSync('jellyflex_devperf_');
    final hz = PlatformDispatcher.instance.views.first.display.refreshRate;
    final budget = 1000 / hz;
    final results = <String, Object>{
      'refresh_hz': hz.round(),
      'energy_saving': Power.energySaving.value,
      'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings(temp)),
        ],
        child: const JellyflexApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 4));
    final router = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp))).read(routerProvider);

    Future<void> scene(String name, Future<void> Function() body) async {
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> t) => timings.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      await body();
      await pumpFor(tester, const Duration(milliseconds: 600));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      results[name] = _summary(timings, budget);
      debugPrint('DEVICE_PERF $name ${jsonEncode(results[name])}');
    }

    Future<void> flings(Finder scrollable, {Offset by = const Offset(0, -500), int times = 5}) async {
      for (var i = 0; i < times; i++) {
        await tester.fling(scrollable, by, 1800);
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
      for (var i = 0; i < times; i++) {
        await tester.fling(scrollable, -by, 1800);
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
    }

    // Leerlauf: wie viele Frames zeichnet die Startseite, wenn niemand etwas tut?
    await scene('idle_home', () => pumpFor(tester, const Duration(seconds: 3)));
    await scene('scroll_home', () => flings(find.byType(Scrollable).first));
    // Reihe seitwärts wischen.
    final rows = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
    if (rows.evaluate().length > 1) {
      await scene('scroll_row', () => flings(rows.at(1), by: const Offset(-400, 0), times: 3));
    }
    await scene('open_details', () async {
      router.push('/item/movie3');
      await pumpFor(tester, const Duration(seconds: 2));
    });
    await scene('scroll_details', () => flings(find.byType(Scrollable).first, times: 3));
    await scene('back_home', () async {
      router.pop();
      await pumpFor(tester, const Duration(seconds: 1));
    });
    await scene('open_library', () async {
      router.go('/library/lib-movies');
      await pumpFor(tester, const Duration(seconds: 2));
    });
    await scene('scroll_library', () => flings(find.byType(Scrollable).first));

    results['rss_mb'] = (ProcessInfo.currentRss / 1024 / 1024).round();
    results['image_cache_mb'] = (PaintingBinding.instance.imageCache.currentSizeBytes / 1024 / 1024).round();
    debugPrint('DEVICE_PERF ${jsonEncode(results)}');
    binding.reportData = results;
    // Auch an den Demo-Server – drahtlos findet `flutter drive` das Gerät oft nicht (dann die
    // App ohne Debugger starten, siehe oben).
    await tester.runAsync(() async {
      try {
        final request = await HttpClient().postUrl(Uri.parse('$demoServer/debug/report?name=$_label'));
        request.write(jsonEncode(results));
        await (await request.close()).drain<void>();
      } catch (e) {
        debugPrint('Messung nicht gesendet: $e');
      }
    });
    await tester.pumpWidget(const SizedBox());
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });
}
