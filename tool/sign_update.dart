// Signiert ein Update-Paket (Windows-Installer oder macOS-Zip), damit die App es vor
// dem Installieren prüfen kann.
//
// Einmalig einen Schlüssel anlegen:   dart run tool/sign_update.dart --new-key
//   → legt den geheimen Schlüssel unter %APPDATA%\JellyflexRelease (macOS:
//     ~/Library/Application Support/JellyflexRelease) ab und zeigt den
//     öffentlichen Schlüssel, der in lib/core/update_check.dart (signingPublicKey) gehört.
//     Den geheimen Schlüssel sichern (z. B. USB-Stick) und NIE weitergeben oder einchecken:
//     Ohne ihn lassen sich keine Updates mehr signieren, mit ihm könnte jeder "Updates" bauen.
//
// Installer signieren:                dart run tool/sign_update.dart dist\Jellyflex-Setup-0.3.0.exe
//   → schreibt dist\Jellyflex-Setup-0.3.0.exe.sig (gehört mit in das GitHub-Release).
//   (tool/build_installer.ps1 und tool/build_macos.sh machen das automatisch, wenn ein
//   Schlüssel da ist.)
//
// GitHub Actions: Inhalt der Schlüsseldatei als Secret JELLYFLEX_UPDATE_SIGNING_KEY –
//   die Umgebungsvariable hat Vorrang vor der Datei.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

const _keyEnv = 'JELLYFLEX_UPDATE_SIGNING_KEY';

File get _keyFile {
  final sep = Platform.pathSeparator;
  final base = Platform.isWindows
      ? Platform.environment['APPDATA']
      : '${Platform.environment['HOME']}/Library/Application Support';
  return File('${base ?? Directory.systemTemp.path}${sep}JellyflexRelease${sep}update_signing_key.json');
}

/// Schlüssel (JSON mit "seed") aus der Umgebung oder der Datei; `null` = keiner da.
String? _readKey() {
  final env = Platform.environment[_keyEnv];
  if (env != null && env.trim().isNotEmpty) return env;
  return _keyFile.existsSync() ? _keyFile.readAsStringSync() : null;
}

Future<void> main(List<String> args) async {
  final algorithm = Ed25519();
  if (args.length == 1 && args.first == '--new-key') {
    if (_keyFile.existsSync()) {
      stderr.writeln('Es gibt schon einen Schlüssel: ${_keyFile.path} – nicht überschrieben.');
      exitCode = 1;
      return;
    }
    final pair = await algorithm.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final public = (await pair.extractPublicKey()).bytes;
    _keyFile.parent.createSync(recursive: true);
    _keyFile.writeAsStringSync(jsonEncode({'seed': base64Encode(seed), 'public': base64Encode(public)}));
    stdout.writeln('Schlüssel angelegt: ${_keyFile.path}');
    stdout.writeln('Öffentlicher Schlüssel (in update_check.dart eintragen):');
    stdout.writeln(base64Encode(public));
    return;
  }
  if (args.length != 1 || !File(args.first).existsSync()) {
    stderr.writeln('Aufruf: dart run tool/sign_update.dart <Paket (.exe/.zip)>  |  --new-key');
    exitCode = 2;
    return;
  }
  final raw = _readKey();
  if (raw == null) {
    stderr.writeln(
      'Kein Schlüssel gefunden ($_keyEnv oder ${_keyFile.path}). Erst: dart run tool/sign_update.dart --new-key',
    );
    exitCode = 1;
    return;
  }
  // Nie den Inhalt ausgeben – Fehlermeldungen landen in öffentlichen Actions-Protokollen.
  final List<int> seed;
  try {
    seed = _parseSeed(raw);
  } catch (_) {
    stderr.writeln('Schlüssel ist kein gültiges JSON mit "seed" (Inhalt wird nicht angezeigt).');
    exitCode = 1;
    return;
  }
  final pair = await algorithm.newKeyPairFromSeed(seed);
  final installer = File(args.first);
  final signature = await algorithm.sign(await installer.readAsBytes(), keyPair: pair);
  final sigFile = File('${installer.path}.sig')..writeAsStringSync(base64Encode(signature.bytes));
  stdout.writeln('Signiert: ${sigFile.path}');
}

/// Seed aus dem Schlüssel-JSON. Ein BOM am Anfang (PowerShell beim Weiterleiten) und
/// Leerzeichen/Zeilenumbrüche drumherum werden ignoriert.
List<int> _parseSeed(String raw) {
  var text = raw.trim();
  if (text.startsWith('\uFEFF')) text = text.substring(1).trim();
  final key = jsonDecode(text) as Map<String, dynamic>;
  final seed = base64Decode(key['seed'] as String);
  if (seed.length != 32) throw const FormatException();
  return seed;
}
