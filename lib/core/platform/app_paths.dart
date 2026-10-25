import 'dart:io';

/// Ordner und Dateipfade der App – je Betriebssystem an den dort üblichen Orten.
///
/// | Zweck          | Windows                         | macOS                                      |
/// |----------------|---------------------------------|--------------------------------------------|
/// | Einstellungen  | `%APPDATA%\Jellyflex`           | `~/Library/Application Support/Jellyflex`  |
/// | Zwischenspeich.| `%LOCALAPPDATA%\Jellyflex`      | `~/Library/Caches/Jellyflex`               |
/// | Videos         | `%USERPROFILE%\Videos`          | `~/Movies`                                 |
/// | Bilder         | `%USERPROFILE%\Pictures`        | `~/Pictures`                               |
///
/// Unter Windows bleiben alle Pfade exakt wie in früheren Versionen – vorhandene
/// Einstellungen, Anmeldungen und Downloads werden weiter gefunden.
abstract final class AppPaths {
  static const appFolder = 'Jellyflex';

  /// Trennzeichen des Systems (`\` oder `/`).
  static String get sep => Platform.pathSeparator;

  /// Teile mit dem Trennzeichen des Systems verbinden.
  static String join(String base, String part1, [String? part2, String? part3]) {
    final parts = [part1, ?part2, ?part3];
    var result = base;
    for (final p in parts) {
      result = result.endsWith(sep) ? '$result$p' : '$result$sep$p';
    }
    return result;
  }

  static String? _env(String name) {
    final value = Platform.environment[name];
    return value == null || value.isEmpty ? null : value;
  }

  /// Benutzerordner (`%USERPROFILE%` bzw. `$HOME`).
  static String get home => (Platform.isWindows ? _env('USERPROFILE') : _env('HOME')) ?? Directory.systemTemp.path;

  /// Einstellungen, Anmeldung, Downloadliste, eigenes Logo.
  static Directory get appData {
    if (Platform.isWindows) return Directory(join(_env('APPDATA') ?? Directory.systemTemp.path, appFolder));
    if (Platform.isMacOS) return Directory(join(home, 'Library', 'Application Support', appFolder));
    return Directory(join(_env('XDG_CONFIG_HOME') ?? join(home, '.config'), appFolder.toLowerCase()));
  }

  /// Zwischenspeicher, der nicht gesichert/synchronisiert werden muss (z. B. Bilder).
  static Directory get cache {
    if (Platform.isWindows) return Directory(join(_env('LOCALAPPDATA') ?? Directory.systemTemp.path, appFolder));
    if (Platform.isMacOS) return Directory(join(home, 'Library', 'Caches', appFolder));
    return Directory(join(_env('XDG_CACHE_HOME') ?? join(home, '.cache'), appFolder.toLowerCase()));
  }

  /// Ordner für Videos (Standard-Downloadort liegt darin).
  static String get videos => join(home, Platform.isMacOS ? 'Movies' : 'Videos');

  /// Downloads-Ordner (Leistungstest-Berichte) – anders als „Dokumente“ selten in OneDrive umgeleitet.
  static String get downloads => join(home, 'Downloads');

  /// Ordner für Bilder (Bildschirmfotos, Jahresrückblick).
  static String get pictures => join(home, 'Pictures');

  /// Pfad für Vergleiche: absolut, ohne abschließendes Trennzeichen, klein geschrieben
  /// (Windows und macOS unterscheiden standardmäßig nicht nach Groß-/Kleinschreibung).
  /// Unter Windows zählt `/` wie `\`.
  static String normalize(String path) {
    var s = Directory(path).absolute.path;
    if (Platform.isWindows) s = s.replaceAll('/', r'\');
    s = s.toLowerCase();
    while (s.length > 1 && s.endsWith(sep) && !(Platform.isWindows && s.length <= 3)) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Datei im Dateimanager zeigen (Explorer bzw. Finder) und markieren.
  static Future<void> reveal(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,$path']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else {
        await Process.run('xdg-open', [File(path).parent.path]);
      }
    } catch (_) {}
  }

  /// Ordner im Dateimanager öffnen.
  static Future<void> openFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else {
        await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [path]);
      }
    } catch (_) {}
  }

  /// Feste Webadresse im Standardbrowser öffnen (nur `https://`).
  static Future<void> openUrl(String url) async {
    if (!url.startsWith('https://')) return;
    try {
      if (Platform.isWindows) {
        await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
      } else {
        await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [url]);
      }
    } catch (_) {}
  }
}
