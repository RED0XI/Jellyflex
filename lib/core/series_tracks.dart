import 'dart:convert';
import 'dart:io';

import 'settings.dart';
import 'platform/app_paths.dart';

/// Merkt sich je Serie (und Konto) die zuletzt gewählte Ton- und Untertitelsprache –
/// wer eine Serie auf Japanisch mit Untertiteln schaut, bekommt die nächste Folge
/// genauso. Gespeichert werden nur Sprachcodes, unter `%APPDATA%\Jellyflex\series_tracks.json`.
class SeriesTracks {
  SeriesTracks._(this._fileOverride);

  /// Nur für Tests: eigene Datei.
  SeriesTracks.forFile(File file) : this._(file);

  /// Speicher der App. Tests ersetzen ihn durch eine Temp-Datei (nie die echte).
  static SeriesTracks instance = SeriesTracks._(null);

  /// Mehr Serien merkt sich die App nicht (die ältesten fallen heraus).
  static const _maxEntries = 500;

  final File? _fileOverride;
  Map<String, Map<String, String>>? _cache;

  File get _file => _fileOverride ?? File(AppPaths.join(appDataDir.path, 'series_tracks.json'));

  Map<String, Map<String, String>> _load() {
    if (_cache != null) return _cache!;
    try {
      if (_file.existsSync()) {
        final decoded = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
        return _cache = {
          for (final e in decoded.entries)
            if (e.value is Map) e.key: (e.value as Map).map((k, v) => MapEntry('$k', '$v')),
        };
      }
    } catch (_) {
      // Beschädigt – neu anfangen.
    }
    return _cache = {};
  }

  static String _key(String account, String seriesId) => '$account|$seriesId';

  /// Gemerkter Bildausschnitt im Player ("fit", "fill" oder ein Zoomfaktor wie "1.25").
  String? zoom(String account, String seriesId) => _load()[_key(account, seriesId)]?['zoom'];

  void setZoom(String account, String seriesId, String zoom) => _set(account, seriesId, 'zoom', zoom);

  /// Gemerkte Tonsprache (z. B. "jpn") und Untertitel ("ger" bzw. [subtitlesOff]).
  ({String? audio, String? subtitle}) get(String account, String seriesId) {
    final entry = _load()[_key(account, seriesId)];
    return (audio: entry?['audio'], subtitle: entry?['subtitle']);
  }

  void setAudio(String account, String seriesId, String language) => _set(account, seriesId, 'audio', language);

  /// [language] = Sprachcode oder [subtitlesOff].
  void setSubtitle(String account, String seriesId, String language) => _set(account, seriesId, 'subtitle', language);

  void _set(String account, String seriesId, String field, String value) {
    final all = _load();
    final key = _key(account, seriesId);
    // Neu einsortieren: zuletzt Benutztes steht am Ende.
    final entry = all.remove(key) ?? {};
    if (entry[field] == value && all.length < _maxEntries) {
      all[key] = entry;
      return;
    }
    entry[field] = value;
    all[key] = entry;
    while (all.length > _maxEntries) {
      all.remove(all.keys.first);
    }
    try {
      _file.parent.createSync(recursive: true);
      final tmp = File('${_file.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(all), flush: true);
      tmp.renameSync(_file.path);
    } catch (_) {
      // Nicht gespeichert – gilt trotzdem für diese Sitzung.
    }
  }
}
