// Kleine Player-Verbesserungen gegen den Demo-Server: Mausrad-Lautstärke bis 150 %,
// Zurückspulen beim Fortsetzen, "Schaust du noch?" und "Zufällig abspielen".
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/player_quick_test.dart -d windows

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/play_queue.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  late ProviderContainer container;
  Player? player;

  Future<void> startApp(WidgetTester tester) async {
    await windowManager.ensureInitialized();
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
  }

  /// Wartet, bis der Player eine Datei geöffnet hat.
  Future<Player> waitForPlayer(WidgetTester tester) async {
    player = null;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    await pumpFor(tester, const Duration(milliseconds: 600));
    return player!;
  }

  String location() => container.read(routerProvider).state.uri.toString();

  Future<void> closePlayer(WidgetTester tester) async {
    container.read(routerProvider).go('/');
    await pumpFor(tester, const Duration(seconds: 1));
  }

  testWidgets('Lautstärke mit dem Mausrad, Zurückspulen beim Fortsetzen', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);

    // Fortsetzen bei 1:00 → ein paar Sekunden früher.
    container.read(routerProvider).push('/play/movie1?start=${60 * 10000000}');
    final p = await waitForPlayer(tester);
    expect(p.state.position.inSeconds, inInclusiveRange(54, 57), reason: '5 Sekunden zurück');

    // Mausrad auf dem Bild: lauter, mit Anzeige; höchstens 150 %.
    final start = p.state.volume;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byType(PlayerScreen));
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(p.state.volume, start + 5);
    expect(find.text('${(start + 5).round()} %'), findsOneWidget, reason: 'Anzeige in der Mitte');
    await saveShot(tester, 'player_volume_osd');
    for (var i = 0; i < 20; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    }
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(p.state.volume, PlayerScreen.maxVolume);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(p.state.volume, PlayerScreen.maxVolume - 5);
    // Gemerkt werden höchstens 100 %.
    await pumpFor(tester, const Duration(seconds: 1));
    expect(container.read(settingsProvider).playerVolume, 100);

    await closePlayer(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Nach mehreren Folgen von selbst: "Schaust du noch?"', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);

    // Wie nach drei Folgen ohne Bedienung.
    PlayerScreen.autoPlayedInARow = PlayerScreen.stillWatchingAfter;
    container.read(routerProvider).push('/play/series0_s1_e1?auto=1');
    final p = await waitForPlayer(tester);
    await p.seek(p.state.duration - const Duration(seconds: 2));
    await pumpFor(tester, const Duration(seconds: 5));
    expect(find.text('Schaust du noch?'), findsOneWidget);
    expect(location(), contains('series0_s1_e1'), reason: 'Nächste Folge startet nicht von selbst');
    await saveShot(tester, 'player_still_watching');

    await tester.tap(find.text('Weiterschauen'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(location(), contains('series0_s1_e2'));
    expect(PlayerScreen.autoPlayedInARow, 0);

    await closePlayer(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Zufällig abspielen auf der Serien-Seite', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);

    container.read(routerProvider).push('/item/series0');
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Zufällig'));
    await waitForPlayer(tester);
    final uri = Uri.parse(location());
    expect(uri.queryParameters['queue'], '1');
    final current = uri.pathSegments.last;
    expect(current, startsWith('series0_'), reason: 'Nur Folgen dieser Serie');
    expect(PlayQueue.contains(current), isTrue);
    expect(PlayQueue.after(current), startsWith('series0_'));

    // Wer danach selbst etwas anderes startet, beendet die Warteschlange.
    container.read(routerProvider).go('/');
    await pumpFor(tester, const Duration(seconds: 1));
    container.read(routerProvider).push('/play/movie1');
    await waitForPlayer(tester);
    expect(PlayQueue.contains(current), isFalse);

    await closePlayer(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
