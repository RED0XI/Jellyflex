// Prüft den Jahresrückblick gegen den Demo-Server: über das Profilmenü öffnen,
// alle Karten durchblättern (Bildschirmfotos), Zahlen aus den Demo-Daten.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/wrapped_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/wrapped/wrapped_screen.dart';
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
    deviceId: 'wrapped-test',
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

  testWidgets('Jahresrückblick', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 3));

    // Profilmenü → Jahresrückblick.
    await tester.tap(find.byTooltip('Demo'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Jahresrückblick'));
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(WrappedScreen), findsOneWidget);
    expect(find.text('Dein Jahr 2026'), findsOneWidget);
    await _saveShot(tester, 'wrapped_0');

    // Durchblättern (Pfeil rechts), jede Karte fotografieren.
    final seen = <String>[];
    for (var i = 1; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _pumpFor(tester, const Duration(milliseconds: 2200));
      await _saveShot(tester, 'wrapped_$i');
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .where((t) => t.isNotEmpty)
          .take(3)
          .join(' | ');
      seen.add(texts);
      debugPrint('Karte $i: $texts');
      if (find.text('Als Bild speichern').evaluate().isNotEmpty) break;
    }

    // Zahlen aus den Demo-Daten: 5 Filme, 6 Folgen aus 2 Serien.
    expect(find.text('Als Bild speichern'), findsOneWidget, reason: 'Letzte Karte erreicht');
    expect(find.text('5'), findsWidgets);
    expect(find.text('6'), findsWidgets);
    expect(seen.any((t) => t.contains('Dein Lieblingsgenre')), isTrue);
    expect(seen.any((t) => t.contains('Deine Serie des Jahres')), isTrue);
    expect(seen.any((t) => t.contains('Dein größter Marathon')), isTrue);
  });
}
