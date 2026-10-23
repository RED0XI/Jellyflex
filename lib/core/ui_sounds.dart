import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kleine Oberflächen-Klänge (Glücksrad, Quiz). Die WAV-Dateien erzeugt
/// `tool/generate_sounds.dart`.
enum UiSound {
  tick('tick'),
  win('win'),
  correct('correct'),
  wrong('wrong');

  const UiSound(this.file);

  final String file;
}

typedef _PlaySoundC = Int32 Function(Pointer<Void> sound, IntPtr module, Uint32 flags);
typedef _PlaySoundDart = int Function(Pointer<Void> sound, int module, int flags);

/// Spielt Klänge direkt aus dem Speicher ab – ohne zusätzliche Bibliothek und
/// praktisch ohne Verzögerung: unter Windows über `PlaySound`, unter macOS über
/// `NSSound` (macos/Runner/AppShell.swift). Ein neuer Klang beendet den vorherigen
/// (für kurze Klicks genau richtig).
abstract final class UiSounds {
  /// Aus den Einstellungen ("Klänge").
  static bool enabled = true;

  static const _async = 0x0001;
  static const _noDefault = 0x0002;
  static const _memory = 0x0004;

  static final _loaded = <UiSound, Pointer<Uint8>>{};
  static final _macLoaded = <UiSound>{};
  static const _shell = MethodChannel('jellyflex/shell');
  static _PlaySoundDart? _playSound;
  static bool _initialized = false;

  /// Klänge vorab laden (einmal beim Start), damit der erste Klick nicht hängt.
  static Future<void> preload() async {
    if (_initialized) return;
    if (Platform.isMacOS) return _preloadMac();
    if (!Platform.isWindows) return;
    _initialized = true;
    try {
      _playSound = DynamicLibrary.open('winmm.dll').lookupFunction<_PlaySoundC, _PlaySoundDart>('PlaySoundW');
      for (final sound in UiSound.values) {
        final data = await rootBundle.load('assets/sounds/${sound.file}.wav');
        // Bleibt für die ganze Laufzeit bestehen – Windows liest direkt daraus.
        final buffer = malloc<Uint8>(data.lengthInBytes);
        buffer
            .asTypedList(data.lengthInBytes)
            .setAll(0, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        _loaded[sound] = buffer;
      }
    } catch (e) {
      debugPrint('Klänge nicht verfügbar: $e');
    }
  }

  static Future<void> _preloadMac() async {
    _initialized = true;
    try {
      for (final sound in UiSound.values) {
        final data = await rootBundle.load('assets/sounds/${sound.file}.wav');
        final ok = await _shell.invokeMethod<bool>('loadSound', {
          'name': sound.file,
          'data': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        });
        if (ok == true) _macLoaded.add(sound);
      }
    } on MissingPluginException {
      // Ohne macOS-Runner (z. B. in Tests) keine Klänge.
    } catch (e) {
      debugPrint('Klänge nicht verfügbar: $e');
    }
  }

  /// Spielt [sound]; `true`, wenn das System den Klang angenommen hat.
  static bool play(UiSound sound) {
    if (!enabled) return false;
    if (Platform.isMacOS) {
      if (!_macLoaded.contains(sound)) return false;
      _shell.invokeMethod<void>('playSound', sound.file).catchError((_) {});
      return true;
    }
    final buffer = _loaded[sound];
    final playSound = _playSound;
    if (buffer == null || playSound == null) return false;
    return playSound(buffer.cast(), 0, _async | _memory | _noDefault) != 0;
  }

  /// Für Tests: wie viele Klänge geladen sind.
  @visibleForTesting
  static int get loadedCount => Platform.isMacOS ? _macLoaded.length : _loaded.length;
}
