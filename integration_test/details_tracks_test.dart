// Ton und Untertitel schon auf der Detailseite wählen: Knöpfe zeigen, was laufen
// wird; der Player startet mit der Wahl; bei Folgen merkt sich die Serie die Sprache.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/details_tracks_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/series_tracks.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:jellyflex/widgets/buttons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Detailseite: Ton und Untertitel wählen', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);

    Future<Player> waitForPlayer() async {
      for (var i = 0; i < 100; i++) {
        await pumpFor(tester, const Duration(milliseconds: 100));
        final p = player;
        if (p != null && p.state.tracks.audio.length >= 4 && p.state.duration > Duration.zero) break;
      }
      await pumpFor(tester, const Duration(seconds: 1));
      return player!;
    }

    // Von vorne: die Fortsetzen-Stellen des Demo-Servers liegen hinter dem Ende des Testvideos.
    Future<void> play() async {
      final fromStart = find.text('Von vorne');
      await tester.tap(fromStart.evaluate().isNotEmpty ? fromStart : find.byType(PrimaryButton).first);
    }

    Future<void> closePlayer() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester, const Duration(seconds: 3));
      expect(find.byType(PlayerScreen), findsNothing);
    }

    // --- Film: Knöpfe zeigen den Standard, Wahl geht an den Player.
    router.push('/item/movie0');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Ton: Deutsch'), findsOneWidget);
    expect(find.text('Untertitel: Aus'), findsOneWidget);

    await tester.tap(find.text('Ton: Deutsch'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await saveShot(tester, 'details_tracks_audio_menu');
    await tester.tap(find.text('Englisch - TrueHD Atmos - 7.1'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Ton: Englisch'), findsOneWidget);

    await tester.tap(find.text('Untertitel: Aus'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Deutsch - SRT - Extern'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Untertitel: Deutsch'), findsOneWidget);
    await saveShot(tester, 'details_tracks_chosen');

    // Fassung wechseln: gleiche Sprachen bleiben gewählt.
    await tester.tap(find.text('Fassung: 4K Dolby Vision'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('1080p · H.264'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Ton: Englisch'), findsOneWidget);
    expect(find.text('Untertitel: Deutsch'), findsOneWidget);

    await play();
    var p = await waitForPlayer();
    debugPrint('Film: audio=${p.state.track.audio.id} sub=${p.state.track.subtitle.id}');
    expect(p.state.track.audio.id, '2', reason: 'Englische Tonspur');
    expect(p.state.track.subtitle.id, isNot('no'), reason: 'Externe deutsche Untertitel');
    expect(p.state.track.subtitle.language, 'ger');
    await closePlayer();
    expect(SeriesTracks.instance.get('$demoServer|user1', 'movie0'), (
      audio: null,
      subtitle: null,
    ), reason: 'Filme merken sich nichts');

    // --- Folge: Wahl gilt danach für die ganze Serie.
    player = null;
    router.push('/item/series0_s1_e1');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Ton: Deutsch'), findsOneWidget);
    await tester.tap(find.text('Ton: Deutsch'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Englisch - TrueHD - 7.1'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await play();
    p = await waitForPlayer();
    expect(p.state.track.audio.id, '2');
    await closePlayer();
    expect(SeriesTracks.instance.get('$demoServer|user1', 'series0').audio, 'eng');

    // Nächste Folge zeigt schon die gemerkte Sprache.
    router.push('/item/series0_s1_e2');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Ton: Englisch'), findsOneWidget);
    expect(find.textContaining('Untertitel:'), findsNothing, reason: 'Demo-Folgen haben keine Untertitel');
    expect(
      SeriesTracks.instance.get('$demoServer|user1', 'series0').subtitle,
      isNull,
      reason: 'Untertitel nicht angefasst → nicht gemerkt',
    );
  });
}
