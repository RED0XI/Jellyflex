import 'package:flutter/services.dart';

/// Medienanzeige (Windows: Lautstärke-Overlay, macOS: „Jetzt läuft“) und Medientasten.
///
/// Gegenstücke: windows/runner/media_session.cpp, macos/Runner/MediaSession.swift.
abstract final class MediaSession {
  static const _channel = MethodChannel('jellyflex/media_session');
  static bool _initialized = false;

  /// Wird bei Medientasten aufgerufen: "play", "pause", "stop", "next", "previous".
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
  }) => _invoke('update', {
    'title': title,
    'subtitle': subtitle ?? '',
    'artUrl': artUrl ?? '',
    'playing': playing,
    'canNext': canNext,
  });

  static Future<void> setPlaying(bool playing) => _invoke('setPlaying', playing);

  static Future<void> clear() => _invoke('clear');

  static Future<void> _invoke(String method, [Object? args]) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {
      // Nicht verfügbar (z. B. in Tests) – ohne Medienanzeige weitermachen.
    }
  }
}
