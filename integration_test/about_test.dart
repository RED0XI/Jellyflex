// Einstellungen → Über Jellyflex: Version, Update-Prüfung (aus), Fehlerbericht.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/about_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/features/settings/about_section.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Über Jellyflex und Fehlerbericht', (tester) async {
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
    expect(container.read(settingsProvider).updateCheck, isFalse, reason: 'Update-Prüfung ist standardmäßig aus');

    container.read(routerProvider).push('/settings');
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.byType(AboutRows));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text(appVersion), findsOneWidget);
    await saveShot(tester, 'settings_about');

    await tester.tap(find.text('Erstellen'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.textContaining('App version: $appVersion'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('Demo-Server')),
      findsNothing,
      reason: 'Servername ist entfernt',
    );
    await saveShot(tester, 'error_report');
    await tester.tap(find.text('Schließen'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // "?" zeigt die Tastenkürzel.
    // Wie auf einer echten Tastatur: Umschalt + Taste, die "?" ergibt.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, physicalKey: PhysicalKeyboardKey.slash, character: '?');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash, physicalKey: PhysicalKeyboardKey.slash);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Tastenkürzel'), findsWidgets);
    await saveShot(tester, 'shortcut_sheet');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Tastenkürzel'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
