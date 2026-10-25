// Erzeugt die kleinen Oberflächen-Klänge der App als WAV-Dateien (synthetisch,
// keine fremden Aufnahmen – daher frei verwendbar und winzig).
//
// Start:  dart run tool/generate_sounds.dart
// Ergebnis: assets/sounds/*.wav

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 22050;

/// Ein Ton: Frequenz, Start, Dauer, Lautstärke; klingt glockenartig aus.
class _Note {
  const _Note(this.freq, this.start, this.length, {this.volume = 0.5, this.decay = 6});

  final double freq;
  final double start;
  final double length;
  final double volume;
  final double decay;
}

Float64List _render(List<_Note> notes, double seconds, {double noise = 0, double noiseLength = 0}) {
  final n = (seconds * _rate).round();
  final out = Float64List(n);
  final random = math.Random(42);
  for (final note in notes) {
    final from = (note.start * _rate).round();
    final len = (note.length * _rate).round();
    for (var i = 0; i < len && from + i < n; i++) {
      final t = i / _rate;
      // Kurzes Einblenden gegen Knackser, dann exponentielles Ausklingen.
      final attack = math.min(1.0, t / 0.004);
      final env = attack * math.exp(-note.decay * t);
      // Grundton + leise Obertöne = weicher, glockiger Klang.
      final s =
          math.sin(2 * math.pi * note.freq * t) +
          0.35 * math.sin(2 * math.pi * note.freq * 2 * t) +
          0.12 * math.sin(2 * math.pi * note.freq * 3 * t);
      out[from + i] += note.volume * env * s / 1.47;
    }
  }
  // Optional ein kurzes Rauschen (Klick-Anteil).
  final noiseSamples = (noiseLength * _rate).round();
  for (var i = 0; i < noiseSamples && i < n; i++) {
    out[i] += noise * (random.nextDouble() * 2 - 1) * math.exp(-i / (noiseSamples / 4));
  }
  return out;
}

Uint8List _wav(Float64List samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  final header = ByteData(44)
    ..setUint32(0, 0x52494646, Endian.big) // "RIFF"
    ..setUint32(4, 36 + data.lengthInBytes, Endian.little)
    ..setUint32(8, 0x57415645, Endian.big) // "WAVE"
    ..setUint32(12, 0x666d7420, Endian.big) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // Mono
    ..setUint32(24, _rate, Endian.little)
    ..setUint32(28, _rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461, Endian.big) // "data"
    ..setUint32(40, data.lengthInBytes, Endian.little);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(data.buffer.asUint8List()))
      .toBytes();
}

void main() {
  final sounds = <String, Float64List>{
    // Rad: kurzes, helles Holz-Klicken.
    'tick': _render([const _Note(1900, 0, 0.04, volume: 0.32, decay: 90)], 0.04, noise: 0.12, noiseLength: 0.006),
    // Rad bleibt stehen: kleines Dur-Arpeggio (C – E – G – C).
    'win': _render([
      const _Note(523.25, 0.00, 0.9, volume: 0.32, decay: 4),
      const _Note(659.25, 0.09, 0.9, volume: 0.32, decay: 4),
      const _Note(783.99, 0.18, 0.9, volume: 0.32, decay: 4),
      const _Note(1046.5, 0.27, 1.1, volume: 0.36, decay: 3),
    ], 1.4),
  };
  final dir = Directory('assets/sounds')..createSync(recursive: true);
  for (final e in sounds.entries) {
    final file = File('${dir.path}/${e.key}.wav')..writeAsBytesSync(_wav(e.value));
    stdout.writeln('${file.path}: ${file.lengthSync()} Bytes');
  }
}
