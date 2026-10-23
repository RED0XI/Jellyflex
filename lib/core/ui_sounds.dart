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

/// Spielt Klänge über die Windows-eigene Funktion `PlaySound` direkt aus dem
/// Speicher ab – ohne zusätzliche Bibliothek und praktisch ohne Verzögerung.
/// Ein neuer Klang beendet den vorherigen (für kurze Klicks genau richtig).
abstract final class UiSounds {
  /// Aus den Einstellungen ("Klänge").
  static bool enabled = true;

  static const _async = 0x0001;
  static const _noDefault = 0x0002;
  static const _memory = 0x0004;

  static final _loaded = <UiSound, Pointer<Uint8>>{};
  static _PlaySoundDart? _playSound;
  static bool _initialized = false;

  /// Klänge vorab laden (einmal beim Start), damit der erste Klick nicht hängt.
  static Future<void> preload() async {
    if (_initialized || !Platform.isWindows) return;
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

  /// Spielt [sound]; `true`, wenn Windows den Klang angenommen hat.
  static bool play(UiSound sound) {
    if (!enabled) return false;
    final buffer = _loaded[sound];
    final playSound = _playSound;
    if (buffer == null || playSound == null) return false;
    return playSound(buffer.cast(), 0, _async | _memory | _noDefault) != 0;
  }

  /// Für Tests: wie viele Klänge geladen sind.
  @visibleForTesting
  static int get loadedCount => _loaded.length;
}
