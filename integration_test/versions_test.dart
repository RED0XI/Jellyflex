// Prüft Fassungen und Medieninfo gegen den Demo-Server: Abzeichen, Fassung
// wählen, gewählte Fassung abspielen, Medieninfo-Fenster.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/versions_test.dart -d windows

import 'dart:convert';
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
import 'package:jellyflex/widgets/buttons.dart';
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
    deviceId: 'versions-test',
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

Future<Map<String, dynamic>> _lastStream() async {
  final client = HttpClient();
  final res = await (await client.getUrl(Uri.parse('$_server/debug/laststream'))).close();
  final body = await utf8.decoder.bind(res).join();
  client.close();
  return (jsonDecode(body) as Map).cast<String, dynamic>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Fassungen: Abzeichen, wählen, abspielen, Medieninfo', (tester) async {
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

    container.read(routerProvider).push('/item/movie0');
    await _pumpFor(tester, const Duration(seconds: 2));

    // Standard: 4K-Fassung mit Dolby Vision und Atmos.
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('Dolby Vision'), findsOneWidget);
    expect(find.text('Atmos'), findsOneWidget);
    final versionButton = find.text('Fassung: 4K Dolby Vision');
    expect(versionButton, findsOneWidget);
    await _saveShot(tester, 'versions_details');

    // Fassung wechseln.
    await tester.tap(versionButton);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('4K Remux · 57,2 GB · 62,0 Mbit/s'), findsOneWidget);
    await _saveShot(tester, 'versions_menu');
    await tester.tap(find.text('1080p · H.264'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Fassung: 1080p'), findsOneWidget);
    expect(find.text('Dolby Vision'), findsNothing);
    expect(find.text('1080p'), findsOneWidget, reason: 'Abzeichen zeigt die gewählte Fassung');

    // Abspielen → der Player fragt genau diese Fassung an.
    await tester.tap(find.byType(PrimaryButton).first);
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    expect(find.byType(PlayerScreen), findsOneWidget);
    final stream = await tester.runAsync(_lastStream);
    debugPrint('Stream: $stream');
    expect(stream!['mediaSourceId'], 'movie0-hd');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PlayerScreen), findsNothing);

    // Medieninfo der gewählten Fassung.
    await tester.tap(find.byTooltip('Medieninfo (Auflösung, Ton, Untertitel …)'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('Medieninfo'), findsOneWidget);
    expect(find.text('1920 × 1080  (1080p)'), findsOneWidget);
    expect(find.text('Englisch - AAC - Stereo'), findsOneWidget);
    await _saveShot(tester, 'versions_info_hd');
    await tester.tap(find.byTooltip('Schließen'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // Zurück auf 4K: Medieninfo mit HDR und Atmos.
    await tester.tap(find.text('Fassung: 1080p'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('4K · Dolby Vision · HEVC'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Medieninfo (Auflösung, Ton, Untertitel …)'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('3840 × 2160  (4K)'), findsOneWidget);
    expect(find.text('10 Bit'), findsOneWidget);
    expect(find.text('Englisch - TrueHD Atmos - 7.1'), findsOneWidget);
    await _saveShot(tester, 'versions_info_4k');
  });
}
