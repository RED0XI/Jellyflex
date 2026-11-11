// Im Vollbild (F11) bleibt oben links der Zurück-Knopf, oben rechts "Vollbild beenden".
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/fullscreen_nav_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/widgets/window_frame.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Vollbild: Zurück und "Vollbild beenden" bleiben erreichbar', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final router = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp))).read(routerProvider);

    await setWindowFullscreen(true);
    router.push('/item/movie1');
    await pumpFor(tester, const Duration(seconds: 2));

    // Die Knöpfe der Fensterleiste (nicht die der Seite): sichtbar und anklickbar?
    Finder titleBar(IconData icon) => find.descendant(of: find.byType(WindowFrame), matching: find.byIcon(icon)).first;
    bool reachable(IconData icon) {
      final button = find.descendant(of: find.byType(WindowFrame), matching: find.byIcon(icon));
      if (button.evaluate().isEmpty) return false;
      return find
          .ancestor(of: button.first, matching: find.byType(IgnorePointer))
          .evaluate()
          .every((e) => !(e.widget as IgnorePointer).ignoring);
    }

    expect(reachable(Icons.arrow_back_rounded), isTrue, reason: 'Zurück-Knopf im Vollbild');
    expect(reachable(Icons.fullscreen_exit_rounded), isTrue, reason: 'Vollbild beenden');
    expect(reachable(Icons.remove_rounded), isFalse, reason: 'Fensterknöpfe gibt es im Vollbild nicht');
    await saveShot(tester, 'fullscreen_details');

    await tester.tap(titleBar(Icons.arrow_back_rounded));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(router.state.uri.path, '/');

    await tester.tap(titleBar(Icons.fullscreen_exit_rounded));
    // macOS verlässt das Vollbild mit einer Animation (eigener Space) – das kann dauern.
    for (var i = 0; i < 30 && windowFullscreen.value; i++) {
      await pumpFor(tester, const Duration(milliseconds: 200));
    }
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(windowFullscreen.value, isFalse);
    // Auf dem Mac sind es die Ampel-Knöpfe des Systems – keine eigenen.
    expect(reachable(Icons.remove_rounded), !Platform.isMacOS, reason: 'Fensterknöpfe wieder da');

    await tester.pumpWidget(const SizedBox());
  });
}
