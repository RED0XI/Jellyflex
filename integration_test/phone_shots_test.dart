// Bildschirmfotos im iPhone-Format: Startseite (oben und gescrollt) und Detailseite je Layout –
// zum Vergleichen von Größen auf dem Telefon. Im iPhone-Simulator starten:
//
//   dart run tool/mock_server.dart
//   flutter test integration_test/phone_shots_test.dart -d <iPhone-Simulator>
//
// Die Bilder landen in --dart-define=SHOT_DIR=<Ordner auf dem Mac> (sonst im Temp-Ordner der App,
// den `flutter test` danach mitsamt der App löscht).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Telefon-Bildschirmfotos', (tester) async {
    if (!await demoServerRunning()) return;
    final temp = Directory.systemTemp.createTempSync('jellyflex_phone_');
    // Im Simulator darf die App auch direkt in einen Ordner des Macs schreiben (--dart-define=SHOT_DIR=…).
    const target = String.fromEnvironment('SHOT_DIR');
    final out = Directory(target.isEmpty ? '${Directory.systemTemp.path}/jf_phone_shots' : target)
      ..createSync(recursive: true);

    Future<void> shot(String name) async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      final file = File('${out.path}/$name.png')..writeAsBytesSync(bytes!.buffer.asUint8List());
      debugPrint('PHONE_SHOT ${file.path}');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings(temp)),
        ],
        // Fester iPhone-Rahmen (iPhone 17 Pro hochkant) – egal, wie der Simulator gerade steht.
        child: Center(
          child: FittedBox(
            child: SizedBox(
              width: 402,
              height: 874,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(402, 874),
                    padding: const EdgeInsets.only(top: 62, bottom: 34),
                    viewPadding: const EdgeInsets.only(top: 62, bottom: 34),
                  ),
                  child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final settings = container.read(settingsProvider.notifier);
    final router = container.read(routerProvider);

    for (final layout in const ['cinema', 'couch']) {
      settings.update((s) => s.copyWith(layoutId: layout));
      router.go('/');
      await pumpFor(tester, const Duration(seconds: 3));
      await shot('${layout}_home');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await pumpFor(tester, const Duration(seconds: 2));
      await shot('${layout}_home_rows');
      router.push('/item/movie3');
      await pumpFor(tester, const Duration(seconds: 3));
      await shot('${layout}_details');
    }

    // Folge einer Serie: Weg zur Serie, Staffelwahl, kompakte Folgenliste.
    settings.update((s) => s.copyWith(layoutId: 'cinema'));
    router.go('/');
    await pumpFor(tester, const Duration(seconds: 1));
    router.push('/item/series0_s2_e3');
    await pumpFor(tester, const Duration(seconds: 3));
    await shot('episode');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await pumpFor(tester, const Duration(seconds: 2));
    await shot('episode_list');
    // Suche ohne Begriff: Genre-Kacheln.
    router.go('/search');
    await pumpFor(tester, const Duration(seconds: 3));
    await shot('search_genres');

    await tester.pumpWidget(const SizedBox());
    temp.deleteSync(recursive: true);
  });
}
