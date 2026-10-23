import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/redact.dart';

void main() {
  test('Zugangsdaten werden aus Texten entfernt', () {
    expect(
      redactSecrets('Failed to open https://jf.example/videos/1/master.m3u8?MediaSourceId=1&api_key=SECRET123&x=1'),
      'Failed to open https://jf.example/videos/1/master.m3u8?MediaSourceId=1&api_key=***&x=1',
    );
    expect(redactSecrets('ApiKey=abc'), 'ApiKey=***');
    expect(
      redactSecrets('Authorization: MediaBrowser Client="Jellyflex", Token="abcdef"'),
      'Authorization: MediaBrowser Client="Jellyflex", Token="***"',
    );
    expect(redactSecrets('https://user:pass@jf.example/x'), 'https://***@jf.example/x');
    expect(redactSecrets('nichts Geheimes hier'), 'nichts Geheimes hier');
    expect(redactSecrets('x?api%5Fkey=SECRET&y=1'), 'x?api%5Fkey=***&y=1');
    expect(redactSecrets('x?api_key%3DSECRET'), 'x?api_key%3D***');
    registerSecret('0123456789abcdef');
    expect(redactSecrets('irgendwo 0123456789abcdef im Text'), 'irgendwo *** im Text');
  });

  test('Adressen vom Server führen nur zum eigenen Server', () {
    final api = JellyfinApi(baseUrl: 'https://jf.example/jellyfin', deviceId: 'd');
    expect(api.onServer('/videos/1/master.m3u8?a=1'), 'https://jf.example/jellyfin/videos/1/master.m3u8?a=1');
    expect(() => api.onServer('@evil.example/video'), throwsException);
    expect(() => api.onServer('https://evil.example/video'), throwsException);
    expect(() => api.onServer('http://jf.example/jellyfin/x'), throwsException, reason: 'Anderes Schema');
    expect(() => api.onServer('https://jf.example:444/x'), throwsException, reason: 'Anderer Port');
  });
}
