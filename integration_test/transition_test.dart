// Übergang Karte → Detailseite: Die Seite wächst aus der angeklickten Karte
// heraus (Foto mitten im Übergang) und schrumpft beim Zurück wieder hinein.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/transition_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/details/details_screen.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Detailseite wächst aus der Karte', (tester) async {
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
    await pumpFor(tester, const Duration(seconds: 3));
    final home = tester.widget<CustomScrollView>(find.byType(CustomScrollView).first);
    home.controller!.jumpTo(700);
    await pumpFor(tester, const Duration(seconds: 1));

    final card = find.byType(PosterCard).first;
    await tester.tap(card);
    // Einige Bilder des Übergangs festhalten (das mittlere zeigt die wachsende Seite).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await saveShot(tester, 'transition_$i');
    }
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(DetailsScreen), findsOneWidget);

    // Zurück: schrumpft in die Karte.
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await saveShot(tester, 'transition_back');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(DetailsScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
