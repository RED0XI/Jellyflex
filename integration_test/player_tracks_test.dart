// Prüft im echten Fenster (mpv) die wichtigsten Player-Funktionen.
//
// Voraussetzung: Testvideo unter %TEMP%\jellyflex_test.mkv mit zwei Tonspuren
// (de, en) und zwei Untertiteln (de, en) – siehe lib/dev/player_harness.dart.
//
// Start:  flutter test integration_test/player_tracks_test.dart -d windows

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/dev/player_harness.dart';
import 'package:jellyflex/widgets/window_frame.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Player: Spurwahl, Intro überspringen, F11', (tester) async {
    await windowManager.ensureInitialized();
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);

    await tester.pumpWidget(buildHarnessApp());
    await tester.pump();
    await tester.tap(find.text('Test-Player öffnen'));

    // Warten, bis mpv die Datei geöffnet hat.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = player;
      if (p != null && p.state.tracks.audio.length >= 4 && p.state.duration > Duration.zero) break;
    }
    final p = player!;
    await _pumpFor(tester, const Duration(seconds: 1));
    debugPrint('Start: audio=${p.state.track.audio.id} sub=${p.state.track.subtitle.id}');

    // Maus bewegen → Bedienelemente einblenden.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(420, 320));
    await _pumpFor(tester, const Duration(milliseconds: 400));

    // --- Spurwahl über das Panel ---
    await tester.tap(find.byIcon(Icons.subtitles_rounded));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Untertitel'), findsOneWidget);

    await tester.tap(find.text('Englisch - AAC - Stereo'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.audio.id, '2');

    await tester.tap(find.text('Englisch - SRT'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.subtitle.id, '2');

    // Panel bleibt nach 4 s offen (Bedienleiste blendet sich nicht aus).
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(find.text('Englisch - SRT'), findsOneWidget);

    await tester.tap(find.text('Aus'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.subtitle.id, 'no');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // Panel schließen
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Englisch - SRT'), findsNothing);

    // --- Intro überspringen (Test-Intro: 3 s bis 25 s) ---
    await p.seek(const Duration(seconds: 5));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Intro überspringen'), findsOneWidget);
    await tester.tap(find.text('Intro überspringen'));
    await _pumpFor(tester, const Duration(seconds: 2));
    debugPrint('Nach Intro-Skip: ${p.state.position}');
    expect(p.state.position.inSeconds, greaterThanOrEqualTo(24));
    expect(find.text('Intro überspringen'), findsNothing);

    // --- F11 Vollbild an/aus ---
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(windowFullscreen.value, isTrue);
    expect(await windowManager.isFullScreen(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(windowFullscreen.value, isFalse);
  });
}
