// Prüft die Zertifikatsprüfung des Video-Players (mpv): Mit SystemCerts.secure
// wird ein abgelaufenes Zertifikat abgelehnt, ein gültiges angenommen.
// Braucht Internet (badssl.com ist eine öffentliche Testseite genau dafür).
//
// Start:  flutter test integration_test/tls_probe_test.dart -d windows

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/system_certs.dart';
import 'package:media_kit/media_kit.dart';

/// Öffnet [url] (eine Webseite, kein Video) und liefert die Meldungen von mpv.
/// "Failed to recognize file format" = Verbindung klappte (TLS ok),
/// "Failed to open" = Verbindung abgelehnt.
Future<String> _open(WidgetTester tester, String url, {required bool secure}) async {
  final player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn));
  if (secure) await tester.runAsync(() => SystemCerts.secure(player));
  final messages = <String>[];
  final sub = player.stream.error.listen(messages.add);
  final logs = player.stream.log.listen((l) => debugPrint('   mpv ${l.prefix}: ${l.text.trim()}'));
  await player.open(Media(url));
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 8)));
  await sub.cancel();
  await logs.cancel();
  await player.dispose();
  final text = messages.join(' | ');
  debugPrint('$url (geprüft: $secure): $text');
  return text;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Video-Player prüft Zertifikate', (tester) async {
    try {
      await tester.runAsync(() => InternetAddress.lookup('badssl.com'));
    } catch (_) {
      markTestSkipped('Kein Internet');
      return;
    }
    final ca = await tester.runAsync(SystemCerts.caFile);
    expect(ca, isNotNull, reason: 'Stammzertifikate von Windows exportiert');
    expect(File(ca!).readAsStringSync(), contains('BEGIN CERTIFICATE'));

    // Ohne Prüfung (so war es vorher): abgelaufenes Zertifikat wird angenommen.
    expect(await _open(tester, 'https://expired.badssl.com/', secure: false), contains('recognize file format'));
    // Mit Prüfung: abgelehnt …
    expect(await _open(tester, 'https://expired.badssl.com/', secure: true), contains('Failed to open'));
    expect(await _open(tester, 'https://self-signed.badssl.com/', secure: true), contains('Failed to open'));
    // … aber gültige Zertifikate funktionieren weiter.
    expect(await _open(tester, 'https://badssl.com/', secure: true), contains('recognize file format'));
  });
}
