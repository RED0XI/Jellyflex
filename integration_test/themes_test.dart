// Prüft die Themes gegen den Demo-Server: jedes Theme wird live gesetzt, die
// App übernimmt Hintergrund und Akzent sofort; Bildschirmfotos je Theme
// (Startseite und Detailseite) plus die Theme-Auswahl in den Einstellungen.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/themes_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'themes-test',
  );
}

final _shotKey = GlobalKey();

Future<void> _saveShot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Themes', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
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
            sessionProvider.overrideWith(_DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp, AppLanguage.en)),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final settings = container.read(settingsProvider.notifier);
      final router = container.read(routerProvider);

      // Einstellungen: Theme-Auswahl sichtbar.
      router.push('/settings');
      await _pumpFor(tester, const Duration(seconds: 1));
      await tester.ensureVisible(find.byType(ThemePicker));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('Synthwave'), findsOneWidget);
      // Ein Theme per Klick wählen.
      await tester.tap(find.text('Cinema Red'));
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(container.read(settingsProvider).themeId, 'cinema');
      expect(AppColors.accent, paletteById('cinema').accent);
      await _saveShot(tester, 'theme_picker');
      router.pop();
      await _pumpFor(tester, const Duration(seconds: 1));

      for (final p in appPalettes) {
        settings.update((s) => s.copyWith(themeId: p.id));
        await _pumpFor(tester, const Duration(milliseconds: 1500));
        final scaffold = Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
        expect(scaffold, p.background, reason: 'Hintergrund von ${p.id}');
        await _saveShot(tester, 'theme_${p.id}_home');

        router.push('/item/movie0');
        await _pumpFor(tester, const Duration(seconds: 2));
        await _saveShot(tester, 'theme_${p.id}_details');
        router.pop();
        await _pumpFor(tester, const Duration(seconds: 1));
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
