import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/l10n/strings.dart';

void main() {
  test('Heimnetz-Adressen erkennen', () {
    for (final h in [
      'localhost',
      '127.0.0.1',
      '192.168.1.20',
      '10.0.0.5',
      '172.20.1.1',
      'nas.local',
      '[::1]',
      'fd12::1',
    ]) {
      expect(isLocalHost(h), isTrue, reason: h);
    }
    for (final h in ['jellyfin.example.com', '8.8.8.8', '172.32.0.1', 'media.tailnet-example.ts.net', '2001:db8::1']) {
      expect(isLocalHost(h), isFalse, reason: h);
    }
  });

  test('Unverschlüsselt wird erkannt', () {
    expect(const ServerInfo(url: 'http://192.168.1.2:8096', name: '', version: '').insecure, isTrue);
    expect(const ServerInfo(url: 'https://jf.example.com', name: '', version: '').insecure, isFalse);
  });

  test('Ungültiges Zertifikat: kein Verbinden, kein Ausweichen auf http', () async {
    try {
      await InternetAddress.lookup('expired.badssl.com');
    } catch (_) {
      markTestSkipped('Kein Internet');
      return;
    }
    appLanguage = AppLanguage.en;
    await expectLater(
      JellyfinApi.probe('expired.badssl.com'),
      throwsA(predicate((e) => e.toString().contains(tr.certificateInvalid))),
    );
  });
}
