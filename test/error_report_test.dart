import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/error_report.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/update_check.dart';
import 'package:jellyflex/core/version.dart';

const _session = AuthSession(
  serverUrl: 'https://media.example-family.de:8920/jellyfin',
  serverName: 'Familien-NAS',
  userId: 'a1b2c3d4e5f6',
  userName: 'Maximilian',
  token: 'tok_0123456789abcdef',
  deviceId: 'device-xyz-123',
);

void main() {
  test('Fehlerbericht enthält keine persönlichen Angaben', () {
    final profile = Platform.environment['USERPROFILE'] ?? r'C:\Users\Test';
    final report = buildErrorReport(
      settings: const AppSettings(),
      session: _session,
      log: [
        'GET https://media.example-family.de:8920/jellyfin/Users/a1b2c3d4e5f6/Items?api_key=tok_0123456789abcdef',
        'Benutzer Maximilian auf Familien-NAS angemeldet (device-xyz-123)',
        r'Datei: ' '$profile' r'\Videos\Jellyflex\x\media.mkv',
        'Fehler bei http://192.168.1.20:8096/System/Info',
      ],
    );
    for (final secret in [
      'example-family',
      'Familien-NAS',
      'a1b2c3d4e5f6',
      'Maximilian',
      'tok_0123456789abcdef',
      'device-xyz-123',
      profile,
      '192.168.1.20',
    ]) {
      expect(report.contains(secret), isFalse, reason: secret);
    }
    expect(report, contains('App version: $appVersion'));
    expect(report, contains('%USERPROFILE%'));
    expect(report, contains('<server>'));
  });

  test('Versionen vergleichen', () {
    expect(UpdateCheck.isNewer('0.3.0', '0.2.0'), isTrue);
    expect(UpdateCheck.isNewer('0.10.0', '0.9.9'), isTrue);
    expect(UpdateCheck.isNewer('0.2.0', '0.2.0'), isFalse);
    expect(UpdateCheck.isNewer('0.1.9', '0.2.0'), isFalse);
  });

  test('Update-Prüfung liest nur eine gültige Versionsnummer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var answer = '{"tag_name": "v1.2.3", "body": "irgendwas"}';
    server.listen((req) async {
      req.response.write(answer);
      await req.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/latest';
    expect(await UpdateCheck.latestVersion(url: url), '1.2.3');
    answer = jsonEncode({'tag_name': '1.2.3; rm -rf'});
    expect(await UpdateCheck.latestVersion(url: url), isNull);
    answer = 'kaputt';
    expect(await UpdateCheck.latestVersion(url: url), isNull);
    await server.close(force: true);
  });

  test('App-Version passt zu pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':').last.trim().split('+').first, appVersion);
  });
}
