// Prüft das Film-Quiz gegen den Demo-Server: Bild wird deutlicher, Zeitablauf,
// Antworten per Zifferntaste, Ergebnis und gespeicherter Rekord.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/quiz_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
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

import 'test_settings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Film-Quiz', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
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
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

      await tester.tap(find.byTooltip('Film-Quiz'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Runde 1 von 8'), findsOneWidget);
      await saveShot(tester, 'quiz_start');
      await pumpFor(tester, const Duration(seconds: 7));
      await saveShot(tester, 'quiz_clearer');

      // --- Runde 1: Zeit läuft ab → zählt als falsch ---
      await pumpFor(tester, const Duration(seconds: 7));
      expect(find.text('Leider nicht'), findsOneWidget);
      await saveShot(tester, 'quiz_reveal');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(find.text('Runde 2 von 8'), findsOneWidget);

      // --- Runden 2–8: per Zifferntaste antworten ---
      for (var round = 2; round <= 8; round++) {
        await pumpFor(tester, const Duration(milliseconds: 1200));
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await pumpFor(tester, const Duration(milliseconds: 800));
        expect(
          find.textContaining(RegExp(r'^(Richtig! \+\d+|Leider nicht)$')),
          findsOneWidget,
          reason: 'Runde $round ausgewertet',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await pumpFor(tester, const Duration(milliseconds: 600));
      }

      // --- Ergebnis ---
      final scoreText = find.textContaining(RegExp(r'^\d+ Punkte$'));
      expect(scoreText, findsOneWidget);
      expect(find.textContaining(RegExp(r'von 8 richtig')), findsOneWidget);
      final score = int.parse((scoreText.evaluate().single.widget as Text).data!.split(' ').first);
      debugPrint('Punkte: $score');
      expect(container.read(settingsProvider).quizHighscore, score, reason: 'Rekord gespeichert');
      await saveShot(tester, 'quiz_result');
    } finally {
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
