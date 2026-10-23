import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/system_certs.dart';

// Minimale Zertifikats-Hüllen (DER): SEQUENCE { tbs, SEQUENCE { OID }, BIT STRING }
List<int> _cert(List<int> oid) {
  final tbs = [0x30, 0x03, 0x02, 0x01, 0x01];
  final alg = [0x30, oid.length + 2, 0x06, oid.length, ...oid];
  final sig = [0x03, 0x02, 0x00, 0x00];
  final body = [...tbs, ...alg, ...sig];
  return [0x30, body.length, ...body];
}

void main() {
  const rsa = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01];
  test('Gebrochene Signaturverfahren werden erkannt', () {
    expect(SystemCerts.usesBrokenHash(base64.decode(base64.encode(_cert([...rsa, 0x02])))), isTrue, reason: 'MD2');
    expect(SystemCerts.usesBrokenHash(base64.decode(base64.encode(_cert([...rsa, 0x04])))), isTrue, reason: 'MD5');
    expect(SystemCerts.usesBrokenHash(base64.decode(base64.encode(_cert([...rsa, 0x0B])))), isFalse, reason: 'SHA-256');
    expect(SystemCerts.usesBrokenHash(base64.decode(base64.encode(_cert([...rsa, 0x05])))), isFalse, reason: 'SHA-1');
  });
}
