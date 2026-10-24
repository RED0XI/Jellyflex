// Wiedergabe-Messung: spielt die Datei aus JELLYFLEX_TEST_VIDEO (über den Demo-Server) im
// Vollbild ab und liest aus mpv, ob die Grafikkarte dekodiert und wie viele Bilder verloren gehen.
// Gedacht für anspruchsvolle Dateien (4K, HDR, 60 fps, AV1) – kein fester Bestandteil der Testreihe.
//
// Start:  $env:JELLYFLEX_TEST_VIDEO = '...\4k_hdr10_hevc.mkv'; dart run tool/mock_server.dart
//         flutter test integration_test/playback_perf_test.dart -d windows

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

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Wiedergabe: Dekoder und verlorene Bilder', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final router = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp))).read(routerProvider);
    router.push('/play/movie2');
    for (var i = 0; i < 100 && (player?.state.duration ?? Duration.zero) == Duration.zero; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final native = player!.platform! as NativePlayer;
    Future<String> prop(String name) async {
      try {
        return await native.getProperty(name);
      } catch (_) {
        return '?';
      }
    }

    // Vollbild wie beim echten Schauen; kurz einschwingen lassen.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await pumpFor(tester, const Duration(seconds: 4));
    final dropsBefore = int.tryParse(await prop('frame-drop-count')) ?? 0;
    final decoderBefore = int.tryParse(await prop('decoder-frame-drop-count')) ?? 0;
    final delayedBefore = int.tryParse(await prop('vo-delayed-frame-count')) ?? 0;
    final positionBefore = player!.state.position;

    await pumpFor(tester, const Duration(seconds: 20));

    final played = player!.state.position - positionBefore;
    final fps = double.tryParse(await prop('container-fps')) ?? 0;
    final report = {
      'Codec': await prop('video-codec'),
      'Auflösung': '${await prop('video-params/w')}x${await prop('video-params/h')}',
      'Farbraum/Kurve': '${await prop('video-params/primaries')} / ${await prop('video-params/gamma')}',
      'Ausgabe (nach Umrechnung)':
          '${await prop('video-out-params/primaries')} / ${await prop('video-out-params/gamma')}',
      'Dekoder (hwdec)': await prop('hwdec-current'),
      'Bilder/s (Datei)': fps.toStringAsFixed(2),
      'Abgespielt': '${played.inMilliseconds / 1000} s von 20 s',
      'Verlorene Bilder (Ausgabe)': (int.tryParse(await prop('frame-drop-count')) ?? 0) - dropsBefore,
      'Verlorene Bilder (Dekoder)': (int.tryParse(await prop('decoder-frame-drop-count')) ?? 0) - decoderBefore,
      'Verspätete Bilder': (int.tryParse(await prop('vo-delayed-frame-count')) ?? 0) - delayedBefore,
      'Erwartete Bilder': (fps * played.inMilliseconds / 1000).round(),
    };
    for (final e in report.entries) {
      debugPrint('PERF ${e.key}: ${e.value}');
    }
    await saveShot(tester, 'perf_player');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    expect(played.inSeconds, greaterThanOrEqualTo(18), reason: 'Wiedergabe lief ohne Stocken durch');
  });
}
