// Merkliste und eigene Listen (private Wiedergabelisten auf dem Server):
// Lesezeichen auf der Detailseite, "Meine Listen", neue Liste, entfernen, löschen.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/lists_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

Future<List<Map<String, dynamic>>> _serverLists() async {
  final request = await HttpClient().getUrl(Uri.parse('$demoServer/debug/playlists'));
  final body = await utf8.decoder.bind(await request.close()).join();
  return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Merkliste und eigene Listen', (tester) async {
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
    final router = container.read(routerProvider);

    // Lesezeichen auf der Detailseite → Merkliste (privat) mit dem Film.
    router.push('/item/movie2');
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Auf die Merkliste'));
    await pumpFor(tester, const Duration(seconds: 2));
    var lists = (await tester.runAsync(_serverLists))!;
    final watchlist = lists.singleWhere((l) => l['Name'] == 'Watchlist');
    expect(watchlist['Items'], ['movie2']);
    expect(watchlist['IsPublic'], isFalse, reason: 'Listen sind privat');
    expect(find.byTooltip('Von der Merkliste nehmen'), findsOneWidget);

    // Meine Listen: neue Liste anlegen.
    router.push('/lists');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.textContaining('Merkliste'), findsWidgets);
    await tester.tap(find.text('Neue Liste'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'Filmabend');
    await tester.tap(find.text('Erstellen'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.textContaining('Filmabend'), findsWidgets);
    expect(find.text('Diese Liste ist leer.'), findsOneWidget);
    await saveShot(tester, 'lists');

    // Aus der Merkliste entfernen.
    await tester.tap(find.bySemanticsLabel(RegExp('aus der Liste entfernen')).first);
    await pumpFor(tester, const Duration(seconds: 2));
    lists = (await tester.runAsync(_serverLists))!;
    expect(lists.singleWhere((l) => l['Name'] == 'Watchlist')['Items'], isEmpty);

    // Eigene Liste löschen.
    await tester.tap(find.byTooltip('Liste löschen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await pumpFor(tester, const Duration(seconds: 2));
    lists = (await tester.runAsync(_serverLists))!;
    expect(lists.where((l) => l['Name'] == 'Filmabend'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
