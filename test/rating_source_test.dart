import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/rating_source.dart';

Json _folder(String type, {List<String>? enabled, List<String>? order}) => {
  'LibraryOptions': {
    'TypeOptions': [
      {'Type': type, 'MetadataFetchers': ?enabled, 'MetadataFetcherOrder': ?order},
    ],
  },
};

void main() {
  test('Erster eingeschalteter Anbieter bestimmt die Quelle', () {
    final sources = ratingSourcesFromFolders([
      _folder(
        'Movie',
        enabled: ['TheMovieDb', 'The Open Movie Database'],
        order: ['The Open Movie Database', 'TheMovieDb'],
      ),
      _folder('Series', enabled: ['TheMovieDb'], order: ['The Open Movie Database', 'TheMovieDb']),
      _folder('Episode', enabled: ['TheTVDB'], order: ['TheTVDB']),
      _folder('Series', enabled: ['TheMovieDb'], order: ['TheMovieDb']),
    ]);
    expect(sources['Movie'], RatingSource.imdb);
    expect(sources['Series'], RatingSource.tmdb, reason: 'OMDb steht vorne, ist aber aus');
    expect(sources['Episode'], RatingSource.unknown);
  });

  test('Verschieden eingestellte Bibliotheken: neutraler Stern', () {
    final sources = ratingSourcesFromFolders([
      _folder('Movie', enabled: ['The Open Movie Database', 'TheMovieDb'], order: ['The Open Movie Database']),
      _folder('Movie', enabled: ['TheMovieDb'], order: ['TheMovieDb']),
    ]);
    expect(sources['Movie'], RatingSource.unknown);
  });

  test('Ohne Einstellungen: Jellyfin-Standard, ohne Leserecht: unbekannt', () {
    BaseItem item(String type) => BaseItem({'Id': 'x', 'Type': type});
    final sources = ratingSourcesFromFolders([
      _folder('Series', enabled: ['The Open Movie Database'], order: const []),
    ]);
    expect(ratingSourceFor(item('Movie'), sources), RatingSource.tmdb);
    expect(ratingSourceFor(item('Episode'), sources), RatingSource.imdb, reason: 'Folgen wie ihre Serie');
    expect(ratingSourceFor(item('Movie'), null), RatingSource.unknown);
  });
}
