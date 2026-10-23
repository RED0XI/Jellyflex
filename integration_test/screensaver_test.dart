// Prüft den Bildschirmschoner gegen den Demo-Server: Vorschau starten, Bilder
// und Uhr, Beenden per Taste (ohne dass die Taste darunter etwas auslöst) und
// per Mausbewegung.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/screensaver_test.dart -d windows

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/format.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/screensaver/screensaver.dart';
import 'package:jellyflex/features/search/search_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Bildschirmschoner: anzeigen und beenden', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_screensaver_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 3));
      bool visible() =>
          find.byType(MouseRegion).evaluate().any((e) => (e.widget as MouseRegion).cursor == SystemMouseCursors.none);

      // --- Starten (wie "Jetzt anzeigen" in den Einstellungen) ---
      screensaverPreview.value++;
      await pumpFor(tester, const Duration(seconds: 4));
      expect(visible(), isTrue);
      expect(find.text(formatClock(DateTime.now())), findsOneWidget, reason: 'Uhr wird angezeigt');
      expect(find.text(formatWeekdayDate(DateTime.now())), findsOneWidget);
      await saveShot(tester, 'screensaver');

      // --- Taste beendet ihn – Strg+F öffnet dabei NICHT die Suche ---
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(visible(), isFalse);

      // --- Mausbewegung beendet ihn; kleines Zittern nicht ---
      screensaverPreview.value++;
      await pumpFor(tester, const Duration(seconds: 2));
      expect(visible(), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 400));
      await mouse.moveBy(const Offset(5, 3));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(visible(), isTrue, reason: 'Kleines Wackeln beendet ihn nicht');
      await mouse.moveBy(const Offset(120, 60));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(visible(), isFalse);
      await mouse.removePointer();
      expect(find.byType(SearchScreen), findsNothing, reason: 'Die Aufweck-Taste hat nichts ausgelöst');
    } finally {
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
