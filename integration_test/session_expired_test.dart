// Abgelaufene Anmeldung: Der Server nimmt den Zugang nicht mehr an (401). Jellyflex geht zur
// Anmeldung, fragt nicht weiter vergeblich und führt über das Profil direkt zur Passworteingabe.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/session_expired_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/secure_store.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/home_providers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<Map<String, dynamic>> _revoke([bool? on]) async {
  final query = on == null ? '' : '?on=${on ? 1 : 0}';
  final response = await (await HttpClient().getUrl(Uri.parse('$demoServer/debug/revoke$query'))).close();
  return jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Anmeldung abgelaufen: zurück zur Anmeldung, Profil fragt nach dem Passwort', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final settings = testSettings();
    const session = AuthSession(
      serverUrl: demoServer,
      serverName: 'Demo-Server',
      userId: 'user1',
      userName: 'Demo',
      token: 'mock-token',
      deviceId: 'expired-test',
    );
    await SecureStore.instance.write(key: 'jellyflex.session', value: jsonEncode(session.toJson()));
    await tester.runAsync(() => _revoke(false));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => settings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);
    expect(router.state.uri.path, '/');

    // Zugang widerrufen, dann lädt die Startseite neu.
    await tester.runAsync(() => _revoke(true));
    container.invalidate(homeProvider);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(router.state.uri.path, '/login', reason: 'Zur Anmeldung statt endlos weiterzufragen');
    expect(find.text('Neu anmelden'), findsOneWidget, reason: 'Profil zeigt, dass es neu angemeldet werden muss');
    await saveShot(tester, 'session_expired_profiles');

    // Danach fragt die App nicht weiter vergeblich nach.
    final before = (await tester.runAsync(_revoke))!['rejected'] as int;
    await pumpFor(tester, const Duration(seconds: 20));
    final after = (await tester.runAsync(_revoke))!['rejected'] as int;
    expect(after - before, lessThanOrEqualTo(1), reason: 'Keine weiteren vergeblichen Anfragen');

    // Profil anklicken → Passworteingabe mit Hinweis, Name schon ausgefüllt.
    await tester.tap(find.text('Demo'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.textContaining('Anmeldung ist abgelaufen'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Demo'), findsOneWidget);
    await saveShot(tester, 'session_expired_password');

    // Neu anmelden → wieder auf der Startseite.
    await tester.enterText(find.byType(TextField).last, 'geheim');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(router.state.uri.path, '/');

    await tester.runAsync(() => _revoke(false));
    await tester.pumpWidget(const SizedBox());
  });
}
