// Untertitel über den Server suchen: Menü auf der Detailseite, Trefferliste, Laden,
// danach ist der neue Untertitel gewählt.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/subtitle_search_test.dart -d windows

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Untertitel über den Server suchen und laden', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    // Eine Folge ohne Untertitel: der Knopf ist trotzdem da (zum Suchen).
    container.read(routerProvider).push('/item/series2_s1_e3');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Untertitel: Aus'), findsOneWidget);
    await tester.tap(find.text('Untertitel: Aus'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Untertitel suchen …'));
    await pumpFor(tester, const Duration(seconds: 2));

    // Trefferliste: genau passender zuerst, mit Marke.
    expect(find.text('Untertitel suchen'), findsOneWidget);
    expect(find.text('Passt genau'), findsOneWidget);
    expect(find.text('Für Hörgeschädigte'), findsOneWidget);
    await saveShot(tester, 'subtitle_search');
    await tester.tap(find.text('Laden').first);
    // Der Demo-Server bindet die Datei (wie Jellyfin) erst nach ein paar Sekunden ein.
    await pumpFor(tester, const Duration(seconds: 10));

    // Geladen und gleich ausgewählt.
    expect(find.text('Untertitel suchen'), findsNothing, reason: 'Fenster geschlossen');
    expect(find.text('Untertitel: Deutsch'), findsOneWidget);
    await saveShot(tester, 'subtitle_search_done');
  });

  testWidgets('Untertitel im Player suchen und gleich einschalten', (tester) async {
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
    container.read(routerProvider).push('/play/series3_s1_e5?start=1');
    for (var i = 0; i < 100; i++) {
      await pumpFor(tester, const Duration(milliseconds: 100));
      final p = player;
      if (p != null && p.state.tracks.audio.length >= 4 && p.state.duration > Duration.zero) break;
    }
    final p = player!;

    // Spur-Panel öffnen, "Untertitel suchen …" wählen.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(420, 320));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.subtitles_rounded));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Untertitel suchen …'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Untertitel suchen'), findsOneWidget);
    expect(p.state.playing, isFalse, reason: 'Video pausiert während der Suche');
    await tester.tap(find.text('Laden').first);
    // Der Demo-Server bindet die Datei (wie Jellyfin) erst nach ein paar Sekunden ein.
    await pumpFor(tester, const Duration(seconds: 10));

    // Der geladene Untertitel läuft, das Video spielt weiter.
    debugPrint('Untertitel: ${p.state.track.subtitle.id} ${p.state.track.subtitle.language}');
    expect(p.state.track.subtitle.id, isNot('no'));
    expect(p.state.track.subtitle.language, 'ger');
    expect(p.state.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, const Duration(seconds: 2));
  });
}
