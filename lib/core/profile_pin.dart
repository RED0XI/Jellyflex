import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'secure_store.dart';

/// Profil-PIN (4–6 Ziffern): schützt ein Profil auf diesem Gerät vor anderen
/// Mitbewohnern (z. B. Kindern). Gespeichert wird nur ein gesalzener, langsamer
/// Hash (PBKDF2-HMAC-SHA256) – zusätzlich liegt er in der mit Windows (DPAPI)
/// verschlüsselten Kontoliste.
abstract final class ProfilePin {
  static const _iterations = 60000;
  static final _format = RegExp(r'^\d{4,6}$');

  /// Gültige PIN? (4–6 Ziffern)
  static bool isValid(String pin) => _format.hasMatch(pin);

  /// Hash für eine neue PIN (läuft im Hintergrund, die Oberfläche ruckelt nicht).
  static Future<String> hash(String pin) {
    final salt = Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    return Isolate.run(() => _encode(salt, _pbkdf2(utf8.encode(pin), salt, _iterations), _iterations));
  }

  /// Passt [pin] zum gespeicherten Hash?
  static Future<bool> verify(String pin, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]) ?? 0;
    if (iterations < 1000 || iterations > 1000000) return false;
    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = await Isolate.run(() => _pbkdf2(utf8.encode(pin), salt, iterations));
    // Vergleich in konstanter Zeit.
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static String _encode(List<int> salt, List<int> hash, int iterations) =>
      'pbkdf2\$$iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';

  /// PBKDF2 mit HMAC-SHA256, ein Block (32 Byte).
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.of(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  // --- Schutz vor Durchprobieren ---------------------------------------------

  static final _failures = <String, int>{};
  static final _lockedUntil = <String, DateTime>{};
  static const _storeKey = 'jellyflex.pinLock';

  /// Gespeicherte Fehlversuche laden (ein Neustart setzt die Sperre nicht zurück).
  static Future<void> load() async {
    try {
      final raw = await SecureStore.instance.read(key: _storeKey);
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      for (final MapEntry(:key, :value) in map.entries) {
        final entry = (value as Map).cast<String, dynamic>();
        _failures[key] = (entry['failures'] as num?)?.toInt() ?? 0;
        final until = DateTime.tryParse(entry['until'] as String? ?? '');
        if (until != null) _lockedUntil[key] = until;
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      await SecureStore.instance.write(
        key: _storeKey,
        value: jsonEncode({
          for (final key in {..._failures.keys, ..._lockedUntil.keys})
            key: {'failures': _failures[key] ?? 0, 'until': ?_lockedUntil[key]?.toIso8601String()},
        }),
      );
    } catch (_) {}
  }

  /// Wie lange das Konto noch gesperrt ist (nach 5 falschen Versuchen 30 s, danach länger).
  static Duration lockedFor(String accountKey) {
    final until = _lockedUntil[accountKey];
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static void recordFailure(String accountKey) {
    final failures = (_failures[accountKey] ?? 0) + 1;
    _failures[accountKey] = failures;
    if (failures >= 5) {
      final seconds = 30 * (1 << min(failures - 5, 5));
      _lockedUntil[accountKey] = DateTime.now().add(Duration(seconds: seconds));
    }
    _save();
  }

  static void recordSuccess(String accountKey) {
    _failures.remove(accountKey);
    _lockedUntil.remove(accountKey);
    _save();
  }
}
