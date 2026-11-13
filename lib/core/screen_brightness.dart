import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bildschirmhelligkeit für Wischgesten im Player (Gegenstücke: ios/Runner/AppShell.swift,
/// android/.../MainActivity.kt, Kanal `jellyflex/shell`).
///
/// Die Helligkeit vor der ersten Änderung wird gemerkt und mit [restore] wiederhergestellt – auf
/// dem iPhone gilt sie sonst systemweit weiter.
abstract final class ScreenBrightness {
  static const _channel = MethodChannel('jellyflex/shell');

  /// Wert vor der ersten Änderung (`null` = noch nichts geändert; Android: -1 = Systemwert).
  static double? _original;

  /// Aktuelle Helligkeit 0…1 (`null`, wenn das Gerät sie nicht verrät; Android ohne eigenen Wert:
  /// -1 → 0.5 als Startpunkt).
  static Future<double?> get() async {
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      if (value == null) return null;
      return value < 0 ? 0.5 : value;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Helligkeit nicht lesbar: $e');
      return null;
    }
  }

  static Future<void> set(double value) async {
    try {
      _original ??= await _channel.invokeMethod<double>('getBrightness');
      await _channel.invokeMethod('setBrightness', value.clamp(0.0, 1.0));
    } on MissingPluginException {
      // Desktop/Tests: keine Helligkeit.
    } catch (e) {
      debugPrint('Helligkeit nicht gesetzt: $e');
    }
  }

  /// Zurück auf den Wert vor dem Player.
  static Future<void> restore() async {
    final original = _original;
    if (original == null) return;
    _original = null;
    try {
      await _channel.invokeMethod('setBrightness', original);
    } catch (_) {}
  }
}
