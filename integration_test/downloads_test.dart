// Prüft Downloads gegen den Demo-Server: Herunterladen, Pausieren/Fortsetzen,
// Löschen während des Ladens, Abspielen ohne Server und das spätere Nachmelden
// des offline geschauten Fortschritts.
//
// Voraussetzung:  dart run tool/mock_server.dart   (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/downloads_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

Future<String> _call(String method, String path) async {
  final client = HttpClient();
  final req = await client.openUrl(method, Uri.parse('$demoServer$path'));
  final res = await req.close();
  final body = await utf8.decoder.bind(res).join();
  client.close();
  return body;
}

/// Wartet (höchstens [timeout]), bis [condition] erfüllt ist.
Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Downloads: laden, pausieren, löschen, offline schauen, nachmelden', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    final video = File('${Directory.systemTemp.path}${Platform.pathSeparator}jellyflex_test.mkv');
    if (!video.existsSync()) {
      markTestSkipped('Testvideo fehlt');
      return;
    }
    await windowManager.ensureInitialized();
    final root = Directory.systemTemp.createTempSync('jellyflex_downloads_');
    Player? player;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;

    try {
      // Langsam ausliefern (~8 MB/s), damit man Pause und Fortschritt sieht.
      await tester.runAsync(() => _call('POST', '/debug/throttle?bps=8000000'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(testSettings),
            downloadsProvider.overrideWith(() => DownloadManager(root, () async => false)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final manager = container.read(downloadsProvider.notifier);
      DownloadEntry entry(String id) => manager.entryFor(id)!;

      final movie = await tester.runAsync(() => container.read(apiProvider).getItem('movie0'));
      final other = await tester.runAsync(() => container.read(apiProvider).getItem('movie2'));

      // --- Herunterladen + Pausieren ---
      // 1080p-Fassung: die 4K-Fassung ist laut Demo-Server 61 GB groß – mehr, als
      // auf manchem Testrechner frei ist (die Platzprüfung würde sie ablehnen).
      await manager.enqueue(movie!, mediaSourceId: 'movie0-hd');
      expect(
        await _waitFor(tester, () => entry('movie0').received > 3000000),
        isTrue,
        reason: 'Download sollte starten',
      );
      manager.pause('movie0');
      await pumpFor(tester, const Duration(milliseconds: 800));
      final part = File('${entry('movie0').folder}${Platform.pathSeparator}media.mkv.part');
      final pausedSize = part.lengthSync();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(entry('movie0').status, DownloadStatus.paused);
      expect(part.lengthSync(), pausedSize, reason: 'Nach Pause wächst die Datei nicht weiter');
      expect(pausedSize, lessThan(video.lengthSync()));

      // --- Fortsetzen (HTTP-Range) bis fertig ---
      manager.resume('movie0');
      expect(await _waitFor(tester, () => entry('movie0').isDone), isTrue, reason: 'Download sollte fertig werden');
      final done = entry('movie0');
      expect(File(done.mediaFile!).lengthSync(), video.lengthSync(), reason: 'Datei vollständig und unbeschädigt');
      expect(File(done.posterPath).existsSync(), isTrue);
      expect(done.subtitleFile(3), isNotNull, reason: 'Externer Untertitel mitgeladen');

      // --- Löschen, während der Download läuft ---
      await manager.enqueue(other!);
      expect(await _waitFor(tester, () => (manager.entryFor('movie2')?.received ?? 0) > 1000000), isTrue);
      final otherFolder = Directory(entry('movie2').folder);
      await tester.runAsync(() => manager.remove('movie2'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(manager.entryFor('movie2'), isNull);
      expect(otherFolder.existsSync(), isFalse, reason: 'Ordner samt Teildatei gelöscht');

      // --- Downloads-Seite ---
      container.read(routerProvider).push('/downloads');
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Bereit zum Offline-Schauen'), findsOneWidget);

      // --- Offline abspielen ---
      await tester.runAsync(() => _call('POST', '/debug/offline?on=1'));
      container.read(routerProvider).push('/play/movie0');
      expect(
        await _waitFor(tester, () => (player?.state.duration ?? Duration.zero) > Duration.zero),
        isTrue,
        reason: 'Lokale Datei spielt auch ohne Server',
      );
      expect(find.textContaining('konnte nicht'), findsNothing);
      await tester.runAsync(() => player!.seek(const Duration(seconds: 60)));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(await _waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty), isTrue);
      final watched = entry('movie0');
      debugPrint('Offline gemerkt: ${watched.positionTicks} Ticks, nachmelden: ${watched.needsSync}');
      expect(watched.needsSync, isTrue);
      expect(ticksToDuration(watched.positionTicks).inSeconds, inInclusiveRange(55, 70));

      // Offline zeigt die Detailseite den lokalen Fortschritt.
      expect(watched.loadItem()!.userData.playbackPositionTicks, watched.positionTicks);

      // --- Wieder online: Fortschritt nachmelden ---
      await tester.runAsync(() => _call('POST', '/debug/offline?on=0'));
      await tester.runAsync(manager.syncPending);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(entry('movie0').needsSync, isFalse);
      final serverData = jsonDecode((await tester.runAsync(() => _call('GET', '/debug/userdata/movie0')))!) as Map;
      expect(serverData['PlaybackPositionTicks'], watched.positionTicks, reason: 'Server kennt jetzt die Stelle');

      // Index wurde gespeichert (Neustart der App findet die Downloads wieder).
      await pumpFor(tester, const Duration(seconds: 1));
      final index =
          (jsonDecode(File('${root.path}${Platform.pathSeparator}downloads.json').readAsStringSync()) as Map)['entries']
              as List;
      expect(index.length, 1);

      // --- Bildschirmfoto: ein laufender und ein fertiger (angeschauter) Download ---
      await manager.enqueue(other);
      await _waitFor(tester, () => (manager.entryFor('movie2')?.received ?? 0) > 2000000);
      await pumpFor(tester, const Duration(milliseconds: 600));
      await saveShot(tester, 'downloads');
      await tester.runAsync(() => manager.remove('movie2'));
    } finally {
      await tester.runAsync(() => _call('POST', '/debug/offline?on=0'));
      await tester.runAsync(() => _call('POST', '/debug/throttle?bps=0'));
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, const Duration(milliseconds: 500));
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
