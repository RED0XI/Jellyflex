// Prüft das Film-Quiz gegen den Demo-Server: Bild wird deutlicher, Zeitablauf,
// Antworten per Zifferntaste, Ergebnis und gespeicherter Rekord.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/quiz_test.dart -d windows

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
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/quiz/quiz_screen.dart';
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
    deviceId: 'quiz-test',
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

  testWidgets('Film-Quiz', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_quiz_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_DemoSession.new),
            settingsProvider.overrideWith(() => SettingsController(File('${temp.path}\\settings.json'))),
          ],
          child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
        ),
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

      await tester.tap(find.byTooltip('Film-Quiz'));
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Runde 1 von 8'), findsOneWidget);
      await _saveShot(tester, 'quiz_start');
      await _pumpFor(tester, const Duration(seconds: 7));
      await _saveShot(tester, 'quiz_clearer');

      // --- Runde 1: Zeit läuft ab → zählt als falsch ---
      await _pumpFor(tester, const Duration(seconds: 7));
      expect(find.text('Leider nicht'), findsOneWidget);
      await _saveShot(tester, 'quiz_reveal');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(find.text('Runde 2 von 8'), findsOneWidget);

      // --- Runden 2–8: per Zifferntaste antworten ---
      for (var round = 2; round <= 8; round++) {
        await _pumpFor(tester, const Duration(milliseconds: 1200));
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await _pumpFor(tester, const Duration(milliseconds: 800));
        expect(
          find.textContaining(RegExp(r'^(Richtig! \+\d+|Leider nicht)$')),
          findsOneWidget,
          reason: 'Runde $round ausgewertet',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _pumpFor(tester, const Duration(milliseconds: 600));
      }

      // --- Ergebnis ---
      final scoreText = find.textContaining(RegExp(r'^\d+ Punkte$'));
      expect(scoreText, findsOneWidget);
      expect(find.textContaining(RegExp(r'von 8 richtig')), findsOneWidget);
      final score = int.parse((scoreText.evaluate().single.widget as Text).data!.split(' ').first);
      debugPrint('Punkte: $score');
      expect(container.read(settingsProvider).quizHighscore, score, reason: 'Rekord gespeichert');
      await _saveShot(tester, 'quiz_result');
    } finally {
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
