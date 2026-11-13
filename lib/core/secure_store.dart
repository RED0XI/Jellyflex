import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'platform/app_paths.dart';

/// Kleiner verschlüsselter Schlüssel-Wert-Speicher.
///
/// Die Daten liegen verschlüsselt in `secure.bin` im App-Datenordner:
/// - **Windows:** mit der Windows-Datenschutz-API (DPAPI) verschlüsselt. Entschlüsseln
///   kann sie nur dasselbe Windows-Benutzerkonto – ganz ohne eigenes Passwort.
/// - **macOS:** mit AES-256-GCM verschlüsselt; den Schlüssel verwahrt der
///   macOS-Schlüsselbund (nur für diesen Benutzer und diese App, nie synchronisiert).
class SecureStore {
  SecureStore._(this._fileOverride);

  /// Nur für Tests: Speicher in einer bestimmten Datei.
  SecureStore.forFile(File file) : this._(file);

  /// Der Speicher der App. Tests ersetzen ihn durch eine Temp-Datei (nie den echten).
  static SecureStore instance = SecureStore._(null);

  final File? _fileOverride;
  Map<String, String>? _cache;
  Future<void> _pending = Future.value();

  File get _file => _fileOverride ?? File(AppPaths.join(AppPaths.appData.path, 'secure.bin'));

  /// Laufendes Laden – zwei gleichzeitige erste Zugriffe teilen sich ein Ergebnis (sonst
  /// entstünden zwei Listen, und ein Schreibvorgang in die erste ginge verloren).
  Future<Map<String, String>?>? _loading;

  /// Inhalt des Speichers. `null`: Es gibt eine Datei, aber der Schlüssel ist gerade nicht
  /// erreichbar (Schlüsselbund gesperrt, Abfrage abgelehnt …). Das ist nicht "leer": Wer dann eine
  /// leere Liste annähme und speicherte, überschriebe alle Konten und PINs.
  Future<Map<String, String>?> _load() {
    final cache = _cache;
    if (cache != null) return Future.value(cache);
    return _loading ??= _read().whenComplete(() => _loading = null);
  }

  Future<Map<String, String>?> _read() async {
    final test = _fileOverride != null;
    try {
      final file = _file;
      if (await file.exists()) {
        // Nicht merken – beim nächsten Zugriff neu versuchen.
        if (!await _Cipher.available(test: test)) return null;
        final plain = await _Cipher.unprotect(await file.readAsBytes(), test: test);
        if (plain != null) {
          final decoded = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
          return _cache = decoded.map((k, v) => MapEntry(k, v as String));
        }
      }
    } catch (_) {
      // Beschädigt oder von einem anderen Konto – neu anfangen.
    }
    return _cache = {};
  }

  Future<void> _save() {
    // Schreibvorgänge nacheinander ausführen. Ein Fehler wird gemeldet, blockiert
    // aber nicht alle folgenden Speichervorgänge.
    final run = _pending.catchError((_) {}).then((_) async {
      final file = _file;
      await file.parent.create(recursive: true);
      final encrypted = await _Cipher.protect(
        Uint8List.fromList(utf8.encode(jsonEncode(_cache ?? {}))),
        test: _fileOverride != null,
      );
      if (encrypted == null) throw FileSystemException(tr.encryptionFailed);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(encrypted, flush: true);
      await tmp.rename(file.path);
    });
    _pending = run.catchError((_) {});
    return run;
  }

  Future<String?> read({required String key}) async => (await _load())?[key];

  Future<void> write({required String key, required String value}) async {
    (await _unlocked())[key] = value;
    await _save();
  }

  Future<void> delete({required String key}) async {
    if ((await _unlocked()).remove(key) != null) await _save();
  }

  /// Inhalt zum Ändern – nie eine leere Liste anstelle eines Speichers, der sich gerade nicht
  /// entschlüsseln lässt (siehe [_load]).
  Future<Map<String, String>> _unlocked() async =>
      await _load() ?? (throw FileSystemException(tr.encryptionFailed, _file.path));
}

/// Verschlüsselung je Betriebssystem. `null` = nicht möglich (dann wird nichts gespeichert).
/// [test]: Speicher eines Tests ([SecureStore.forFile]) – auf macOS/iOS mit einem Schlüssel nur im
/// Arbeitsspeicher statt dem echten Schlüsselbund (App-Tests laufen im echten Runner).
abstract final class _Cipher {
  static Future<Uint8List?> protect(Uint8List data, {bool test = false}) async =>
      Platform.isWindows ? _Dpapi.protect(data) : _KeychainAes.protect(data, test: test);

  static Future<Uint8List?> unprotect(Uint8List data, {bool test = false}) async =>
      Platform.isWindows ? _Dpapi.unprotect(data) : _KeychainAes.unprotect(data, test: test);

  /// Lässt sich gerade überhaupt ver- und entschlüsseln (Schlüssel erreichbar)?
  static Future<bool> available({bool test = false}) async =>
      Platform.isWindows || await _KeychainAes.available(test: test);
}

// --- macOS: AES-256-GCM, Schlüssel im Schlüsselbund ------------------------------

/// Gegenstück in Swift: macos/Runner/Keychain.swift (Kanal `jellyflex/keychain`).
abstract final class _KeychainAes {
  static const _channel = MethodChannel('jellyflex/keychain');

  /// Kennung des Dateiformats ("JFX" + Version 1), danach Nonce, Geheimtext, MAC.
  static const _magic = [0x4A, 0x46, 0x58, 0x01];
  static final _algorithm = AesGcm.with256bits();

  static Future<SecretKey?>? _key;

  static Future<SecretKey?> _loadKey() async {
    // In `flutter test` (ohne macOS-Runner): Schlüssel nur im Arbeitsspeicher – Tests
    // berühren nie den echten Schlüsselbund.
    if (Platform.environment['FLUTTER_TEST'] == 'true') return _algorithm.newSecretKey();
    try {
      final raw = await _channel.invokeMethod<Uint8List>('storeKey');
      if (raw != null && raw.length == 32) return SecretKey(raw);
      return null;
    } catch (_) {
      // Ohne Schlüsselbund wird nie etwas gespeichert.
      return null;
    }
  }

  /// Schlüssel für Test-Speicher – nie im Schlüsselbund.
  static final Future<SecretKey> _testKey = _algorithm.newSecretKey();

  static Future<SecretKey?> _secretKey({bool test = false}) async {
    if (test) return _testKey;
    final key = await (_key ??= _loadKey());
    // Fehlschlag nicht merken – beim nächsten Mal neu versuchen.
    if (key == null) _key = null;
    return key;
  }

  static Future<bool> available({bool test = false}) async => await _secretKey(test: test) != null;

  static Future<Uint8List?> protect(Uint8List data, {bool test = false}) async {
    final key = await _secretKey(test: test);
    if (key == null) return null;
    final box = await _algorithm.encrypt(data, secretKey: key);
    return Uint8List.fromList([..._magic, ...box.concatenation()]);
  }

  static Future<Uint8List?> unprotect(Uint8List data, {bool test = false}) async {
    if (data.length < _magic.length + 12 + 16) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) return null;
    }
    final key = await _secretKey(test: test);
    if (key == null) return null;
    try {
      final box = SecretBox.fromConcatenation(
        data.sublist(_magic.length),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      return Uint8List.fromList(await _algorithm.decrypt(box, secretKey: key));
    } on SecretBoxAuthenticationError {
      return null; // Verändert oder mit einem anderen Schlüssel verschlüsselt.
    }
  }
}

// --- Windows: DPAPI über dart:ffi ------------------------------------------------

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptNative = Int32 Function(
  Pointer<_DataBlob> dataIn,
  Pointer<Void> description,
  Pointer<_DataBlob> entropy,
  Pointer<Void> reserved,
  Pointer<Void> prompt,
  Uint32 flags,
  Pointer<_DataBlob> dataOut,
);
typedef _CryptDart = int Function(
  Pointer<_DataBlob> dataIn,
  Pointer<Void> description,
  Pointer<_DataBlob> entropy,
  Pointer<Void> reserved,
  Pointer<Void> prompt,
  int flags,
  Pointer<_DataBlob> dataOut,
);

abstract final class _Dpapi {
  static const _uiForbidden = 0x1;

  static final _crypt32 = DynamicLibrary.open('crypt32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final _protect = _crypt32.lookupFunction<_CryptNative, _CryptDart>('CryptProtectData');
  static final _unprotect = _crypt32.lookupFunction<_CryptNative, _CryptDart>('CryptUnprotectData');
  static final _localFree = _kernel32
      .lookupFunction<Pointer<Void> Function(Pointer<Void>), Pointer<Void> Function(Pointer<Void>)>('LocalFree');

  static Uint8List? protect(Uint8List data) => _run(data, _protect);
  static Uint8List? unprotect(Uint8List data) => _run(data, _unprotect);

  static Uint8List? _run(Uint8List input, _CryptDart fn) {
    final inBlob = calloc<_DataBlob>();
    final outBlob = calloc<_DataBlob>();
    final buffer = calloc<Uint8>(input.isEmpty ? 1 : input.length);
    try {
      buffer.asTypedList(input.length).setAll(0, input);
      inBlob.ref
        ..cbData = input.length
        ..pbData = buffer;
      final ok = fn(inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob);
      if (ok == 0) return null;
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      // Klartext (Token!) im nativen Speicher überschreiben, bevor er freigegeben wird.
      final out = outBlob.ref.pbData;
      if (out != nullptr) {
        out.asTypedList(outBlob.ref.cbData).fillRange(0, outBlob.ref.cbData, 0);
        _localFree(out.cast());
      }
      buffer.asTypedList(input.isEmpty ? 1 : input.length).fillRange(0, input.isEmpty ? 1 : input.length, 0);
      calloc.free(buffer);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }
}
