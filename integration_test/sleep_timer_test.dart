// Prüft den Schlaf-Timer im Player gegen den Demo-Server: Menü, Ausblenden der
// Lautstärke, Anhalten mit "Gute Nacht", Weiterschauen, "am Ende des Films".
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/sleep_timer_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/sleep_timer.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Schlaf-Timer im Player', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    SleepTimer.instance.cancel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    container.read(routerProvider).push('/play/movie1');
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    final p = player!;
    await pumpFor(tester, const Duration(milliseconds: 500));

    // --- Menü: 30 Minuten wählen (Bedienelemente sind direkt nach dem Start sichtbar) ---
    await tester.tap(find.byTooltip('Schlaf-Timer'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Am Ende des Films'), findsOneWidget);
    await saveShot(tester, 'sleep_menu');
    await tester.tap(find.text('In 30 Minuten'));
    await pumpFor(tester, const Duration(milliseconds: 1500));
    expect(SleepTimer.instance.mode, SleepMode.minutes);
    expect(find.textContaining(RegExp(r'^(29|30) Min\.$')), findsOneWidget);

    // --- Kurzer Timer: Lautstärke sinkt, dann Anhalten mit "Gute Nacht" ---
    await tester.runAsync(() => p.setVolume(100));
    SleepTimer.instance.debugSetEndsAt(DateTime.now().add(const Duration(seconds: 8)));
    await pumpFor(tester, const Duration(seconds: 3));
    debugPrint('Lautstärke beim Ausblenden: ${p.state.volume}');
    expect(p.state.volume, lessThan(20), reason: 'In der letzten Minute wird es leiser');
    expect(p.state.playing, isTrue);
    await pumpFor(tester, const Duration(seconds: 7));
    expect(p.state.playing, isFalse, reason: 'Timer abgelaufen → angehalten');
    expect(find.text('Gute Nacht'), findsOneWidget);
    expect(p.state.volume, 100, reason: 'Lautstärke für das nächste Mal zurückgesetzt');
    expect(SleepTimer.instance.active, isFalse);
    await pumpFor(tester, const Duration(seconds: 2));
    await saveShot(tester, 'sleep_goodnight');

    await tester.tap(find.text('Weiterschauen'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Gute Nacht'), findsNothing);
    expect(p.state.playing, isTrue);

    // --- "Am Ende des Films": Player bleibt offen und zeigt "Gute Nacht" ---
    SleepTimer.instance.setEndOfItem();
    await tester.runAsync(() => p.seek(p.state.duration - const Duration(seconds: 3)));
    await pumpFor(tester, const Duration(seconds: 6));
    expect(find.byType(PlayerScreen), findsOneWidget, reason: 'Player schließt sich nicht von selbst');
    expect(find.text('Gute Nacht'), findsOneWidget);
    expect(SleepTimer.instance.active, isFalse);

    await tester.tap(find.text('Player schließen'));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PlayerScreen), findsNothing);
  });
}
