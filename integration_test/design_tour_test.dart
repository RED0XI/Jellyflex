// Design-Durchgang: besucht alle wichtigen Seiten und speichert je ein Bild nach
// build/design_tour/<theme>_<nn>_<seite>.png (Fenster 1600×900) – zum Vergleichen
// von Abständen, Schriften, Symbolen und leeren Zuständen.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/design_tour_test.dart -d windows
//                 (--dart-define=TOUR_THEMES=midnight,frost für weitere Themen)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _themes = String.fromEnvironment('TOUR_THEMES', defaultValue: 'midnight');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Design-Durchgang', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.runAsync(() => windowManager.setSize(const Size(1600, 900)));
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 4));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 450));

    var n = 0;
    var theme = '';
    Future<void> shot(String name) async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      n++;
      final file = File('build/design_tour/${theme}_${n.toString().padLeft(2, '0')}_$name.png')
        ..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      debugPrint('TOUR ${file.path}');
    }

    // Seiten scrollen nur per Mausrad (SmoothScroll), nicht per Ziehen.
    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    Future<void> scrollDown(double dy) async {
      await tester.sendEventToBinding(wheel.hover(const Offset(800, 500)));
      await tester.sendEventToBinding(wheel.scroll(Offset(0, dy)));
      await pumpFor(tester, const Duration(milliseconds: 900));
    }

    Future<void> open(String path, String name, {int ms = 2200}) async {
      router.go('/');
      await pumpFor(tester, const Duration(milliseconds: 400));
      if (path != '/') router.push(path);
      await pumpFor(tester, Duration(milliseconds: ms));
      await mouse.moveTo(const Offset(5, 450));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await shot(name);
    }

    for (final id in _themes.split(',')) {
      theme = id;
      n = 0;
      container.read(settingsProvider.notifier).update((s) => s.copyWith(themeId: id));
      await pumpFor(tester, const Duration(milliseconds: 800));

      await open('/', 'home');
      await scrollDown(700);
      await shot('home_rows');

      // Profilmenü und Kontextmenü einer Karte.
      final avatar = find.bySemanticsLabel('Demo').evaluate().isNotEmpty ? find.bySemanticsLabel('Demo') : null;
      if (avatar != null) {
        await tester.tap(avatar.first);
        await pumpFor(tester, const Duration(milliseconds: 600));
        await shot('profile_menu');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await pumpFor(tester, const Duration(milliseconds: 400));
      }

      await open('/library/lib-movies?name=Filme&type=movies', 'library_movies');
      await open('/library/lib-shows?name=Serien&type=tvshows', 'library_shows');
      await open('/item/movie0', 'details_movie');
      await scrollDown(800);
      await shot('details_movie_rows');
      await open('/item/series0', 'details_series');
      await scrollDown(600);
      await shot('details_series_episodes');
      await open('/item/series0_s1_e2', 'details_episode');
      await open('/person/person0', 'person');
      await open('/search', 'search_empty');
      await tester.enterText(find.byType(EditableText).first, 'Nord');
      await pumpFor(tester, const Duration(seconds: 2));
      await shot('search_results');
      await open('/lists', 'lists');
      await open('/downloads', 'downloads');
      await open('/calendar', 'calendar');
      for (final section in ['general', 'playback', 'appearance', 'downloads', 'advanced', 'about']) {
        await open('/settings?section=$section', 'settings_$section');
      }
      await open('/roulette', 'roulette');
      await open('/wrapped', 'wrapped', ms: 4000);

      // Player mit Bedienleiste und Spur-Panel.
      player = null;
      router.go('/');
      await pumpFor(tester, const Duration(milliseconds: 400));
      router.push('/play/movie1?start=1');
      for (var i = 0; i < 80 && (player?.state.duration ?? Duration.zero) == Duration.zero; i++) {
        await pumpFor(tester, const Duration(milliseconds: 100));
      }
      await mouse.moveTo(const Offset(800, 450));
      await mouse.moveTo(const Offset(820, 470));
      await pumpFor(tester, const Duration(milliseconds: 700));
      await shot('player_controls');
      await tester.tap(find.byIcon(Icons.subtitles_rounded));
      await pumpFor(tester, const Duration(milliseconds: 700));
      await shot('player_tracks');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester, const Duration(seconds: 2));
    }
  });
}
