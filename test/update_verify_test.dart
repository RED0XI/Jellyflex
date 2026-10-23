import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/update_check.dart';

void main() {
  // flutter_test ersetzt HttpClient – hier echte Verbindungen (nur localhost).
  setUpAll(() => HttpOverrides.global = null);

  late SimpleKeyPair keys;
  late String publicKey;
  final installer = List<int>.generate(200000, (i) => i * 7 % 256);

  setUpAll(() async {
    keys = await Ed25519().newKeyPair();
    publicKey = base64Encode((await keys.extractPublicKey()).bytes);
  });

  Future<String> sign(List<int> data, [SimpleKeyPair? pair]) async =>
      base64Encode((await Ed25519().sign(data, keyPair: pair ?? keys)).bytes);

  test('Signatur passt nur zur unveränderten Datei und zum richtigen Schlüssel', () async {
    final signature = await sign(installer);
    expect(await UpdateCheck.verify(installer, signature, publicKey: publicKey), isTrue);

    final changed = [...installer]..[1000] ^= 1;
    expect(await UpdateCheck.verify(changed, signature, publicKey: publicKey), isFalse, reason: 'Ein Byte anders');

    final other = await Ed25519().newKeyPair();
    expect(await UpdateCheck.verify(installer, await sign(installer, other), publicKey: publicKey), isFalse);
    expect(await UpdateCheck.verify(installer, 'kein base64!', publicKey: publicKey), isFalse);
    // Der eingebaute Schlüssel akzeptiert eine fremde Signatur nicht.
    expect(await UpdateCheck.verify(installer, signature), isFalse);
  });

  test('Laden: nur mit gültiger Signatur entsteht eine Datei', () async {
    var payload = installer;
    var signature = await sign(installer);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      if (req.uri.path.endsWith('.sig')) {
        req.response.write(signature);
      } else {
        req.response.add(payload);
      }
      req.response.close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    final release = UpdateRelease('9.9.9', installerUrl: '$base/setup.exe', signatureUrl: '$base/setup.exe.sig');
    try {
      final ok = await UpdateCheck.downloadVerified(release, publicKey: publicKey);
      expect(ok, isNotNull);
      expect(ok!.readAsBytesSync(), installer);
      ok.deleteSync();

      // Ausgetauschter Installer (Signatur passt nicht mehr) → nichts.
      payload = [...installer, 1, 2, 3];
      expect(await UpdateCheck.downloadVerified(release, publicKey: publicKey), isNull);
      // Signatur fehlt im Release → nichts.
      expect(await UpdateCheck.downloadVerified(const UpdateRelease('9.9.9', installerUrl: 'x')), isNull);
      signature = 'kaputt';
      payload = installer;
      expect(await UpdateCheck.downloadVerified(release, publicKey: publicKey), isNull);
    } finally {
      await server.close(force: true);
    }
  });
}
