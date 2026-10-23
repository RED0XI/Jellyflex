// Suche: Personen (nach Schauspielern suchen), Filter, "Nur ungesehene",
// letzte Suchen (nur lokal gespeichert, löschbar).
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/search_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/person/person_screen.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:jellyflex/widgets/people_row.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Suche mit Personen, Filtern und Verlauf', (tester) async {
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
    final router = container.read(routerProvider);

    // Personensuche.
    router.push('/search');
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Lena');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(PeopleRow), findsOneWidget);
    expect(find.text('Lena Brandt'), findsOneWidget);
    await saveShot(tester, 'search_people');
    await tester.tap(find.text('Lena Brandt'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(PersonScreen), findsOneWidget);
    router.pop();
    await pumpFor(tester, const Duration(seconds: 1));

    // Titelsuche mit Filtern (Feld nach der Rückkehr erst wieder anklicken).
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'e');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpFor(tester, const Duration(seconds: 2));
    final all = find.byType(PosterCard).evaluate().length + find.byType(LandscapeCard).evaluate().length;
    expect(all, greaterThan(0));
    await tester.tap(find.text('Serien').last);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byType(LandscapeCard), findsNothing, reason: 'Nur Serien – keine Folgen');
    await tester.tap(find.text('Nur ungesehene'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await saveShot(tester, 'search_filters');

    // Verlauf: leeres Feld zeigt die letzten Suchen; löschbar.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Letzte Suchen'), findsOneWidget);
    expect(container.read(settingsProvider).recentSearches, containsAll(['Lena']));
    await saveShot(tester, 'search_recent');
    await tester.tap(find.text('Verlauf löschen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(container.read(settingsProvider).recentSearches, isEmpty);
    expect(find.text('Letzte Suchen'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
