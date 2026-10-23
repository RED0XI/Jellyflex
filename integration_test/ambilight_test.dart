// Prüft das Ambilight-Leuchten im Player gegen den Demo-Server: Mit einem fast
// quadratischen Fenster entstehen Balken über/unter dem Video – mit Ambilight sind
// sie farbig, ohne schwarz.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/ambilight_test.dart -d windows

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'ambilight-test',
  );
}

final _shotKey = GlobalKey();

/// Bildschirmfoto speichern und die Pixel (RGBA) zurückgeben.
Future<(ByteData, int)> _shot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  final raw = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
  return (raw!, image.width);
}

/// Mittlere Helligkeit eines Streifens oben im Bild (im Balken über dem Video).
double _barBrightness((ByteData, int) shot, int y) {
  final (data, width) = shot;
  var sum = 0.0;
  var n = 0;
  for (var x = width ~/ 4; x < width * 3 ~/ 4; x += 7) {
    final i = (y * width + x) * 4;
    sum += (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) / 3;
    n++;
  }
  return sum / n;
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

  testWidgets('Ambilight im Player', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final oldSize = await tester.runAsync(windowManager.getSize);
    final temp = Directory.systemTemp.createTempSync('jellyflex_ambilight_');
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    try {
      await tester.runAsync(() => windowManager.setSize(const Size(1040, 900)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp)),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      expect(container.read(settingsProvider).ambilight, AmbilightMode.window, reason: 'Standard: im Fenster an');

      container.read(routerProvider).push('/play/movie1');
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
      }
      await tester.runAsync(() => player!.seek(const Duration(seconds: 20)));
      // Bedienelemente ausblenden lassen (sonst liegt oben der dunkle Verlauf).
      await _pumpFor(tester, const Duration(seconds: 5));

      final on = await _shot(tester, 'ambilight_on');
      container.read(settingsProvider.notifier).update((s) => s.copyWith(ambilight: AmbilightMode.off));
      await _pumpFor(tester, const Duration(seconds: 1));
      final off = await _shot(tester, 'ambilight_off');

      // Etwa in der Mitte des oberen Balkens messen.
      final (_, width) = on;
      final barY = ((on.$1.lengthInBytes ~/ 4 ~/ width) - width * 9 ~/ 16) ~/ 4;
      final bright = _barBrightness(on, barY);
      final dark = _barBrightness(off, barY);
      debugPrint('Balken-Helligkeit: mit Ambilight $bright, ohne $dark (Zeile $barY)');
      expect(dark, lessThan(8), reason: 'Ohne Ambilight sind die Balken schwarz');
      expect(bright, greaterThan(dark + 10), reason: 'Mit Ambilight leuchten die Balken');
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (oldSize != null) await tester.runAsync(() => windowManager.setSize(oldSize));
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
