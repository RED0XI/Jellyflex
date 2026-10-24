// "Was ist neu": erscheint einmal nach einem Update, nicht nach einer Neuinstallation.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/whats_new_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/changelog.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  Future<ProviderContainer> start(WidgetTester tester, Directory dir) async {
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings(dir)),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    return ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
  }

  testWidgets('Nach einem Update: Neuigkeiten einmal zeigen', (tester) async {
    if (!await demoServerRunning()) return;
    final dir = Directory.systemTemp.createTempSync('jellyflex_whatsnew_');
    // Zuletzt war 0.3.1 installiert.
    File('${dir.path}${Platform.pathSeparator}settings.json')
        .writeAsStringSync(jsonEncode({'language': 'de', 'lastSeenVersion': '0.3.1'}));
    final container = await start(tester, dir);
    expect(find.textContaining('Neu in Jellyflex'), findsOneWidget);
    // Überschriften je Version gibt es erst, wenn mehrere Versionen neu sind (ab 0.3.4).
    if (changesSince('0.3.1', appVersion).length > 1) {
      expect(find.text('Version 0.3.2'), findsWidgets, reason: 'Überschrift je Version');
    }
    expect(find.textContaining('Updates installieren sich selbst'), findsOneWidget);
    expect(find.textContaining('Smart Downloads'), findsNothing, reason: '0.3.0 war schon bekannt');
    await saveShot(tester, 'whats_new');
    await tester.tap(find.text('Alles klar'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('Neu in Jellyflex'), findsNothing);
    expect(container.read(settingsProvider).lastSeenVersion, appVersion);

    // Nächster Start: nicht noch einmal.
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, const Duration(milliseconds: 500));
    await start(tester, dir);
    expect(find.textContaining('Neu in Jellyflex'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Frisch installiert: kein Neuigkeiten-Fenster', (tester) async {
    if (!await demoServerRunning()) return;
    final dir = Directory.systemTemp.createTempSync('jellyflex_whatsnew_fresh_');
    // Keine Einstellungsdatei vorher – wie nach einer Neuinstallation. (testSettings legt
    // sonst eine an; hier übernimmt der Controller eine noch nicht existierende Datei.)
    SettingsController make() {
      testSettings(dir).hashCode; // Temp-Speicher für Anmeldung usw. umlenken
      final file = File('${dir.path}${Platform.pathSeparator}settings.json')..deleteSync();
      return SettingsController(file);
    }

    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(make)],
        child: const JellyflexApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.textContaining('in Jellyflex'), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    expect(container.read(settingsProvider).lastSeenVersion, appVersion, reason: 'Gilt jetzt als gesehen');
    await tester.pumpWidget(const SizedBox());
  });
}
