import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session.dart';

/// Woher die Publikumsbewertung ("CommunityRating") stammt. Jellyfin liefert nur die
/// Zahl – die Quelle hängt davon ab, welcher Metadaten-Anbieter in der Bibliothek
/// zuerst steht: TheMovieDb (Standard) oder OMDb (dann ist es die IMDb-Wertung).
enum RatingSource { tmdb, imdb, unknown }

/// Namen der Anbieter, wie Jellyfin sie in den Bibliothekseinstellungen führt.
const _tmdbFetcher = 'TheMovieDb';
const _omdbFetcher = 'The Open Movie Database';

/// Quelle je Elementtyp ("Movie", "Series", "Episode" …) aus `/Library/VirtualFolders`.
/// Sind mehrere Bibliotheken eines Typs verschieden eingestellt, ist die Quelle unbekannt
/// (welche Bibliothek ein Titel hat, verrät Jellyfin der App nicht ohne Weiteres).
Map<String, RatingSource> ratingSourcesFromFolders(List<Json> folders) {
  final result = <String, RatingSource>{};
  for (final folder in folders) {
    final types = (folder['LibraryOptions'] as Map?)?['TypeOptions'] as List? ?? const [];
    for (final t in types.whereType<Map>()) {
      final type = t['Type'] as String?;
      if (type == null) continue;
      final enabled = {for (final f in (t['MetadataFetchers'] as List? ?? const [])) '$f'};
      final order = [for (final f in (t['MetadataFetcherOrder'] as List? ?? const [])) '$f'];
      // Der erste eingeschaltete der beiden Anbieter setzt die Bewertung.
      final first = [
        ...order,
        ...enabled,
      ].where((f) => enabled.contains(f) && (f == _tmdbFetcher || f == _omdbFetcher)).firstOrNull;
      final source = switch (first) {
        _tmdbFetcher => RatingSource.tmdb,
        _omdbFetcher => RatingSource.imdb,
        _ => RatingSource.unknown,
      };
      result[type] = result[type] == null || result[type] == source ? source : RatingSource.unknown;
    }
  }
  return result;
}

/// Quelle für ein Element. Ohne Eintrag für den Typ gilt Jellyfins Standard (TheMovieDb);
/// konnte die App die Einstellungen nicht lesen (kein Administrator), ist sie unbekannt.
RatingSource ratingSourceFor(BaseItem item, Map<String, RatingSource>? sources) {
  if (sources == null) return RatingSource.unknown;
  return sources[item.type] ?? (item.isEpisode ? sources['Series'] : null) ?? RatingSource.tmdb;
}

/// Einmal je Anmeldung gelesen; `null` = unbekannt (kein Administrator oder Fehler).
final ratingSourcesProvider = FutureProvider<Map<String, RatingSource>?>((ref) async {
  final api = ref.watch(apiProvider);
  try {
    final user = await api.getCurrentUser();
    if ((user['Policy'] as Map?)?['IsAdministrator'] != true) return null;
    return ratingSourcesFromFolders(await api.getVirtualFolders());
  } catch (_) {
    return null;
  }
});
