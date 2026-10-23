import 'dart:convert';
import 'dart:io';

import 'version.dart';

/// Freiwillige Update-Prüfung (Standard: aus). Gefragt wird nur nach der
/// neuesten Versionsnummer – ohne Kennung, ohne Daten über dich oder deinen
/// Server. Geladen oder installiert wird nichts automatisch.
abstract final class UpdateCheck {
  /// Einzige Adresse, die dafür kontaktiert wird.
  static const feedUrl = 'https://api.github.com/repos/RED0XI/Jellyflex/releases/latest';

  /// Seite mit den Versionen (öffnet sich nur auf Klick im Browser).
  static const releasesPage = 'https://github.com/RED0XI/Jellyflex/releases';

  static final _version = RegExp(r'^v?(\d{1,4})\.(\d{1,4})\.(\d{1,4})$');

  /// Neueste veröffentlichte Version (z. B. "0.3.0") oder `null`, falls
  /// nicht ermittelbar.
  static Future<String?> latestVersion({String url = feedUrl}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'Jellyflex';
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) return null;
      // Antwort begrenzen – eine Versionsangabe ist klein.
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 512 * 1024) return null;
      }
      final tag = (jsonDecode(utf8.decode(bytes)) as Map)['tag_name'];
      final match = tag is String ? _version.firstMatch(tag.trim()) : null;
      return match == null ? null : '${match[1]}.${match[2]}.${match[3]}';
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Ist [latest] neuer als [current]? (Versionen im Format 1.2.3)
  static bool isNewer(String latest, [String current = appVersion]) {
    List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(latest);
    final b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Versionsseite im Browser öffnen (feste Adresse, nichts vom Server).
  static Future<void> openReleasesPage() => Process.run('rundll32', ['url.dll,FileProtocolHandler', releasesPage]);
}
