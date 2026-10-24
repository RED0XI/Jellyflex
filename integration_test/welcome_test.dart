// Einrichtungs-Assistent beim ersten Start und Server-Suche im Heimnetz.
//
// Voraussetzung:  dart run tool/mock_server.dart   (antwortet auch auf die Heimnetz-Suche)
// Start:          flutter test integration_test/welcome_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/server_discovery.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Erster Start: Assistent, dann Anmeldung mit Server aus dem Heimnetz', (tester) async {
    if (!await demoServerRunning()) return;
    // Wie frisch installiert: keine Einstellungsdatei, keine Konten (Speicher im Temp-Ordner).
    final dir = Directory.systemTemp.createTempSync('jellyflex_welcome_');
    SettingsController make() {
      testSettings(dir).hashCode; // Temp-Speicher für Anmeldung usw. umlenken
      final file = File('${dir.path}${Platform.pathSeparator}settings.json')..deleteSync();
      return SettingsController(file);
    }

    // Heimnetz-Suche nur gegen den Demo-Server auf diesem Rechner.
    ServerDiscovery.target = InternetAddress.loopbackIPv4;

    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(make)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    // Im kleinen Testfenster liegt manches unterhalb – erst hinscrollen.
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(finder.first);
    }

    // Schritt 1: Sprache – Deutsch wählen wirkt sofort.
    expect(find.text(S.en.welcomeTitle), findsOneWidget);
    await tap(find.text('Deutsch'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text(S.de.welcomeTitle), findsOneWidget);
    expect(container.read(settingsProvider).language, AppLanguage.de);
    await saveShot(tester, 'welcome_language');
    await tap(find.text(S.de.next));
    await pumpFor(tester, const Duration(milliseconds: 600));

    // Schritt 2: Aussehen – ein anderes Layout wählen.
    expect(find.text(S.de.setupLookTitle), findsOneWidget);
    await tap(find.text('Sofa'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(container.read(settingsProvider).layoutId, 'couch');
    await saveShot(tester, 'welcome_look');
    await tap(find.text(S.de.next));
    await pumpFor(tester, const Duration(milliseconds: 600));

    // Schritt 3: Fragen – Titelmusik einschalten (Standard: aus).
    expect(find.text(S.de.setupOptionsTitle), findsOneWidget);
    expect(container.read(settingsProvider).themeMusic, isFalse);
    await tap(find.byType(Switch));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(container.read(settingsProvider).themeMusic, isTrue);
    await saveShot(tester, 'welcome_options');
    expect(container.read(settingsProvider).setupDone, isFalse);
    await tap(find.text(S.de.setupFinish));
    await pumpFor(tester, const Duration(seconds: 1));

    // Danach: Anmeldung. Gesucht wird erst nach dem Klick.
    expect(container.read(settingsProvider).setupDone, isTrue);
    expect(find.text(S.de.connectServer), findsOneWidget);
    expect(find.text(S.de.searchNetworkHint), findsOneWidget);
    await tap(find.text(S.de.searchNetwork));
    await pumpFor(tester, const Duration(seconds: 4));
    expect(find.text(S.de.serversFound), findsOneWidget);
    await saveShot(tester, 'welcome_found');
    await tap(find.text('Demo-Server'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.textContaining('Demo-Server · Jellyfin'), findsOneWidget, reason: 'Weiter zur Anmeldung');

    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, const Duration(milliseconds: 300));
    dir.deleteSync(recursive: true);
  });
}
