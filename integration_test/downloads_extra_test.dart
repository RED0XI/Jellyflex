// Prüft die erweiterten Downloads gegen den Demo-Server: nur über WLAN/LAN,
// Geschwindigkeitsgrenze, kleinere Fassung mit gewählter Tonspur und Smart Downloads.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/downloads_extra_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<String> _call(String method, String path, [String? body]) async {
  final client = HttpClient();
  final req = await client.openUrl(method, Uri.parse('$demoServer$path'));
  if (body != null) req.write(body);
  final res = await req.close();
  final text = await utf8.decoder.bind(res).join();
  client.close();
  return text;
}

Future<bool> _waitFor(WidgetTester tester, bool Function() condition, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  late Directory root;
  var metered = false;

  Future<ProviderContainer> startApp(WidgetTester tester) async {
    await windowManager.ensureInitialized();
    root = Directory.systemTemp.createTempSync('jellyflex_downloads_extra_');
    metered = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings()),
          downloadsProvider.overrideWith(() => DownloadManager(root, () async => metered)),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    return ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.runAsync(() => _call('POST', '/debug/throttle?bps=0'));
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, const Duration(milliseconds: 500));
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  }

  testWidgets('Windows meldet die Art der Verbindung', (tester) async {
    final cost = await const MethodChannel('jellyflex/shell').invokeMethod<String>('connectionCost');
    debugPrint('Verbindung laut Windows: $cost');
    expect(cost, isIn(['unrestricted', 'metered', 'none', 'unknown']));
  });

  testWidgets('Nur über WLAN/LAN und Geschwindigkeitsgrenze', (tester) async {
    if (!await demoServerRunning()) return;
    final container = await startApp(tester);
    try {
      final manager = container.read(downloadsProvider.notifier);
      final settings = container.read(settingsProvider.notifier);
      final movie = (await tester.runAsync(() => container.read(apiProvider).getItem('movie3')))!;

      // Getaktete Verbindung: Download wartet.
      metered = true;
      await manager.enqueue(movie);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(manager.entryFor('movie3')!.status, DownloadStatus.queued);
      expect(manager.entryFor('movie3')!.received, 0);
      expect(manager.waitingForUnmetered.value, isTrue);

      // Mit Grenze 1 MB/s weiter, sobald WLAN da ist.
      settings.update((s) => s.copyWith(downloadSpeedLimit: 1000000));
      metered = false;
      manager.recheckNetwork();
      expect(await _waitFor(tester, () => manager.entryFor('movie3')!.received > 0), isTrue);
      expect(manager.waitingForUnmetered.value, isFalse);
      final start = manager.entryFor('movie3')!.received;
      final watch = Stopwatch()..start();
      await pumpFor(tester, const Duration(seconds: 3));
      final rate = (manager.entryFor('movie3')!.received - start) / watch.elapsedMilliseconds * 1000;
      debugPrint('Geschwindigkeit mit Grenze: ${(rate / 1000000).toStringAsFixed(2)} MB/s');
      expect(rate, lessThan(1600000), reason: 'Grenze von 1 MB/s eingehalten');
      expect(rate, greaterThan(300000), reason: 'Download läuft weiter');

      // Mitten im Download getaktet: hält an und wartet.
      metered = true;
      manager.recheckNetwork();
      await pumpFor(tester, const Duration(seconds: 1));
      final paused = manager.entryFor('movie3')!;
      expect(paused.status, DownloadStatus.queued);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(manager.entryFor('movie3')!.received, paused.received, reason: 'Kein Weiterladen über mobile Daten');

      // Grenze aufheben, WLAN zurück → wird fertig (fortgesetzt per Range).
      settings.update((s) => s.copyWith(downloadSpeedLimit: 0));
      metered = false;
      manager.recheckNetwork();
      expect(await _waitFor(tester, () => manager.entryFor('movie3')!.isDone), isTrue);
      expect(File(manager.entryFor('movie3')!.mediaFile!).lengthSync(), 41482147);
      await tester.runAsync(() => manager.remove('movie3'));
    } finally {
      await cleanUp(tester);
    }
  });

  testWidgets('Detailseite: Ordner-Frage, Optionen, Abbrechen', (tester) async {
    if (!await demoServerRunning()) return;
    final container = await startApp(tester);
    try {
      await tester.runAsync(() => _call('POST', '/debug/throttle?bps=500000'));
      final manager = container.read(downloadsProvider.notifier);
      container.read(routerProvider).push('/item/movie5');
      await pumpFor(tester, const Duration(seconds: 2));

      await tester.tap(find.byTooltip('Herunterladen (offline ansehen)'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      // Beim ersten Mal: Ordner bestätigen.
      expect(find.text('Wohin sollen die Downloads?'), findsOneWidget);
      expect(find.text(root.path), findsOneWidget);
      await tester.tap(find.text('Diesen Ordner nehmen'));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(container.read(settingsProvider).downloadFolderAsked, isTrue);

      // Optionen: kleinere Fassung → Tonspur wählbar.
      expect(find.text('Englisch'), findsNothing, reason: 'Original: keine Tonspur-Auswahl');
      await tester.tap(find.text('3 Mbit/s · 720p'));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Englisch'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await saveShot(tester, 'download_options');
      await tester.tap(find.widgetWithText(FilledButton, 'Herunterladen'));
      await pumpFor(tester, const Duration(seconds: 1));
      final entry = manager.entryFor('movie5')!;
      expect(entry.maxBitrate, 3000000);
      expect(entry.audioLanguage, 'eng');

      // Abbrechen direkt auf der Detailseite.
      await tester.tap(find.byTooltip('Download abbrechen'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('Download abbrechen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Download abbrechen'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(manager.entryFor('movie5'), isNull);
      expect(find.byTooltip('Herunterladen (offline ansehen)'), findsOneWidget);
    } finally {
      await cleanUp(tester);
    }
  });

  testWidgets('Kleinere Fassung mit gewählter Tonspur', (tester) async {
    if (!await demoServerRunning()) return;
    final container = await startApp(tester);
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    try {
      final manager = container.read(downloadsProvider.notifier);
      final movie = (await tester.runAsync(() => container.read(apiProvider).getItem('movie0')))!;
      await manager.enqueue(
        movie,
        mediaSourceId: 'movie0-hd',
        options: const DownloadOptions(maxBitrate: 3000000, audioLanguage: 'eng'),
      );
      expect(await _waitFor(tester, () => manager.entryFor('movie0')?.isDone ?? false), isTrue);
      final entry = manager.entryFor('movie0')!;
      expect(entry.converted, isTrue);
      expect(entry.audioIndex, 2, reason: 'Englische Tonspur');
      expect(entry.mediaFile, endsWith('media.mkv'));
      expect(entry.subtitleFile(3), isNotNull, reason: 'Untertitel als Datei');

      final stream = jsonDecode((await tester.runAsync(() => _call('GET', '/debug/laststream')))!) as Map;
      debugPrint('Angefragt: $stream');
      expect(stream['path'], 'stream.mkv');
      expect(stream['static'], 'false');
      expect(stream['mediaSourceId'], 'movie0-hd');
      expect(stream['audioStreamIndex'], '2');
      expect(stream['maxHeight'], '720');
      expect(int.parse(stream['videoBitRate'] as String), lessThanOrEqualTo(3000000));

      // Die kleinere Fassung spielt lokal.
      container.read(routerProvider).push('/play/movie0');
      expect(await _waitFor(tester, () => (player?.state.duration ?? Duration.zero) > Duration.zero), isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(PlayerScreen), findsOneWidget);
      container.read(routerProvider).pop();
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.runAsync(() => manager.remove('movie0'));
    } finally {
      PlayerScreen.debugBeforeOpen = null;
      await cleanUp(tester);
    }
  });

  testWidgets('Smart Downloads: nächste Folgen laden, gesehene löschen, Platzgrenze', (tester) async {
    if (!await demoServerRunning()) return;
    final ids = [
      for (final s in [1, 2])
        for (var e = 1; e <= 8; e++) 'series3_s${s}_e$e',
    ];
    final saved = (await tester.runAsync(() => saveUserData(ids)))!;
    Future<void> setPlayed(String id, bool played) async {
      final data = jsonDecode(saved[id]!) as Map<String, dynamic>;
      await _call('PUT', '/debug/userdata/$id', jsonEncode({...data, 'Played': played, 'PlaybackPositionTicks': 0}));
    }

    final container = await startApp(tester);
    try {
      await tester.runAsync(() async {
        for (final id in ids) {
          await setPlayed(id, false);
        }
      });
      final manager = container.read(downloadsProvider.notifier);
      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(smartDownloads: true, smartEpisodes: 2, smartMaxGb: 0));

      // Folge 1 laden und auf dem Server als gesehen markieren.
      final first = (await tester.runAsync(() => container.read(apiProvider).getItem(ids[0])))!;
      await manager.enqueue(first);
      expect(await _waitFor(tester, () => manager.entryFor(ids[0])?.isDone ?? false), isTrue);
      await tester.runAsync(() => setPlayed(ids[0], true));
      await tester.runAsync(manager.runSmart);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(manager.entryFor(ids[0]), isNull, reason: 'Gesehene Folge gelöscht');
      expect(manager.entryFor(ids[1])?.auto, isTrue, reason: 'Folge 2 automatisch geladen');
      expect(manager.entryFor(ids[2])?.auto, isTrue, reason: 'Folge 3 automatisch geladen');
      expect(manager.entryFor(ids[3]), isNull, reason: 'Nur zwei Folgen bereithalten');
      expect(
        await _waitFor(tester, () => [ids[1], ids[2]].every((id) => manager.entryFor(id)?.isDone ?? false)),
        isTrue,
      );

      // Folge 2 offline zu Ende geschaut (lokal gesehen) → Folge 4 kommt dazu, Folge 2 geht.
      final runtime = manager.entryFor(ids[1])!.loadItem()!.runTimeTicks!;
      manager.savePlayback(ids[1], positionTicks: runtime, runtimeTicks: runtime, synced: true);
      expect(
        await _waitFor(tester, () => manager.entryFor(ids[3]) != null && manager.entryFor(ids[1]) == null),
        isTrue,
        reason: 'Nach dem Ansehen: nächste Folge geladen, gesehene gelöscht',
      );
      expect(await _waitFor(tester, () => manager.entryFor(ids[3])?.isDone ?? false), isTrue);

      // Platzgrenze: 1 GB reicht für keine weitere Folge (je ~4 GB laut Server).
      container.read(settingsProvider.notifier).update((s) => s.copyWith(smartMaxGb: 1));
      final runtime3 = manager.entryFor(ids[2])!.loadItem()!.runTimeTicks!;
      manager.savePlayback(ids[2], positionTicks: runtime3, runtimeTicks: runtime3, synced: true);
      expect(await _waitFor(tester, () => manager.entryFor(ids[2]) == null), isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(manager.entryFor(ids[4]), isNull, reason: 'Speichergrenze verhindert weitere Downloads');

      for (final e in [...container.read(myDownloadsProvider)]) {
        await tester.runAsync(() => manager.remove(e.itemId));
      }
    } finally {
      await tester.runAsync(() => restoreUserData(saved));
      await cleanUp(tester);
    }
  });
}
