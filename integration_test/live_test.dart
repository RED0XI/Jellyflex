// Prüft Live-Verbindung und Fernsteuerung gegen den Demo-Server.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/live_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/gamepad_input.dart';
import 'package:jellyflex/features/details/details_screen.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:jellyflex/features/search/search_screen.dart';
import 'package:jellyflex/widgets/focusable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';

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
        overrides: [sessionProvider.overrideWith(_DemoSession.new), settingsProvider.overrideWith(testSettings)],
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

  testWidgets('Bedienung ohne Maus: Tastatur und Controller', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('http://localhost:8097/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: const JellyflexApp(),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 4));

    // --- Tastatur: Pfeiltasten bis in die erste Reihe, Enter öffnet Details ---
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _pumpFor(tester, const Duration(milliseconds: 400));
      final f = FocusManager.instance.primaryFocus;
      debugPrint('NACH ↓ $i: $f | ${f?.context?.findAncestorWidgetOfExactType<Focusable>()?.runtimeType}');
    }
    final focused = FocusManager.instance.primaryFocus;
    debugPrint('Fokus nach ↓↓↓↓: ${focused?.context?.widget.runtimeType} / ${focused?.debugLabel}');
    expect(focused?.context?.findAncestorWidgetOfExactType<Focusable>(), isNotNull);

    // Kontextmenü per Tastatur (Umschalt+F10) – erscheint nur auf Karten.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    final menuOpen = find.text('Details').evaluate().isNotEmpty;
    debugPrint('Kontextmenü offen: $menuOpen');
    if (menuOpen) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    final beforeEnter = FocusManager.instance.primaryFocus;
    debugPrint(
      'Fokus vor Enter: $beforeEnter / in Focusable: ${beforeEnter?.context?.findAncestorWidgetOfExactType<Focusable>() != null}',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(DetailsScreen), findsOneWidget, reason: 'Enter auf einer Karte öffnet die Details');

    // --- Controller: B = zurück, Steuerkreuz + A = wieder öffnen ---
    GamepadInput.simulate(PadAction.back);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(DetailsScreen), findsNothing, reason: 'B geht zurück');

    GamepadInput.simulate(PadAction.right);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    GamepadInput.simulate(PadAction.select);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(DetailsScreen), findsOneWidget, reason: 'Steuerkreuz + A öffnet die Details');

    GamepadInput.simulate(PadAction.back);
    await _pumpFor(tester, const Duration(seconds: 1));
    GamepadInput.simulate(PadAction.search);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(SearchScreen), findsOneWidget, reason: 'Y öffnet die Suche');
  });
}
