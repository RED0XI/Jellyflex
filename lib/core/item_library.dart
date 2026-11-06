import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_api.dart';
import 'platform/app_paths.dart';
import 'session.dart';
import 'settings.dart';

/// Merkt sich, zu welcher Bibliothek ein Titel gehört – für die Untertitel-Regeln je Bibliothek.
/// Jellyfin nennt das beim Titel selbst nicht; die Antwort wird gemerkt, damit sie auch offline
/// gilt (Downloads) und nicht jeder Start eine Anfrage kostet. Serien zählen als Ganzes.
class ItemLibraries {
  ItemLibraries._(this._fileOverride);

  /// Nur für Tests: eigene Datei.
  ItemLibraries.forFile(File file) : this._(file);

  /// Speicher der App. Tests ersetzen ihn durch eine Temp-Datei (nie die echte).
  static ItemLibraries instance = ItemLibraries._(null);

  /// Mehr Titel merkt sich die App nicht (die ältesten fallen heraus).
  static const _maxEntries = 2000;

  final File? _fileOverride;
  Map<String, String>? _cache;

  File get _file => _fileOverride ?? File(AppPaths.join(appDataDir.path, 'item_libraries.json'));

  Map<String, String> _load() {
    if (_cache != null) return _cache!;
    try {
      if (_file.existsSync()) {
        final decoded = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
        return _cache = decoded.map((k, v) => MapEntry(k, '$v'));
      }
    } catch (_) {
      // Beschädigt – neu anfangen.
    }
    return _cache = {};
  }

  /// Schon bekannte Bibliothek (ohne Anfrage).
  String? cached({required String itemId, String? seriesId}) => _load()[seriesId ?? itemId];

  /// Bibliothek des Titels; `null`, wenn unbekannt (z. B. offline und noch nie nachgesehen).
  Future<String?> resolve(JellyfinApi api, {required String itemId, String? seriesId}) async {
    final known = cached(itemId: itemId, seriesId: seriesId);
    if (known != null) return known;
    try {
      final library = await api.getLibraryId(itemId);
      if (library != null) _remember(seriesId ?? itemId, library);
      return library;
    } catch (_) {
      return null;
    }
  }

  void _remember(String key, String library) {
    final all = _load();
    all[key] = library;
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

/// Bibliothek eines Titels für die Oberfläche. Solange keine Bibliothek eigene Regeln hat,
/// wird gar nicht erst nachgefragt.
final itemLibraryProvider = FutureProvider.autoDispose.family<String?, ({String itemId, String? seriesId})>((
  ref,
  item,
) async {
  if (!ref.watch(settingsProvider.select((s) => s.subtitleLibraries.isNotEmpty))) return null;
  return ItemLibraries.instance.resolve(ref.watch(apiProvider), itemId: item.itemId, seriesId: item.seriesId);
});
