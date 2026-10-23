// Prüft den Bildschirmschoner gegen den Demo-Server: Vorschau starten, Bilder
// und Uhr, Beenden per Taste (ohne dass die Taste darunter etwas auslöst) und
// per Mausbewegung.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/screensaver_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'screensaver-test',
  );
}

final _shotKey = GlobalKey();

Future<void> _saveShot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Bildschirmschoner: anzeigen und beenden', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
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
            sessionProvider.overrideWith(_DemoSession.new),
            settingsProvider.overrideWith(() => SettingsController(File('${temp.path}\\settings.json'))),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      bool visible() => find.byType(MouseRegion).evaluate().any(
        (e) => (e.widget as MouseRegion).cursor == SystemMouseCursors.none,
      );

      // --- Starten (wie "Jetzt anzeigen" in den Einstellungen) ---
      screensaverPreview.value++;
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(visible(), isTrue);
      expect(find.text(formatClock(DateTime.now())), findsOneWidget, reason: 'Uhr wird angezeigt');
      expect(find.text(formatWeekdayDate(DateTime.now())), findsOneWidget);
      await _saveShot(tester, 'screensaver');

      // --- Taste beendet ihn – Strg+F öffnet dabei NICHT die Suche ---
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(visible(), isFalse);

      // --- Mausbewegung beendet ihn; kleines Zittern nicht ---
      screensaverPreview.value++;
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(visible(), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 400));
      await mouse.moveBy(const Offset(5, 3));
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(visible(), isTrue, reason: 'Kleines Wackeln beendet ihn nicht');
      await mouse.moveBy(const Offset(120, 60));
      await _pumpFor(tester, const Duration(milliseconds: 600));
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
