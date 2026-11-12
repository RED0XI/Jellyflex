import 'package:flutter/services.dart';

/// Medienanzeige (Windows: Lautstärke-Overlay, macOS/iOS: „Jetzt läuft“, Sperrbildschirm) und
/// Medientasten.
///
/// Gegenstücke: windows/runner/media_session.cpp, macos/Runner/MediaSession.swift.
abstract final class MediaSession {
  static const _channel = MethodChannel('jellyflex/media_session');
  static bool _initialized = false;

  /// Wird bei Medientasten aufgerufen: "play", "pause", "stop", "next", "previous",
  /// "skipForward", "skipBackward" oder `seek:<Sekunden>` (Ziehen an der Leiste).
  static void Function(String button)? onButton;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'button' && call.arguments is String) {
        onButton?.call(call.arguments as String);
      }
    });
  }

  static Future<void> update({
    required String title,
    String? subtitle,
    String? artUrl,
    required bool playing,
    bool canNext = false,
    int skipBack = 10,
    int skipForward = 10,
  }) => _invoke('update', {
    'skipBack': skipBack,
    'skipForward': skipForward,
    'title': title,
    'subtitle': subtitle ?? '',
    'artUrl': artUrl ?? '',
    'playing': playing,
    'canNext': canNext,
  });

  /// Vor dem Öffnen eines Videos (iOS: Audio-Sitzung aktivieren, damit der Player Ton ausgeben
  /// und im Hintergrund weiterlaufen darf).
  static Future<void> prepare() => _invoke('prepare');

  static Future<void> setPlaying(bool playing) => _invoke('setPlaying', playing);

  /// Position, Länge und Tempo – die Anzeige zählt von hier aus selbst weiter, es reicht also
  /// ein Aufruf bei Start, Pause, Sprung und Tempowechsel.
  static Future<void> setProgress({required Duration position, required Duration duration, double rate = 1}) => _invoke(
    'progress',
    {'position': position.inMilliseconds / 1000, 'duration': duration.inMilliseconds / 1000, 'rate': rate},
  );

  /// Anzeige entfernen. [keepAudio]: die Audio-Sitzung offen lassen (iOS: Apples Player
  /// übernimmt gerade und spielt weiter).
  static Future<void> clear({bool keepAudio = false}) => _invoke('clear', keepAudio);

  static Future<void> _invoke(String method, [Object? args]) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {
      // Nicht verfügbar (z. B. in Tests) – ohne Medienanzeige weitermachen.
    }
  }
}
