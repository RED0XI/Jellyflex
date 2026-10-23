// Prüft die Themes gegen den Demo-Server: jedes Theme wird live gesetzt, die
// App übernimmt Hintergrund und Akzent sofort; Bildschirmfotos je Theme
// (Startseite und Detailseite) plus die Theme-Auswahl in den Einstellungen.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/themes_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/themes.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/theme.dart';
import 'package:jellyflex/widgets/theme_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Themes', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_themes_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp, AppLanguage.en)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final settings = container.read(settingsProvider.notifier);
      final router = container.read(routerProvider);

      // Einstellungen: Theme-Auswahl sichtbar.
      router.push('/settings');
      await pumpFor(tester, const Duration(seconds: 1));
      await tester.ensureVisible(find.byType(ThemePicker));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('Synthwave'), findsOneWidget);
      // Ein Theme per Klick wählen.
      await tester.tap(find.text('Cinema Red'));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(container.read(settingsProvider).themeId, 'cinema');
      expect(AppColors.accent, paletteById('cinema').accent);
      await saveShot(tester, 'theme_picker');
      router.pop();
      await pumpFor(tester, const Duration(seconds: 1));

      for (final p in appPalettes) {
        settings.update((s) => s.copyWith(themeId: p.id));
        await pumpFor(tester, const Duration(milliseconds: 1500));
        final scaffold = Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
        expect(scaffold, p.background, reason: 'Hintergrund von ${p.id}');
        await saveShot(tester, 'theme_${p.id}_home');

        router.push('/item/movie0');
        await pumpFor(tester, const Duration(seconds: 2));
        await saveShot(tester, 'theme_${p.id}_details');
        router.pop();
        await pumpFor(tester, const Duration(seconds: 1));
      }

      // Gespeichert?
      expect(File('${temp.path}\\settings.json').readAsStringSync(), contains('"themeId": "noir"'));
    } finally {
      appPalette = appPalettes.first;
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
