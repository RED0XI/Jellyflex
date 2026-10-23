// Neuer Titel auf dem Server ("LibraryChanged") erscheint ohne Neuladen
// in der geöffneten Bibliothek.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/auto_refresh_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<String> _addMovie(String name) async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('$demoServer/debug/addmovie?name=${Uri.encodeQueryComponent(name)}'));
  final body = await utf8.decoder.bind(await req.close()).join();
  client.close();
  return (jsonDecode(body) as Map)['id'] as String;
}

Future<void> _removeMovie(String id) async {
  final client = HttpClient();
  await (await client.deleteUrl(Uri.parse('$demoServer/debug/addmovie?id=$id'))).close();
  client.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Neuer Film erscheint von selbst in der Bibliothek', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => testSettings())],
        child: const JellyflexApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).push('/library/lib-movies?name=Filme&type=movies');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Aaa Neuzugang'), findsNothing);

    final id = (await tester.runAsync(() => _addMovie('Aaa Neuzugang')))!;
    try {
      // Meldungen werden 1,5 s gebündelt, dann lädt die Liste still nach.
      await pumpFor(tester, const Duration(seconds: 4));
      expect(find.text('Aaa Neuzugang'), findsWidgets, reason: 'Neuer Film nach LibraryChanged sichtbar');
    } finally {
      await tester.runAsync(() => _removeMovie(id));
    }
  });
}
