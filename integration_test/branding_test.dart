// Prüft eigenen App-Namen und eigenes Logo: Anzeige in der App, Fenstertitel,
// Taskleisten-Symbol (.ico). Nutzt eine eigene Einstellungsdatei im Temp-Ordner.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/branding_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/branding.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/widgets/brand_logo.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'branding-test',
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

  testWidgets('Eigener Name und eigenes Logo', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_branding_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp)),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      expect(await tester.runAsync(windowManager.getTitle), defaultAppName);

      // Logo aus den Projektdateien importieren (wie über "Bild wählen …").
      final logo = await tester.runAsync(() => importLogo('${Directory.current.path}\\assets\\icon.png', dir: temp));
      final ico = File('${logo!.substring(0, logo.lastIndexOf('.'))}.ico');
      expect(ico.existsSync(), isTrue);
      final icoBytes = ico.readAsBytesSync();
      expect(icoBytes.sublist(0, 4), [0, 0, 1, 0], reason: 'Gültiger ICO-Kopf');
      expect(icoBytes.sublist(22, 26), [0x89, 0x50, 0x4E, 0x47], reason: 'PNG im Symbol');

      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(appName: () => 'Mein Kino', logoPath: () => logo));
      await _pumpFor(tester, const Duration(seconds: 2));

      expect(find.text('Mein Kino'), findsWidgets);
      expect(find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)), findsOneWidget);
      expect(await tester.runAsync(windowManager.getTitle), 'Mein Kino');
      await _saveShot(tester, 'branding_home');

      container.read(routerProvider).push('/settings');
      await _pumpFor(tester, const Duration(seconds: 1));
      final reset = find.text('Auf Jellyflex zurücksetzen');
      await tester.ensureVisible(reset);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Personalisieren'), findsOneWidget);
      await _saveShot(tester, 'branding_settings');

      // Zurücksetzen → wieder Jellyflex.
      await tester.tap(reset);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(container.read(settingsProvider).appName, isNull);
      expect(await tester.runAsync(windowManager.getTitle), defaultAppName);
    } finally {
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
