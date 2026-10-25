// Einstellungen: Bereiche wechseln, Adresse mit ?section=, Suche über alle Bereiche.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/settings_sections_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/widgets/theme_picker.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Einstellungen: Bereiche und Suche', (tester) async {
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
    final router = container.read(routerProvider);

    // Direkt in einen Bereich.
    router.push('/settings?section=downloads');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Smart Downloads'), findsOneWidget);
    expect(find.text('Sprache der App'), findsNothing, reason: 'Nur ein Bereich auf einmal');

    // Bereich wechseln über die Liste links.
    await tester.tap(find.text('Aussehen'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.text('Smart Downloads'), findsNothing);

    // Suche findet Einträge aus allen Bereichen, mit Bereichsnamen.
    await tester.enterText(find.byType(TextField).first, 'untertitel');
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('Bevorzugte Untertitel'), findsOneWidget);
    expect(find.text('Wiedergabe · Untertitel-Darstellung'), findsOneWidget);
    await saveShot(tester, 'settings_search');

    await tester.enterText(find.byType(TextField).first, 'xyz-gibt-es-nicht');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Keine Einstellung passt zu „xyz-gibt-es-nicht“.'), findsOneWidget);

    // Bereich anklicken beendet die Suche.
    await tester.tap(find.text('Über Jellyflex'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('App-Version'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
