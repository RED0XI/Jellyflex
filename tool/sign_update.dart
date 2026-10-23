// Signiert einen Installer, damit die App ein Update vor dem Starten prüfen kann.
//
// Einmalig einen Schlüssel anlegen:   dart run tool/sign_update.dart --new-key
//   → legt den geheimen Schlüssel unter %APPDATA%\JellyflexRelease ab und zeigt den
//     öffentlichen Schlüssel, der in lib/core/update_check.dart (signingPublicKey) gehört.
//     Den geheimen Schlüssel sichern (z. B. USB-Stick) und NIE weitergeben oder einchecken:
//     Ohne ihn lassen sich keine Updates mehr signieren, mit ihm könnte jeder "Updates" bauen.
//
// Installer signieren:                dart run tool/sign_update.dart dist\Jellyflex-Setup-0.3.0.exe
//   → schreibt dist\Jellyflex-Setup-0.3.0.exe.sig (gehört mit in das GitHub-Release).
//   (tool/build_installer.ps1 macht das automatisch, wenn ein Schlüssel da ist.)

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

File get _keyFile =>
    File('${Platform.environment['APPDATA'] ?? Directory.systemTemp.path}\\JellyflexRelease\\update_signing_key.json');

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
    stderr.writeln('Aufruf: dart run tool/sign_update.dart <Installer.exe>  |  --new-key');
    exitCode = 2;
    return;
  }
  if (!_keyFile.existsSync()) {
    stderr.writeln('Kein Schlüssel gefunden (${_keyFile.path}). Erst: dart run tool/sign_update.dart --new-key');
    exitCode = 1;
    return;
  }
  final key = jsonDecode(_keyFile.readAsStringSync()) as Map<String, dynamic>;
  final pair = await algorithm.newKeyPairFromSeed(base64Decode(key['seed'] as String));
  final installer = File(args.first);
  final signature = await algorithm.sign(await installer.readAsBytes(), keyPair: pair);
  final sigFile = File('${installer.path}.sig')..writeAsStringSync(base64Encode(signature.bytes));
  stdout.writeln('Signiert: ${sigFile.path}');
}
