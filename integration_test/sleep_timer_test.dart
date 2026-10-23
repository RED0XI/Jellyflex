// Prüft den Schlaf-Timer im Player gegen den Demo-Server: Menü, Ausblenden der
// Lautstärke, Anhalten mit "Gute Nacht", Weiterschauen, "am Ende des Films".
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/sleep_timer_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'sleep-test',
  );
}

final _shotKey = GlobalKey();

Future<void> _saveShot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Schlaf-Timer im Player', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
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
        overrides: [sessionProvider.overrideWith(_DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    container.read(routerProvider).push('/play/movie1');
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    final p = player!;
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // --- Menü: 30 Minuten wählen (Bedienelemente sind direkt nach dem Start sichtbar) ---
    await tester.tap(find.byTooltip('Schlaf-Timer'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Am Ende des Films'), findsOneWidget);
    await _saveShot(tester, 'sleep_menu');
    await tester.tap(find.text('In 30 Minuten'));
    await _pumpFor(tester, const Duration(milliseconds: 1500));
    expect(SleepTimer.instance.mode, SleepMode.minutes);
    expect(find.textContaining(RegExp(r'^(29|30) Min\.$')), findsOneWidget);

    // --- Kurzer Timer: Lautstärke sinkt, dann Anhalten mit "Gute Nacht" ---
    await tester.runAsync(() => p.setVolume(100));
    SleepTimer.instance.debugSetEndsAt(DateTime.now().add(const Duration(seconds: 8)));
    await _pumpFor(tester, const Duration(seconds: 3));
    debugPrint('Lautstärke beim Ausblenden: ${p.state.volume}');
    expect(p.state.volume, lessThan(20), reason: 'In der letzten Minute wird es leiser');
    expect(p.state.playing, isTrue);
    await _pumpFor(tester, const Duration(seconds: 7));
    expect(p.state.playing, isFalse, reason: 'Timer abgelaufen → angehalten');
    expect(find.text('Gute Nacht'), findsOneWidget);
    expect(p.state.volume, 100, reason: 'Lautstärke für das nächste Mal zurückgesetzt');
    expect(SleepTimer.instance.active, isFalse);
    await _pumpFor(tester, const Duration(seconds: 2));
    await _saveShot(tester, 'sleep_goodnight');

    await tester.tap(find.text('Weiterschauen'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Gute Nacht'), findsNothing);
    expect(p.state.playing, isTrue);

    // --- "Am Ende des Films": Player bleibt offen und zeigt "Gute Nacht" ---
    SleepTimer.instance.setEndOfItem();
    await tester.runAsync(() => p.seek(p.state.duration - const Duration(seconds: 3)));
    await _pumpFor(tester, const Duration(seconds: 6));
    expect(find.byType(PlayerScreen), findsOneWidget, reason: 'Player schließt sich nicht von selbst');
    expect(find.text('Gute Nacht'), findsOneWidget);
    expect(SleepTimer.instance.active, isFalse);

    await tester.tap(find.text('Player schließen'));
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PlayerScreen), findsNothing);
  });
}
