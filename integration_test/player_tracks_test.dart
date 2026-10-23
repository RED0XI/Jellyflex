// Prüft im echten Fenster (mpv) die wichtigsten Player-Funktionen.
//
// Voraussetzung: Testvideo unter %TEMP%\jellyflex_test.mkv mit zwei Tonspuren
// (de, en) und zwei Untertiteln (de, en) – siehe lib/dev/player_harness.dart.
//
// Start:  flutter test integration_test/player_tracks_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/dev/player_harness.dart';
import 'package:jellyflex/features/player/player_overlays.dart';
import 'package:jellyflex/widgets/window_frame.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';

/// Speichert ein Panel als PNG unter build/screenshots/ (zum Anschauen).
Future<void> _savePanelShot(WidgetTester tester, Finder panel, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: panel, matching: find.byType(RepaintBoundary)).first,
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('build/screenshots/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
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
    await pumpFor(tester, const Duration(seconds: 1));
    debugPrint('Start: audio=${p.state.track.audio.id} sub=${p.state.track.subtitle.id}');

    // Maus bewegen → Bedienelemente einblenden.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(420, 320));
    await pumpFor(tester, const Duration(milliseconds: 400));

    // --- Spurwahl über das Panel ---
    await tester.tap(find.byIcon(Icons.subtitles_rounded));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Untertitel'), findsOneWidget);

    await tester.tap(find.text('Englisch - AAC - Stereo'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.audio.id, '2');

    await tester.tap(find.text('Englisch - SRT'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.subtitle.id, '2');

    // Panel bleibt nach 4 s offen (Bedienleiste blendet sich nicht aus).
    await pumpFor(tester, const Duration(seconds: 4));
    expect(find.text('Englisch - SRT'), findsOneWidget);

    await tester.tap(find.text('Aus'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.track.subtitle.id, 'no');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // Panel schließen
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Englisch - SRT'), findsNothing);

    // --- Intro überspringen (Test-Intro: 3 s bis 25 s) ---
    await p.seek(const Duration(seconds: 5));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Intro überspringen'), findsOneWidget);
    await tester.tap(find.text('Intro überspringen'));
    await pumpFor(tester, const Duration(seconds: 2));
    debugPrint('Nach Intro-Skip: ${p.state.position}');
    expect(p.state.position.inSeconds, greaterThanOrEqualTo(24));
    expect(find.text('Intro überspringen'), findsNothing);

    // --- F11 Vollbild an/aus ---
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(windowFullscreen.value, isTrue);
    expect(await windowManager.isFullScreen(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(windowFullscreen.value, isFalse);
  });

  testWidgets('Player: bevorzugte Sprachen und automatisches Überspringen', (tester) async {
    await windowManager.ensureInitialized();
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);

    await tester.pumpWidget(
      buildHarnessApp(
        settings: const AppSettings(audioLanguage: 'eng', subtitleLanguage: 'eng', autoSkipIntro: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Test-Player öffnen'));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = player;
      if (p != null && p.state.tracks.audio.length >= 4 && p.state.duration > Duration.zero) break;
    }
    final p = player!;
    await pumpFor(tester, const Duration(seconds: 2));
    debugPrint('Mit Einstellungen: audio=${p.state.track.audio.id} sub=${p.state.track.subtitle.id}');
    expect(p.state.track.audio.id, '2', reason: 'Englische Tonspur bevorzugt');
    expect(p.state.track.subtitle.id, '2', reason: 'Englische Untertitel bevorzugt');

    // Im Intro (3 s – 25 s) wird automatisch ans Ende gesprungen.
    await p.seek(const Duration(seconds: 5));
    await pumpFor(tester, const Duration(seconds: 3));
    debugPrint('Nach Auto-Skip: ${p.state.position}');
    expect(p.state.position.inSeconds, greaterThanOrEqualTo(24));
  });

  testWidgets('Player: Geschwindigkeit, Versatz, Kapitel, Qualität', (tester) async {
    await windowManager.ensureInitialized();
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);
    harnessTranscodeRequests.clear();
    await tester.pumpWidget(buildHarnessApp());
    await tester.pump();
    await tester.tap(find.text('Test-Player öffnen'));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = player;
      if (p != null && p.state.tracks.audio.length >= 4 && p.state.duration > Duration.zero) break;
    }
    final p = player!;
    await pumpFor(tester, const Duration(seconds: 1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(420, 320));
    await pumpFor(tester, const Duration(milliseconds: 400));

    // --- Kapitel in der Vorschau beim Überfahren der Spulleiste (Mitte = 60 s) ---
    await mouse.moveTo(tester.getCenter(find.byType(Slider).first));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('Die Mitte'), findsOneWidget);
    await mouse.moveTo(const Offset(420, 320));
    await pumpFor(tester, const Duration(milliseconds: 300));

    // --- Geschwindigkeit ---
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('1,5×'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(p.state.rate, 1.5);

    // --- Untertitelversatz +0,1 s ---
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await pumpFor(tester, const Duration(milliseconds: 500));
    final subDelay = await (p.platform as NativePlayer).getProperty('sub-delay');
    debugPrint('sub-delay=$subDelay');
    expect(double.parse(subDelay), closeTo(0.1, 0.001));
    expect(find.text('+0,1 s'), findsOneWidget);
    await _savePanelShot(tester, find.byType(PlaybackPanel), 'playback_panel');

    // --- Qualität: Umrechnung an derselben Stelle ---
    await p.seek(const Duration(seconds: 40));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('6 Mbit/s · 720p'));
    await pumpFor(tester, const Duration(seconds: 3));
    debugPrint('Umrechnung angefragt: $harnessTranscodeRequests, Position: ${p.state.position}');
    expect(harnessTranscodeRequests, [6000000]);
    expect(p.state.position.inSeconds, greaterThanOrEqualTo(38));
    expect(find.text('6 Mbit/s'), findsOneWidget); // Hinweis in der Leiste

    // Spurwechsel bei Umrechnung startet den Stream neu.
    await tester.tap(find.byIcon(Icons.subtitles_rounded));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Englisch - AAC - Stereo'));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(harnessTranscodeRequests.length, 2);
  });
}
