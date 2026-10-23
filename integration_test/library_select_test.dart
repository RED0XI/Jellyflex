// Mehrfachauswahl in einer Bibliothek: Auswahlmodus, Karten anwählen,
// alle als gesehen markieren, wieder ungesehen, Esc beendet.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/library_select_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/library/library_selection.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<bool> _played(String id) async {
  final request = await HttpClient().getUrl(Uri.parse('$demoServer/debug/userdata/$id'));
  final body = await utf8.decoder.bind(await request.close()).join();
  return (jsonDecode(body) as Map)['Played'] == true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Mehrfachauswahl in der Bibliothek', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings()),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).push('/library/lib-movies?name=Filme&type=movies');
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('Auswählen'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(SelectionBar), findsOneWidget);
    final overlays = find.byType(SelectableOverlay);
    expect(overlays, findsWidgets);

    // Zwei Filme anwählen (die ersten beiden Karten).
    final ids = [for (final e in overlays.evaluate().take(2)) (e.widget as SelectableOverlay).item.id];
    await tester.tap(overlays.at(0));
    await tester.tap(overlays.at(1));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('2 ausgewählt'), findsOneWidget);
    await saveShot(tester, 'library_select');

    await tester.tap(find.widgetWithText(TextButton, 'Gesehen'));
    await pumpFor(tester, const Duration(seconds: 2));
    for (final id in ids) {
      expect(await tester.runAsync(() => _played(id)), isTrue, reason: '$id gesehen');
    }
    expect(find.text('0 ausgewählt'), findsOneWidget, reason: 'Auswahl nach der Aktion geleert');

    // Wieder ungesehen.
    await tester.tap(overlays.at(0));
    await tester.tap(overlays.at(1));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Ungesehen'));
    await pumpFor(tester, const Duration(seconds: 2));
    for (final id in ids) {
      expect(await tester.runAsync(() => _played(id)), isFalse, reason: '$id ungesehen');
    }

    // Esc beendet den Auswahlmodus.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(SelectionBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
