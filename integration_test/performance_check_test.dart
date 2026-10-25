// Leistungstest aus Einstellungen → Über: läuft komplett durch (Server, Bibliotheken,
// Suche, Bilder, Netz, Scrollen, Wiedergabe), speichert einen JSON-Bericht und der
// Bericht enthält keine persönlichen Angaben.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/performance_check_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/performance_check.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/settings/about_section.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Leistungstest speichert einen bereinigten Bericht', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_perfcheck_');
    addTearDown(() {
      PerformanceCheck.saveFolder = null;
      temp.deleteSync(recursive: true);
    });
    PerformanceCheck.saveFolder = temp;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => testSettings())],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).push('/settings?section=about');
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.byType(AboutRows));
    await pumpFor(tester, const Duration(milliseconds: 600));

    await tester.tap(find.text('Test starten'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.textContaining('Downloads-Ordner'), findsOneWidget);
    await saveShot(tester, 'perf_check_intro');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Test starten')));

    // Läuft gut eine Minute; zwischendurch Bibliothek und Player.
    var sawLibrary = false;
    var sawPlayer = false;
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(minutes: 4) &&
        find.text('Fertig – der Bericht ist gespeichert.').evaluate().isEmpty) {
      await pumpFor(tester, const Duration(milliseconds: 500));
      final path = container.read(routerProvider).state.uri.path;
      sawLibrary |= path.startsWith('/library/');
      sawPlayer |= path.startsWith('/play/');
    }
    await pumpFor(tester, const Duration(milliseconds: 600));
    await saveShot(tester, 'perf_check_done');
    expect(find.text('Fertig – der Bericht ist gespeichert.'), findsOneWidget);
    expect(sawLibrary, isTrue, reason: 'Bibliothek zum Scrollen geöffnet');
    expect(sawPlayer, isTrue, reason: 'Player geöffnet');
    expect(container.read(routerProvider).state.uri.path, '/settings', reason: 'zurück auf der Einstellungsseite');

    final files = temp.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    final text = files.single.readAsStringSync();
    debugPrint(text);
    final report = jsonDecode(text) as Map<String, dynamic>;
    for (final key in ['server', 'home', 'libraries', 'search', 'images', 'throughput', 'scrolling', 'playback']) {
      expect(report[key], isA<Map>(), reason: key);
      expect((report[key] as Map).containsKey('error'), isFalse, reason: '$key: ${report[key]}');
    }
    expect(report['server']['pingMs']['n'], 10);
    expect(report['libraries']['counts']['MovieCount'], greaterThan(0));
    expect(report['scrolling']['frames'], greaterThan(30));
    expect(report['playback']['playedS'], greaterThan(15));
    expect(report['throughput']['mb'], greaterThan(0));

    // Keine persönlichen Angaben: Server, Namen, IDs, Titel, Bibliotheksnamen.
    for (final secret in ['localhost', '8097', 'Demo', 'user1', 'mock-token', 'Filme', 'Serien', 'lib-movies']) {
      expect(text.contains(secret), isFalse, reason: 'Bericht enthält "$secret"');
    }
    expect(RegExp(r'movie\d|series\d|episode\d').hasMatch(text), isFalse, reason: 'keine Eintrags-IDs');

    await tester.tap(find.text('Schließen'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });
}
