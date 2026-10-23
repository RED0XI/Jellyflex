// Prüft "Überrasch mich" gegen den Demo-Server: Rad füllen, drehen, Gewinner
// anzeigen; mit "Nur Ungesehenes" kommt nie ein schon gesehener Film.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/roulette_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/roulette/roulette_screen.dart';
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
    deviceId: 'roulette-test',
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
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Großer Titel der Gewinnerkarte.
String? _winnerTitle() {
  final title = find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 34);
  return title.evaluate().isEmpty ? null : (title.evaluate().first.widget as Text).data;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Überrasch mich: drehen und Gewinner', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new)],
        child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 3));

    // Über den Würfel oben in der Leiste öffnen.
    await tester.tap(find.byTooltip('Überrasch mich'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(RouletteScreen), findsOneWidget);
    expect(find.text('Drehen'), findsOneWidget);
    await _saveShot(tester, 'roulette_start');

    final winners = <String>{};
    for (var round = 0; round < 3; round++) {
      await tester.tap(find.textContaining('rehen').last);
      await _pumpFor(tester, const Duration(milliseconds: 1800));
      if (round == 0) await _saveShot(tester, 'roulette_spinning');
      expect(find.text('Dreht …'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 4));
      final winner = _winnerTitle();
      debugPrint('Gewinner $round: $winner');
      expect(winner, isNotNull, reason: 'Nach dem Drehen steht ein Gewinner fest');
      expect(winner, isNot('Stadt aus Glas'), reason: 'Schon gesehen – mit "Nur Ungesehenes" ausgeschlossen');
      winners.add(winner!);
      if (round == 0) await _saveShot(tester, 'roulette_winner');
    }
    expect(find.text('Abspielen'), findsOneWidget);
    debugPrint('Verschiedene Gewinner: ${winners.length}');
  });
}
