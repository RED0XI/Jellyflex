// Effizienz-Messung mit einem echten Server: Anfragen (auch doppelte), Bilder, Startzeit,
// Arbeitsspeicher über eine Stöber-Runde und was die App im Leerlauf tut.
// Braucht ein eigenes Profil, in dem schon jemand angemeldet ist (wie bei readme_shots_test).
//
// Start:  flutter test integration_test/efficiency_test.dart -d windows
//           --dart-define=EFF_PROFILE=<Ordner mit settings.json und secure.bin>
// Ohne EFF_PROFILE wird der Test übersprungen.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/image_cache.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/retry.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

const _profile = String.fromEnvironment('EFF_PROFILE');
const _playerRounds = int.fromEnvironment('EFF_PLAYER_ROUNDS', defaultValue: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  int rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  testWidgets('Effizienz mit echtem Server', (tester) async {
    if (_profile.isEmpty) {
      markTestSkipped('EFF_PROFILE nicht gesetzt');
      return;
    }
    // Jede Anfrage an den Server mitschreiben (ohne Anmeldedaten – die stehen im Kopf, nicht in der Adresse).
    final requests = <(String phase, String request)>[];
    var phase = 'Start';
    JellyfinApi.debugObserver = (RequestOptions o) =>
        requests.add((phase, '${o.method} ${o.uri.path}${o.uri.hasQuery ? '?${o.uri.query}' : ''}'));

    // EFF_PROFILE=mock: der eigene Demo-Server (dart run tool/mock_server.dart) statt eines echten.
    final mock = _profile == 'mock';
    if (!mock) {
      final file = File('$_profile${Platform.pathSeparator}settings.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      file.writeAsStringSync(jsonEncode({...json, 'lastSeenVersion': appVersion}));
    }

    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1600, 900));
    final memory = <String, int>{'Vor dem Start': rssMb()};
    final imagesAtStart = ImageDiskCache.instance.downloads;
    final started = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        retry: providerRetry,
        overrides: [
          if (mock) sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(
            () => mock ? testSettings() : testSettings(Directory(_profile), AppLanguage.en),
          ),
        ],
        child: const JellyflexApp(),
      ),
    );

    // Startzeit: bis die ersten Karten mit Bild zu sehen sind.
    var homeMs = -1;
    while (started.elapsedMilliseconds < 30000) {
      await tester.pump(const Duration(milliseconds: 50));
      final loaded = tester.widgetList<RawImage>(find.byType(RawImage)).where((i) => i.image != null).length;
      if (find.byType(LandscapeCard).evaluate().isNotEmpty && loaded >= 4) {
        homeMs = started.elapsedMilliseconds;
        break;
      }
    }
    await wait(tester, 4000);
    memory['Startseite'] = rssMb();
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);
    final api = container.read(apiProvider);

    // Bibliothek öffnen und ganz nach unten scrollen.
    phase = 'Bibliothek';
    final views = await tester.runAsync(api.getUserViews) ?? const <BaseItem>[];
    for (final lib in views.where((v) => v.collectionType == 'movies' || v.collectionType == 'tvshows')) {
      router.push('/library/${lib.id}?name=${Uri.encodeComponent(lib.name)}&type=${lib.collectionType}');
      await wait(tester, 3000);
      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await wait(tester, 300);
      }
      router.go('/');
      await wait(tester, 1000);
    }
    memory['Bibliotheken'] = rssMb();

    // Sechs Detailseiten nacheinander.
    phase = 'Detailseiten';
    final titles = await tester.runAsync(() => api.getRandomPicks(limit: 6)) ?? const <BaseItem>[];
    for (final t in titles) {
      router.push('/item/${t.id}');
      await wait(tester, 2500);
      router.go('/');
      await wait(tester, 800);
    }
    memory['6 Detailseiten'] = rssMb();

    // Player mehrmals öffnen und schließen – wächst der Speicher jedes Mal weiter?
    phase = 'Player';
    final movie = titles.where((t) => t.isMovie).firstOrNull;
    if (movie != null) {
      for (var i = 1; i <= _playerRounds; i++) {
        router.push('/play/${movie.id}');
        await wait(tester, 6000);
        router.go('/');
        await wait(tester, 2000);
        memory['Player $i×'] = rssMb();
      }
    }

    // Eine Minute nichts tun: Was fragt die App von selbst? (Optional ohne Banner-Trailer.)
    if (const bool.fromEnvironment('EFF_NO_TRAILERS')) {
      container.read(settingsProvider.notifier).update((s) => s.copyWith(bannerTrailers: false));
    }
    phase = 'Leerlauf';
    await wait(tester, 60000);
    memory['Nach 1 min Leerlauf'] = rssMb();

    // --- Auswertung ---------------------------------------------------------------------
    final byPhase = <String, List<String>>{};
    for (final (p, r) in requests) {
      byPhase.putIfAbsent(p, () => []).add(r);
    }
    debugPrint('EFF Startzeit bis Karten mit Bildern: $homeMs ms');
    debugPrint('EFF Bilder vom Server geladen: ${ImageDiskCache.instance.downloads - imagesAtStart}');
    for (final e in memory.entries) {
      debugPrint('EFF Speicher ${e.key}: ${e.value} MB');
    }
    for (final e in byPhase.entries) {
      final counts = <String, int>{};
      for (final r in e.value) {
        counts[r] = (counts[r] ?? 0) + 1;
      }
      final dupes = counts.entries.where((c) => c.value > 1).toList()..sort((a, b) => b.value.compareTo(a.value));
      debugPrint(
        'EFF Anfragen ${e.key}: ${e.value.length} (davon ${dupes.fold(0, (s, d) => s + d.value - 1)} doppelt)',
      );
      for (final d in dupes.take(6)) {
        debugPrint('EFF   ${d.value}×  ${d.key.length > 150 ? '${d.key.substring(0, 150)}…' : d.key}');
      }
      if (e.key == 'Leerlauf' || e.key == 'Start') {
        for (final r in counts.keys.take(40)) {
          debugPrint('EFF   · $r');
        }
      }
    }
    JellyfinApi.debugObserver = null;
    await tester.pumpWidget(const SizedBox());
  });
}
