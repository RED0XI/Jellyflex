import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_paths.dart';

/// Auf welchem Gerät die App läuft: Desktop (Windows, macOS) mit Fenster, Maus und
/// eigener Titelleiste – oder Android (Fernseher wie Fire TV, später Tablet/Handy).
abstract final class PlatformInfo {
  static const _channel = MethodChannel('jellyflex/platform');

  /// Fernseher (Android TV, Google TV, Fire TV): Bedienung nur mit der Fernbedienung.
  static bool isTv = false;

  /// Vor dem Start der App einmal aufrufen: holt unter Android die App-Ordner und
  /// erkennt Fernseher.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final paths = await _channel.invokeMapMethod<String, String>('paths');
      if (paths != null) AppPaths.androidPaths = paths;
      isTv = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (e) {
      debugPrint('Android-Plattformdaten nicht verfügbar: $e');
    }
  }
}
