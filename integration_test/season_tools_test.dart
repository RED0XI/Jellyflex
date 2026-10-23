// Staffel-Werkzeuge auf der Serienseite: Fortschritt "x von y gesehen",
// ganze Staffel als gesehen/ungesehen markieren (mit Rückfrage), Staffel
// herunterladen mit Fortschritt.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/season_tools_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<void> _post(String path, {String method = 'POST'}) async {
  final request = await HttpClient().openUrl(method, Uri.parse('$demoServer$path'));
  await (await request.close()).drain<void>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Staffel-Werkzeuge', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final root = Directory.systemTemp.createTempSync('jellyflex_season_tools_');
    // Langsam ausliefern, damit der Download-Fortschritt sichtbar bleibt.
    await tester.runAsync(() => _post('/debug/throttle?bps=200000'));
    // Ausgangszustand der Demo-Daten merken (andere Tests zählen darauf) …
    final ids = [
      for (final s in [1, 2]) ...['series1_s$s', for (var e = 1; e <= 8; e++) 'series1_s${s}_e$e'],
    ];
    final before = (await tester.runAsync(() => saveUserData(ids)))!;
    // … dann: beide Staffeln ungesehen (falls ein früherer Lauf abbrach).
    for (final s in ['series1_s1', 'series1_s2']) {
      await tester.runAsync(() => _post('/UserPlayedItems/$s', method: 'DELETE'));
    }
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings()),
            downloadsProvider.overrideWith(() => DownloadManager(root)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 2));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      container.read(routerProvider).push('/item/series1');
      await pumpFor(tester, const Duration(seconds: 3));

      final markButton = find.text('Staffel als gesehen markieren');
      await tester.ensureVisible(markButton);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.textContaining(RegExp(r'^\d+ von 8 gesehen$')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Ganze Staffel als gesehen – mit Rückfrage.
      await tester.tap(markButton);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('als gesehen markieren?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Staffel als gesehen markieren'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('8 von 8 gesehen'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget, reason: 'Haken an der Staffel');
      expect(find.text('Staffel als ungesehen markieren'), findsOneWidget);

      // Staffel herunterladen: Fortschritt erscheint.
      await tester.tap(find.text('Staffel herunterladen'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.textContaining(RegExp(r'^\d von 8 heruntergeladen$')), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Für das Foto etwas zurückscrollen (Werkzeugleiste unter der Leiste hervor).
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 220));
      await pumpFor(tester, const Duration(milliseconds: 600));
      await saveShot(tester, 'season_tools');

      // Wieder ungesehen.
      await tester.tap(find.text('Staffel als ungesehen markieren'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('0 von 8 gesehen'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => _post('/debug/throttle?bps=0'));
      // Demo-Daten genau wiederherstellen.
      await tester.runAsync(() => restoreUserData(before));
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
