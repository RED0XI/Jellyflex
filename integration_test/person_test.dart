// Prüft die Personenseite gegen den Demo-Server: Besetzung anklicken,
// Lebensdaten, Biografie, Filter Filme/Serien, Gastauftritte.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/person_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/details/details_screen.dart';
import 'package:jellyflex/features/person/person_screen.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Personenseite: aus der Besetzung öffnen, Infos, Filter', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    // Detailseite → in der Besetzung auf die erste Person klicken.
    container.read(routerProvider).push('/item/movie0');
    await pumpFor(tester, const Duration(seconds: 2));
    // Die Besetzung steht weiter unten – schrittweise hinscrollen.
    final cast = find.text('Lena Brandt');
    final details = tester.widget<CustomScrollView>(
      find.descendant(of: find.byType(DetailsScreen), matching: find.byType(CustomScrollView)),
    );
    for (var i = 0; i < 10 && cast.evaluate().isEmpty; i++) {
      details.controller!.jumpTo(details.controller!.offset + 250);
      await pumpFor(tester, const Duration(milliseconds: 300));
    }
    expect(cast, findsOneWidget);
    await tester.ensureVisible(cast);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(cast);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PersonScreen), findsOneWidget);

    // Lebensdaten und Biografie.
    expect(find.textContaining('Geboren am 10. Januar 1960'), findsOneWidget);
    expect(find.textContaining('in Hamburg, Deutschland'), findsOneWidget);
    await saveShot(tester, 'person');
    expect(find.text('Mehr anzeigen'), findsOneWidget, reason: 'Lange Biografie ist zuerst gekürzt');

    // Filmografie: Filme und Serien, mit Filter.
    final all = find.byType(PosterCard).evaluate().length;
    debugPrint('Titel gesamt (sichtbar): $all');
    expect(all, greaterThan(0));

    final seriesChip = find.textContaining(RegExp(r'^Serien \(\d+\)$'));
    expect(seriesChip, findsOneWidget);
    final seriesCount = int.parse(RegExp(r'\d+').firstMatch((seriesChip.evaluate().single.widget as Text).data!)![0]!);
    await tester.tap(seriesChip);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byType(PosterCard).evaluate().length, seriesCount);

    await tester.tap(find.text('Mehr anzeigen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Weniger anzeigen'), findsOneWidget);

    // Gastauftritte stehen weiter unten.
    final page = tester.widget<CustomScrollView>(
      find.descendant(of: find.byType(PersonScreen), matching: find.byType(CustomScrollView)),
    );
    page.controller!.jumpTo(page.controller!.position.maxScrollExtent);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Auftritte in einzelnen Folgen'), findsOneWidget);
    await saveShot(tester, 'person_bottom');
  });
}
