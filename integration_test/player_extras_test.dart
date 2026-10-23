// Player-Extras im echten Fenster (mpv): Kapitel-Leiste (C), Wiedergabe-Infos (I),
// Bildschirmfoto (S).
//
// Voraussetzung: Testvideo unter %TEMP%\jellyflex_test.mkv – siehe lib/dev/player_harness.dart.
// Start:  flutter test integration_test/player_extras_test.dart -d windows

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/dev/player_harness.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Player: Kapitel, Infos, Bildschirmfoto', (tester) async {
    await windowManager.ensureInitialized();
    final shots = Directory.systemTemp.createTempSync('jellyflex_shots_');
    debugScreenshotFolder = shots;
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);
    try {
      await tester.pumpWidget(RepaintBoundary(key: shotKey, child: buildHarnessApp()));
      await tester.pump();
      await tester.tap(find.text('Test-Player öffnen'));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final p = player;
        if (p != null && p.state.duration > Duration.zero) break;
      }
      final p = player!;
      await pumpFor(tester, const Duration(seconds: 1));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 300));
      await mouse.moveTo(const Offset(420, 320));
      await pumpFor(tester, const Duration(milliseconds: 400));

      // --- Kapitel: Taste C öffnet die Leiste, Klick springt hin ---
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Kapitel'), findsOneWidget);
      expect(find.text('Die Mitte'), findsOneWidget);
      await saveShot(tester, 'player_chapters');
      await tester.tap(find.text('Das Ende'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(p.state.position.inSeconds, greaterThanOrEqualTo(79), reason: 'Sprung zum Kapitel "Das Ende" (80 s)');
      expect(find.text('Die Mitte'), findsNothing, reason: 'Leiste schließt nach der Wahl');

      // --- Wiedergabe-Infos: Taste I ---
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await pumpFor(tester, const Duration(milliseconds: 1500));
      expect(find.text('Wiedergabe-Infos (I)'), findsOneWidget);
      expect(find.textContaining('Direkt (Originaldatei)'), findsOneWidget);
      await saveShot(tester, 'player_stats');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('Wiedergabe-Infos (I)'), findsNothing);

      // --- Bildschirmfoto: Taste S ---
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      File? shot;
      for (var i = 0; i < 40 && shot == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        shot = shots.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).firstOrNull;
      }
      expect(shot, isNotNull, reason: 'Bildschirmfoto gespeichert');
      final bytes = shot!.readAsBytesSync();
      expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: 'gültige PNG-Datei');
      expect(shot.path, contains('Testfolge'));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester, const Duration(seconds: 1));
    } finally {
      debugScreenshotFolder = null;
      await tester.pumpWidget(const SizedBox());
      try {
        shots.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
