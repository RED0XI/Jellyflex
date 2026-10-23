// Server weg → Hinweis "Server nicht erreichbar" (mit Weg zu den Downloads),
// Server wieder da → "Erneut versuchen" blendet ihn aus.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/offline_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/server_status.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<void> _offline(bool on) async {
  final request = await HttpClient().postUrl(Uri.parse('$demoServer/debug/offline?on=${on ? 1 : 0}'));
  await (await request.close()).drain<void>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Hinweis, wenn der Server nicht erreichbar ist', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
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
      await pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      expect(container.read(serverOnlineProvider), isTrue);

      await tester.runAsync(() => _offline(true));
      // Live-Verbindung bricht ab → 3 s warten → Server fragen.
      for (var i = 0; i < 80 && container.read(serverOnlineProvider); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(container.read(serverOnlineProvider), isFalse);
      expect(find.text('Server nicht erreichbar'), findsOneWidget);
      await saveShot(tester, 'offline_banner');

      // Downloads lassen sich öffnen.
      await tester.tap(find.widgetWithText(TextButton, 'Downloads'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(container.read(routerProvider).state.uri.path, '/downloads');

      await tester.runAsync(() => _offline(false));
      await tester.tap(find.widgetWithText(TextButton, 'Erneut versuchen'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(container.read(serverOnlineProvider), isTrue);
      expect(find.text('Wieder mit dem Server verbunden'), findsOneWidget);
    } finally {
      await tester.runAsync(() => _offline(false));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
