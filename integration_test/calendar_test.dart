// "Demnächst": angekündigte Folgen nach Tagen, Leiste mit zwei Wochen, Klick führt zur Serie.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/calendar_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/details/details_screen.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Demnächst: Tage, Leiste, Sprung zur Serie', (tester) async {
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

    // Über das Symbol in der Leiste der Startseite.
    await tester.tap(find.byTooltip('Demnächst'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Demnächst'), findsWidgets);
    expect(find.text('Nächste Folge  ·  Heute'), findsOneWidget, reason: 'Großes Bild der nächsten Folge');
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.text('MORGEN'), findsOneWidget);
    expect(find.text('2 Folgen'), findsWidgets, reason: 'Morgen zwei Folgen');
    await saveShot(tester, 'calendar_midnight');

    // Andere Themen: gleiche Seite in deren Farben.
    final settings = container.read(settingsProvider.notifier);
    for (final theme in ['cinema', 'sunset']) {
      settings.update((s) => s.copyWith(themeId: theme));
      await pumpFor(tester, const Duration(milliseconds: 800));
      await saveShot(tester, 'calendar_$theme');
    }

    // Klick auf eine Folge öffnet die Serie.
    await tester.tap(find.textContaining('S2 E6').first);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(DetailsScreen), findsOneWidget);
    expect(container.read(routerProvider).state.uri.path, '/item/series1');
  });
}
