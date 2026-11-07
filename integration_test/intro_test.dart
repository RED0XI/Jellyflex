// Intro beim Start: läuft durch, zeigt Zeichen und Namen, lässt sich mit einer Taste überspringen.
// Bilder einzelner Momente: build/screenshots/intro_*.png
//
// Start:  flutter test integration_test/intro_test.dart -d macos

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
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/widgets/app_intro.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Intro beim Start', (tester) async {
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_intro_');
    // Intro an, aber ohne Klang (Tests sollen still sein).
    File('${temp.path}/settings.json').writeAsStringSync(
      jsonEncode({'language': 'de', 'lastSeenVersion': appVersion, 'intro': true, 'soundEffects': false}),
    );
    AppIntro.showInTests = true;
    AppIntro.debugReset();
    addTearDown(() {
      AppIntro.showInTests = false;
      temp.deleteSync(recursive: true);
    });

    Widget app() => ProviderScope(
      overrides: [
        sessionProvider.overrideWith(DemoSession.new),
        settingsProvider.overrideWith(() => testSettings(temp)),
      ],
      child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
    );

    await tester.pumpWidget(app());
    final start = DateTime.now();
    for (final ms in [250, 500, 800, 1100, 1400, 1800, 2300, 2700]) {
      await pumpFor(tester, Duration(milliseconds: ms) - DateTime.now().difference(start));
      await saveShot(tester, 'intro_$ms');
    }
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('J'), findsNothing, reason: 'Intro ist durch (einzelne Buchstaben weg)');

    // Neustart der App im selben Programm: kein zweites Intro.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('J'), findsNothing, reason: 'nur einmal je Programmstart');

    // Überspringen per Taste.
    AppIntro.debugReset();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(find.text('J'), findsOneWidget, reason: 'Intro läuft');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('J'), findsNothing, reason: 'mit Taste übersprungen');
    await tester.pumpWidget(const SizedBox());
  });
}
