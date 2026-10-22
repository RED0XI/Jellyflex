// Test-Player ohne Jellyfin-Server – nur für die Entwicklung.
//
// Start:  flutter run -d windows -t lib/dev/player_harness.dart
//
// Spielt ein lokales Testvideo mit zwei Tonspuren und zwei Untertiteln ab,
// um Spurwahl, Intro-Button, Vollbild usw. zu prüfen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import '../core/jellyfin_api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/settings.dart';
import '../features/player/player_screen.dart';
import '../theme.dart';
import '../widgets/window_frame.dart';

/// Angefragte Bitraten bei simulierter Umrechnung (für Tests).
final harnessTranscodeRequests = <int>[];

String get _testVideo =>
    Platform.environment['JELLYFLEX_TEST_VIDEO'] ?? '${Directory.systemTemp.path}\\jellyflex_test.mkv';

class _FakeApi extends JellyfinApi {
  // Leere baseUrl: so wird die "umgerechnete" Adresse direkt zum Dateipfad.
  _FakeApi() : super(baseUrl: '', deviceId: 'harness', token: 't', userId: 'u');

  static final _source = {
    'Id': 'src',
    'DefaultAudioStreamIndex': 1,
    'DefaultSubtitleStreamIndex': -1,
    'MediaStreams': [
      {'Type': 'Video', 'Index': 0},
      {'Type': 'Audio', 'Index': 1, 'Language': 'ger', 'DisplayTitle': 'Deutsch - AAC - Stereo - Standard'},
      {'Type': 'Audio', 'Index': 2, 'Language': 'eng', 'DisplayTitle': 'Englisch - AAC - Stereo'},
      {'Type': 'Subtitle', 'Index': 3, 'Language': 'ger', 'DisplayTitle': 'Deutsch - SRT'},
      {'Type': 'Subtitle', 'Index': 4, 'Language': 'eng', 'DisplayTitle': 'Englisch - SRT'},
    ],
  };

  @override
  Future<PlaybackInfo> getTranscodeInfo(
    String id, {
    required String mediaSourceId,
    required int maxBitrate,
    int? audioIndex,
    int? subtitleIndex,
  }) async {
    harnessTranscodeRequests.add(maxBitrate);
    return PlaybackInfo({
      'PlaySessionId': 'transcode',
      'MediaSources': [
        {..._source, 'TranscodingUrl': _testVideo},
      ],
    });
  }

  @override
  Future<BaseItem> getItem(String id) async => BaseItem({
    'Id': id,
    'Name': 'Testfolge',
    'Type': 'Episode',
    'SeriesName': 'Test-Serie',
    'IndexNumber': 1,
    'ParentIndexNumber': 1,
    'MediaSources': [_source],
    'Chapters': [
      {'StartPositionTicks': 0, 'Name': 'Anfang'},
      {'StartPositionTicks': 300000000, 'Name': 'Die Mitte'},
      {'StartPositionTicks': 800000000, 'Name': 'Das Ende'},
    ],
  });

  @override
  Future<PlaybackInfo> getPlaybackInfo(String id) async => PlaybackInfo({
    'PlaySessionId': 'p',
    'MediaSources': [_source],
  });

  @override
  String streamUrl(String itemId, {required String mediaSourceId, String? playSessionId}) => _testVideo;

  @override
  Future<List<MediaSegment>> getMediaSegments(String itemId) async => [
    MediaSegment({'Type': 'Intro', 'StartTicks': 30000000, 'EndTicks': 250000000}),
  ];

  @override
  Future<BaseItem?> getNextEpisode(BaseItem episode) async => null;

  @override
  Future<void> reportPlaybackStart(Json body) async {}
  @override
  Future<void> reportPlaybackProgress(Json body) async {}
  @override
  Future<void> reportPlaybackStopped(Json body) async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1280, 800), center: true, titleBarStyle: TitleBarStyle.hidden),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  await prepareHarness();
  runApp(buildHarnessApp());
}

/// Testvideo: %TEMP%\jellyflex_test.mkv (oder JELLYFLEX_TEST_VIDEO) mit zwei
/// Tonspuren (de, en) und zwei Untertiteln (de, en), z. B. per ffmpeg erzeugt.
/// [onPlayer] bekommt den Player (für Tests, die seinen Zustand prüfen wollen).
Future<void> prepareHarness({void Function(Player player)? onPlayer}) async {
  MediaKit.ensureInitialized();
  PlayerScreen.debugBeforeOpen = (player) async => onPlayer?.call(player);
}

/// [settings]: feste App-Einstellungen für den Test (werden in eine Temp-Datei geschrieben).
Widget buildHarnessApp({AppSettings? settings}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(onPressed: () => context.push('/play/test'), child: const Text('Test-Player öffnen')),
          ),
        ),
      ),
      GoRoute(
        path: '/play/:id',
        builder: (_, s) => PlayerScreen(itemId: s.pathParameters['id']!),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(_FakeApi()),
      if (settings != null)
        settingsProvider.overrideWith(() {
          final file = File('${Directory.systemTemp.createTempSync('jellyflex_settings').path}\\settings.json')
            ..writeAsStringSync(jsonEncode(settings.toJson()));
          return SettingsController(file);
        }),
    ],
    child: MaterialApp.router(
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => WindowFrame(router: router, child: child!),
    ),
  );
}
