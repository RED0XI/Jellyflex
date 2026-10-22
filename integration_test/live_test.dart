// Prüft Live-Verbindung und Fernsteuerung gegen den Demo-Server.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/live_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: 'http://localhost:8097',
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'live-test',
  );
}

Future<int> _send(String type, Object data) async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('http://localhost:8097/debug/send'));
  req.write(jsonEncode({'MessageType': type, 'Data': data}));
  final res = await req.close();
  final body = await utf8.decoder.bind(res).join();
  client.close();
  return (jsonDecode(body) as Map)['sent'] as int;
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

  testWidgets('Live-Verbindung: Nachricht, Abspielen, Fernsteuerung', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('http://localhost:8097/System/Info/Public')).then((r) => r.close());
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
        child: const JellyflexApp(),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 4));

    // --- Mitteilung vom Server ---
    final clients = await tester.runAsync(
      () => _send('GeneralCommand', {
        'Name': 'DisplayMessage',
        'Arguments': {'Header': 'Hallo', 'Text': 'Test vom Handy'},
      }),
    );
    debugPrint('Live-Clients: $clients');
    expect(clients, greaterThanOrEqualTo(1), reason: 'App sollte per WebSocket verbunden sein');
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Hallo: Test vom Handy'), findsOneWidget);

    // --- Abspielen per Fernsteuerung ---
    await tester.runAsync(
      () => _send('Play', {
        'ItemIds': ['movie1'],
        'PlayCommand': 'PlayNow',
      }),
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    expect(find.byType(PlayerScreen), findsOneWidget);
    final p = player!;
    await _pumpFor(tester, const Duration(seconds: 1));

    await tester.runAsync(() => _send('Playstate', {'Command': 'Pause'}));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(p.state.playing, isFalse);

    await tester.runAsync(() => _send('Playstate', {'Command': 'Seek', 'SeekPositionTicks': 300000000}));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(p.state.position.inSeconds, inInclusiveRange(29, 31));

    await tester.runAsync(
      () => _send('GeneralCommand', {
        'Name': 'SetVolume',
        'Arguments': {'Volume': '30'},
      }),
    );
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(p.state.volume, 30);

    await tester.runAsync(() => _send('Playstate', {'Command': 'Stop'}));
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PlayerScreen), findsNothing);
  });
}
