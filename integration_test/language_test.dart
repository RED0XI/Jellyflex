// Prüft die Sprache der Oberfläche: Englisch ist Standard, ein Wechsel auf
// Deutsch wirkt sofort (ohne Neustart) – auch für schon geladene Reihen.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/language_test.dart -d windows

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
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/widgets/media_row.dart';
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
    deviceId: 'language-test',
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

List<String?> _rowTitles() => find.byType(MediaRow).evaluate().map((e) => (e.widget as MediaRow).title).toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Sprache: Englisch als Standard, Wechsel wirkt sofort', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_language_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_DemoSession.new),
            // Leere Einstellungen = Standard.
            settingsProvider.overrideWith(() => SettingsController(File('${temp.path}\\settings.json'))),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

      // --- Englisch ---
      expect(appLanguage, AppLanguage.en);
      debugPrint('Reihen (en): ${_rowTitles()}');
      expect(_rowTitles(), contains('Continue watching'));
      expect(find.text('Home'), findsOneWidget);
      await _saveShot(tester, 'language_home_en');

      container.read(routerProvider).push('/settings');
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('App language'), findsOneWidget);
      await _saveShot(tester, 'language_settings_en');

      // --- Wechsel auf Deutsch, ohne Neustart ---
      container.read(settingsProvider.notifier).update((s) => s.copyWith(language: AppLanguage.de));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Sprache der App'), findsOneWidget);
      container.read(routerProvider).pop();
      await _pumpFor(tester, const Duration(seconds: 3));
      debugPrint('Reihen (de): ${_rowTitles()}');
      expect(_rowTitles(), contains('Weiterschauen'), reason: 'Schon geladene Reihen werden neu beschriftet');
      expect(find.text('Startseite'), findsOneWidget);
      await _saveShot(tester, 'language_home_de');

      // Gespeichert?
      expect(File('${temp.path}\\settings.json').readAsStringSync(), contains('"language": "de"'));
    } finally {
      appLanguage = AppLanguage.en;
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
