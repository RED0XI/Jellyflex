import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/jellyfin_api.dart';
import '../../core/models.dart';

/// Wie Apples Player übernehmen soll.
enum AppleHandoff {
  /// Sofort ins Bild-in-Bild-Fenster – in Jellyflex lässt sich weiterstöbern.
  pictureInPicture('pip'),

  /// Apples Vollbild-Player mit AirPlay-Knopf (Fernseher, Apple TV).
  airPlay('airplay');

  const AppleHandoff(this.mode);

  final String mode;
}

/// Apples eigener Player auf iPhone/iPad (Gegenstück: ios/Runner/ApplePlayer.swift).
///
/// mpv zeichnet in eine Flutter-Textur, daraus macht iOS kein Bild-in-Bild und kein AirPlay-Video.
/// Für beides übernimmt Apples Player den Titel an derselben Stelle als HLS-Stream vom Server –
/// mit eigener Wiedergabe-Sitzung, deren Fortschritt hier an Jellyfin geht. Tippt man im
/// Bild-in-Bild-Fenster auf "zurück" (bzw. schließt Apples Vollbild), geht es im Jellyflex-Player
/// an derselben Stelle weiter.
abstract final class ApplePlayer {
  static const _channel = MethodChannel('jellyflex/apple_player');
  static _Session? _session;

  /// Übernimmt Apples Player gerade?
  static bool get active => _session != null;

  /// Übergibt [item] ab [position]. `false`: ging nicht (kein Stream, kein Bild-in-Bild …) –
  /// dann läuft der Jellyflex-Player einfach weiter.
  static Future<bool> open({
    required JellyfinApi api,
    required GoRouter router,
    required BaseItem item,
    required String mediaSourceId,
    required Duration position,
    required AppleHandoff handoff,
    int? audioIndex,
    int? subtitleIndex,
    int? maxBitrate,
  }) async {
    try {
      final info = await api.getApplePlaybackInfo(
        item.id,
        mediaSourceId: mediaSourceId,
        audioIndex: audioIndex,
        subtitleIndex: subtitleIndex,
        maxBitrate: maxBitrate ?? 120000000,
      );
      final source = info.mediaSources.firstOrNull;
      final relative = source?.transcodingUrl;
      if (source == null || relative == null) return false;
      final session = _Session(
        api: api,
        router: router,
        itemId: item.id,
        mediaSourceId: source.id,
        playSessionId: info.playSessionId,
        audioIndex: audioIndex,
        subtitleIndex: subtitleIndex,
      );
      _channel.setMethodCallHandler(_onCall);
      final ok =
          await _channel.invokeMethod<bool>('open', {
            'url': api.onServer(relative),
            'headers': {'Authorization': api.authorizationHeader},
            'position': position.inMilliseconds / 1000,
            'mode': handoff.mode,
          }) ??
          false;
      if (!ok) return false;
      _session = session;
      api.reportPlaybackStart(session.body(position)).ignore();
      return true;
    } catch (e) {
      debugPrint('Apples Player nicht gestartet: $e');
      return false;
    }
  }

  static Future<void> _onCall(MethodCall call) async {
    final session = _session;
    if (session == null) return;
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
    final position = Duration(milliseconds: (((args['position'] as num?) ?? 0) * 1000).round());
    switch (call.method) {
      case 'progress':
        session.api.reportPlaybackProgress(session.body(position, paused: args['paused'] == true)).ignore();
      case 'restore':
        _session = null;
        session.api.reportPlaybackStopped(session.body(position)).ignore();
        session.router.push('/play/${session.itemId}?start=${durationToTicks(position)}');
      case 'ended':
        _session = null;
        session.api.reportPlaybackStopped(session.body(position)).ignore();
    }
  }
}

class _Session {
  _Session({
    required this.api,
    required this.router,
    required this.itemId,
    required this.mediaSourceId,
    required this.playSessionId,
    required this.audioIndex,
    required this.subtitleIndex,
  });

  final JellyfinApi api;
  final GoRouter router;
  final String itemId;
  final String mediaSourceId;
  final String? playSessionId;
  final int? audioIndex;
  final int? subtitleIndex;

  Json body(Duration position, {bool paused = false}) => {
    'ItemId': itemId,
    'MediaSourceId': mediaSourceId,
    'PlaySessionId': ?playSessionId,
    'PositionTicks': durationToTicks(position),
    'IsPaused': paused,
    'PlayMethod': 'Transcode',
    'AudioStreamIndex': ?audioIndex,
    'SubtitleStreamIndex': ?subtitleIndex,
    'CanSeek': true,
  };
}
