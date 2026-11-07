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

// ---------------------------------------------------------------------------
// Intro (Stereo, 44,1 kHz): eigener, aufwendigerer Klang mit Filtern und Hall.
// ---------------------------------------------------------------------------

const _introRate = 44100;

/// Zustandsvariablen-Filter (Chamberlin) – Bandpass/Tiefpass mit wandernder Grenzfrequenz.
class _Svf {
  double _low = 0, _band = 0;

  /// Liefert (Tiefpass, Bandpass) für [x] bei Grenzfrequenz [freq] und Güte [q].
  (double, double) run(double x, double freq, double q) {
    final f = 2 * math.sin(math.pi * math.min(freq, _introRate / 6) / _introRate);
    _low += f * _band;
    final high = x - _low - _band / q;
    _band += f * high;
    return (_low, _band);
  }
}

/// Sägezahn ohne harte Kanten (PolyBLEP) – klingt sauber statt kratzig.
class _Saw {
  _Saw(this.freq, [double phase = 0]) : _phase = phase;
  final double freq;
  double _phase;

  double next() {
    final dt = freq / _introRate;
    _phase += dt;
    if (_phase >= 1) _phase -= 1;
    var v = 2 * _phase - 1;
    // Glättung um den Sprung herum.
    if (_phase < dt) {
      final t = _phase / dt;
      v -= t + t - t * t - 1;
    } else if (_phase > 1 - dt) {
      final t = (_phase - 1) / dt;
      v -= t * t + t + t + 1;
    }
    return v;
  }
}

/// Einfacher Stereo-Hall (Freeverb-Prinzip: parallele Kammfilter, dann Allpässe).
class _Reverb {
  _Reverb({required this.room, required this.damp, int spread = 0})
    : _combs = [for (final d in const [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]) _Comb(d + spread)],
      _allpasses = [for (final d in const [556, 441, 341, 225]) _Allpass(d + spread)];
  final double room;
  final double damp;
  final List<_Comb> _combs;
  final List<_Allpass> _allpasses;

  double run(double x) {
    var out = 0.0;
    for (final c in _combs) {
      out += c.run(x * 0.015, room, damp);
    }
    for (final a in _allpasses) {
      out = a.run(out);
    }
    return out;
  }
}

class _Comb {
  _Comb(int size) : _buf = Float64List(size);
  final Float64List _buf;
  int _i = 0;
  double _store = 0;

  double run(double x, double feedback, double damp) {
    final y = _buf[_i];
    _store = y * (1 - damp) + _store * damp;
    _buf[_i] = x + _store * feedback;
    _i = (_i + 1) % _buf.length;
    return y;
  }
}

class _Allpass {
  _Allpass(int size) : _buf = Float64List(size);
  final Float64List _buf;
  int _i = 0;

  double run(double x) {
    final b = _buf[_i];
    _buf[_i] = x + b * 0.5;
    _i = (_i + 1) % _buf.length;
    return b - x;
  }
}

/// Intro beim App-Start (~3,2 s, Stereo): ein gefilterter "Riser", der durchs Stereobild wandert,
/// während sich das Zeichen zeichnet; bei 0,8 s ein tiefer Schlag und ein breiter, warmer Akkord
/// (verstimmte Sägezähne durch einen sich schließenden Tiefpass); zwei FM-Glocken zu den Bögen;
/// alles in einem Hall.
(Float64List, Float64List) _introStereo() {
  const seconds = 3.2;
  final n = (seconds * _introRate).round();
  final left = Float64List(n);
  final right = Float64List(n);
  void add(int i, double v, double pan) {
    // Gleich laute Mitte: Wurzel-Gesetz.
    left[i] += v * math.sqrt(0.5 * (1 - pan));
    right[i] += v * math.sqrt(0.5 * (1 + pan));
  }

  final random = math.Random(11);

  // 1) Riser 0,0–0,82 s: Rauschen durch einen Bandpass, der von 250 Hz auf 7 kHz steigt.
  final svf = _Svf();
  const riserEnd = 0.82;
  for (var i = 0; i < (riserEnd * _introRate).round(); i++) {
    final p = i / (riserEnd * _introRate);
    final freq = 250 * math.pow(28, p);
    final (_, band) = svf.run(random.nextDouble() * 2 - 1, freq.toDouble(), 2.2);
    final env = math.pow(p, 2.2) * (p > 0.94 ? (1 - p) / 0.06 : 1);
    add(i, 0.55 * env * band, -0.7 + 1.4 * p);
    // Darunter ein leiser, aufsteigender Ton.
    final tone = math.sin(2 * math.pi * (110 + 110 * p * p) * i / _introRate);
    add(i, 0.05 * env * tone, 0);
  }

  // 2) Schlag bei 0,8 s: Sinus, der von 110 auf 46 Hz fällt, dazu ein kurzer dumpfer Anschlag.
  const hit = 0.80;
  final hitStart = (hit * _introRate).round();
  var phase = 0.0;
  for (var i = 0; i < (1.4 * _introRate).round() && hitStart + i < n; i++) {
    final t = i / _introRate;
    final freq = 46 + 64 * math.exp(-t * 14);
    phase += 2 * math.pi * freq / _introRate;
    final env = math.min(1.0, t / 0.004) * math.exp(-t * 3.2);
    add(hitStart + i, 0.6 * env * math.sin(phase), 0);
  }
  final thump = _Svf();
  for (var i = 0; i < (0.06 * _introRate).round(); i++) {
    final (low, _) = thump.run(random.nextDouble() * 2 - 1, 900, 0.7);
    add(hitStart + i, 0.35 * low * math.exp(-i / (0.012 * _introRate)), 0);
  }

  // 3) Akkord D-Dur add9, jede Stimme drei leicht verstimmte Sägezähne, breit verteilt.
  const chord = [
    (73.42, -0.0, 0.22), // D2
    (146.83, -0.5, 0.16), // D3
    (220.00, 0.45, 0.13), // A3
    (293.66, -0.3, 0.11), // D4
    (369.99, 0.35, 0.09), // F#4
    (659.25, 0.0, 0.05), // E5
  ];
  for (final (freq, pan, vol) in chord) {
    final saws = [for (final c in const [-7.0, 0.0, 7.0]) _Saw(freq * math.pow(2, c / 1200), random.nextDouble())];
    final filter = _Svf();
    for (var i = 0; i < (2.4 * _introRate).round() && hitStart + i < n; i++) {
      final t = i / _introRate;
      var v = 0.0;
      for (final saw in saws) {
        v += saw.next();
      }
      // Tiefpass schließt sich langsam: hell beim Anschlag, dann warm.
      final (low, _) = filter.run(v / 3, 700 + 3200 * math.exp(-t * 2.4), 0.9);
      final env = math.min(1.0, t / 0.025) * math.exp(-t * 1.25);
      add(hitStart + i, vol * env * low, pan);
    }
  }

  // 4) Zwei FM-Glocken (Träger + Modulator 3,5:1) zu den Bögen, links und rechts.
  void bell(double at, double freq, double pan, double vol) {
    final from = (at * _introRate).round();
    for (var i = 0; i < (1.6 * _introRate).round() && from + i < n; i++) {
      final t = i / _introRate;
      final index = 2.4 * math.exp(-t * 5) + 0.3;
      final mod = index * math.sin(2 * math.pi * freq * 3.5 * t);
      final env = math.min(1.0, t / 0.002) * math.exp(-t * 3.2);
      add(from + i, vol * env * math.sin(2 * math.pi * freq * t + mod), pan);
    }
  }

  bell(1.12, 880.0, -0.45, 0.10);
  bell(1.34, 1318.5, 0.45, 0.085);

  // Hall: getrennt je Seite (leicht versetzte Längen = breiter Raum), dazumischen.
  final verbL = _Reverb(room: 0.84, damp: 0.3);
  final verbR = _Reverb(room: 0.84, damp: 0.3, spread: 23);
  for (var i = 0; i < n; i++) {
    final mono = (left[i] + right[i]) * 0.5;
    left[i] += 0.32 * verbL.run(mono);
    right[i] += 0.32 * verbR.run(mono);
  }

  // Weich begrenzen, angleichen, ausblenden.
  var peak = 0.0;
  for (var i = 0; i < n; i++) {
    left[i] = _softClip(left[i]);
    right[i] = _softClip(right[i]);
    peak = math.max(peak, math.max(left[i].abs(), right[i].abs()));
  }
  final gain = 0.89 / peak;
  final fade = (0.45 * _introRate).round();
  for (var i = 0; i < n; i++) {
    final f = i > n - fade ? (n - i) / fade : 1.0;
    left[i] *= gain * f;
    right[i] *= gain * f;
  }
  return (left, right);
}

double _softClip(double x) => x / (1 + x.abs() * 0.6);

Uint8List _wavStereo(Float64List left, Float64List right) {
  final data = ByteData(left.length * 4);
  for (var i = 0; i < left.length; i++) {
    data.setInt16(i * 4, (left[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    data.setInt16(i * 4 + 2, (right[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  final header = ByteData(44)
    ..setUint32(0, 0x52494646, Endian.big)
    ..setUint32(4, 36 + data.lengthInBytes, Endian.little)
    ..setUint32(8, 0x57415645, Endian.big)
    ..setUint32(12, 0x666d7420, Endian.big)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 2, Endian.little) // Stereo
    ..setUint32(24, _introRate, Endian.little)
    ..setUint32(28, _introRate * 4, Endian.little)
    ..setUint16(32, 4, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461, Endian.big)
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
  final (left, right) = _introStereo();
  final intro = File('${dir.path}/intro.wav')..writeAsBytesSync(_wavStereo(left, right));
  stdout.writeln('${intro.path}: ${intro.lengthSync()} Bytes');
}
