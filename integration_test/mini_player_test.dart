// Prüft den Mini-Player gegen den Demo-Server: P verkleinert das Fenster und hält
// es im Vordergrund, Esc holt das große Fenster zurück, Schließen beendet beides.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/mini_player_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:jellyflex/widgets/window_frame.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'mini-test',
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

  testWidgets('Mini-Player', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new)],
        child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final before = (await tester.runAsync(windowManager.getBounds))!;
    debugPrint('Fenster vorher: $before');

    try {
      container.read(routerProvider).push('/play/movie1');
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
      }
      final p = player!;

      // --- P: klein und im Vordergrund ---
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(windowMiniPlayer.value, isTrue);
      final mini = (await tester.runAsync(windowManager.getBounds))!;
      debugPrint('Mini-Fenster: $mini');
      expect(mini.width, lessThan(560));
      expect(mini.height, lessThan(340));
      expect(await tester.runAsync(windowManager.isAlwaysOnTop), isTrue);
      expect(p.state.playing, isTrue, reason: 'Video läuft weiter');
      // Maus darüber → Bedienelemente des Mini-Players.
      await _saveShot(tester, 'mini_player');
      expect(find.byTooltip('Großes Fenster (P)'), findsOneWidget);

      // --- Esc: großes Fenster zurück, Player bleibt offen ---
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(windowMiniPlayer.value, isFalse);
      expect(find.byType(PlayerScreen), findsOneWidget);
      final restored = (await tester.runAsync(windowManager.getBounds))!;
      expect((restored.width - before.width).abs(), lessThan(4));
      expect((restored.height - before.height).abs(), lessThan(4));
      expect(await tester.runAsync(windowManager.isAlwaysOnTop), isFalse);

      // --- Wieder klein, dann Schließen: Player zu, Fenster normal ---
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(windowMiniPlayer.value, isTrue);
      await tester.tap(find.byTooltip('Schließen'));
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.byType(PlayerScreen), findsNothing);
      expect(windowMiniPlayer.value, isFalse);
      final after = (await tester.runAsync(windowManager.getBounds))!;
      expect((after.width - before.width).abs(), lessThan(4));
    } finally {
      if (windowMiniPlayer.value) await tester.runAsync(() => setWindowMiniPlayer(false));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
