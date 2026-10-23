// Kapitel als "Szenen" auf der Detailseite: Reihe mit Vorschaubildern,
// Klick startet an der Stelle des Kapitels.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/scenes_test.dart -d windows

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Szenen auf der Detailseite', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    PlayerScreen.debugBeforeOpen = (p) async => p.pause();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings()),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 2));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final router = container.read(routerProvider);
      router.push('/item/movie0');
      await pumpFor(tester, const Duration(seconds: 2));

      // Die Reihe liegt unter dem Kopfbereich – erst hinscrollen (Reihen entstehen erst sichtbar).
      for (var i = 0; i < 6 && find.text('Szenen').evaluate().isEmpty; i++) {
        // Mausrad (die Seite scrollt weich per Rad, nicht per Ziehen).
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(const Offset(600, 400));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }
      await tester.ensureVisible(find.text('Szenen'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Der Sturm'), findsOneWidget);
      expect(find.text('40:00'), findsOneWidget, reason: 'Startzeit auf dem Bild');
      await saveShot(tester, 'scenes');

      // Film nicht im Rechner geladen? Kein Problem: Wichtig ist die Startstelle.
      await tester.tap(find.text('Der Sturm'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(router.state.uri.path, '/play/movie0');
      expect(router.state.uri.queryParameters['start'], '${40 * 60 * 10000000}');
      router.pop();
      await pumpFor(tester, const Duration(seconds: 1));
    } finally {
      PlayerScreen.debugBeforeOpen = null;
    }
  });

  testWidgets('Viele Staffeln bleiben im Fenster', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => testSettings())],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).push('/item/series5');
    await pumpFor(tester, const Duration(seconds: 3));
    final last = find.text('Staffel 18');
    await tester.ensureVisible(last);
    await pumpFor(tester, const Duration(milliseconds: 500));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getRect(last).right, lessThan(width), reason: 'Letzte Staffel sichtbar im Fenster');
    final chip = find.ancestor(of: last, matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(chip).width, lessThan(220), reason: 'Knopf so breit wie sein Text');
    expect(tester.getSize(chip).height, 44);
    expect(tester.getRect(last).top, greaterThan(tester.getRect(find.text('Staffel 1')).top), reason: 'Umbruch');
    await tester.tap(last);
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Staffel 1'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await saveShot(tester, 'many_seasons');
  });
}
