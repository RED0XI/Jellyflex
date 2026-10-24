// Kaltstart mit gespeicherter Anmeldung, aber nicht erreichbarem Server: Die App darf nicht
// hängen bleiben, sondern zeigt die Startseite mit dem Hinweis "Server nicht erreichbar".
// Zwei Fälle: der Server antwortet gar nicht (Verbindung läuft ins Leere, z. B. Tailscale aus)
// und er lehnt sofort ab (Rechner an, Jellyfin aus).
//
// Start:  flutter test integration_test/cold_start_offline_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/secure_store.dart';
import 'package:jellyflex/core/server_status.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  for (final (name, server) in const [
    ('antwortet nicht', 'http://10.255.255.1:8096'),
    ('lehnt ab', 'http://127.0.0.1:9'),
  ]) {
    testWidgets('Kaltstart, Server $name', (tester) async {
      await windowManager.ensureInitialized();
      final dir = Directory.systemTemp.createTempSync('jellyflex_coldstart_');
      final settings = testSettings(dir);
      // Wie nach einer früheren Anmeldung.
      await SecureStore.instance.write(
        key: 'jellyflex.session',
        value: jsonEncode(
          const AuthSession(
            serverUrl: '',
            serverName: 'Weg',
            userId: 'u1',
            userName: 'Test',
            token: 'token',
            deviceId: 'cold-start-test',
          ).toJson()..['serverUrl'] = server,
        ),
      );

      final started = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(() => settings)],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final router = container.read(routerProvider);

      // Nach kurzer Zeit: Startseite statt Ladebildschirm, die Oberfläche reagiert.
      await pumpFor(tester, const Duration(seconds: 3));
      expect(router.state.uri.path, '/', reason: 'Nicht auf dem Ladebildschirm hängen');

      // Hinweis "Server nicht erreichbar" – spätestens nach der Wartezeit der Verbindung.
      Duration? offlineAfter;
      while (DateTime.now().difference(started) < const Duration(seconds: 40)) {
        await tester.pump(const Duration(milliseconds: 200));
        // Der Hinweis liegt immer im Baum (nur ausgeblendet) – also den Zustand prüfen.
        if (!container.read(serverOnlineProvider)) {
          offlineAfter = DateTime.now().difference(started);
          break;
        }
      }
      debugPrint('KALTSTART ($name): Hinweis nach ${offlineAfter?.inMilliseconds} ms');
      await pumpFor(tester, const Duration(seconds: 1)); // Hinweis gleitet herein
      await saveShot(tester, 'cold_start_${name.replaceAll(' ', '_')}');
      expect(offlineAfter, isNotNull, reason: 'Hinweis "Server nicht erreichbar" erscheint');

      // Downloads bleiben erreichbar.
      router.push('/downloads');
      await pumpFor(tester, const Duration(seconds: 1));
      expect(router.state.uri.path, '/downloads');

      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, const Duration(milliseconds: 300));
    });
  }
}
