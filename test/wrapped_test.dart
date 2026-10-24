import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/features/wrapped/wrapped_stats.dart';

const _minute = 60 * 10000000;

BaseItem _movie(
  String id,
  int minutes,
  String played, {
  List<String> genres = const [],
  List<String> actors = const [],
}) => BaseItem({
  'Id': id,
  'Name': id,
  'Type': 'Movie',
  'RunTimeTicks': minutes * _minute,
  'Genres': genres,
  'People': [
    for (final a in actors) {'Id': a, 'Name': a, 'Type': 'Actor'},
  ],
  'UserData': {'Played': true, 'LastPlayedDate': played},
});

BaseItem _episode(String id, String seriesId, int minutes, String played) => BaseItem({
  'Id': id,
  'Name': id,
  'Type': 'Episode',
  'SeriesId': seriesId,
  'RunTimeTicks': minutes * _minute,
  'UserData': {'Played': true, 'LastPlayedDate': played},
});

void main() {
  test('Jahresrückblick: Zeit, Genres, Serie, Schauspieler, Marathon', () {
    final stats = computeWrapped(
      year: 2026,
      playedMovies: [
        _movie('a', 120, '2026-03-01T20:00:00Z', genres: ['Drama'], actors: ['lena', 'tom']),
        _movie('b', 90, '2026-03-02T21:00:00Z', genres: ['Komödie', 'Drama'], actors: ['lena']),
        _movie('alt', 100, '2025-12-30T20:00:00Z', genres: ['Horror'], actors: ['tom']), // anderes Jahr
      ],
      playedEpisodes: [
        for (var i = 0; i < 5; i++) _episode('n$i', 'nordlicht', 45, '2026-07-04T1$i:00:00Z'),
        _episode('s1', 'signal', 50, '2026-08-01T22:00:00Z'),
      ],
      seriesById: {
        'nordlicht': BaseItem({
          'Id': 'nordlicht',
          'Name': 'Nordlicht',
          'Type': 'Series',
          'Genres': ['Krimi'],
          'People': [
            {'Id': 'lena', 'Name': 'lena', 'Type': 'Actor'},
          ],
        }),
        'signal': BaseItem({
          'Id': 'signal',
          'Name': 'Signal',
          'Type': 'Series',
          'Genres': ['Sci-Fi'],
        }),
      },
    );
    expect(stats.movies, 2);
    expect(stats.episodes, 6);
    expect(stats.series, 2);
    expect(stats.totalMinutes, 120 + 90 + 5 * 45 + 50);
    expect(stats.topGenres.first, ('Krimi', 225));
    expect(stats.topGenres.map((g) => g.$1), containsAll(['Drama', 'Komödie', 'Sci-Fi']));
    expect(stats.topSeries?.name, 'Nordlicht');
    expect(stats.topSeriesEpisodes, 5);
    expect(stats.topActor?.name, 'lena');
    expect(stats.topActor?.count, 3);
    expect(stats.bingeMinutes, 225);
    expect(stats.bingeDay?.day, 4);
    expect(stats.longestMovie?.id, 'a');
    expect(stats.isEmpty, isFalse);
    // Bilder: Folgen zeigen ihre Serie, meistgeschaut zuerst, jeder Titel einmal.
    expect(stats.titles.map((t) => t.id), ['nordlicht', 'a', 'b', 'signal']);
    expect(stats.genreTitle?.id, 'nordlicht');
    expect(stats.bingeTitles.map((t) => t.id), ['nordlicht']);
    expect(stats.actorTitle?.id, 'nordlicht', reason: 'lena spielt auch in Nordlicht');
    expect(stats.hourTitle, isNotNull);
  });

  test('Leeres Jahr', () {
    final stats = computeWrapped(year: 2020, playedMovies: const [], playedEpisodes: const []);
    expect(stats.isEmpty, isTrue);
    expect(stats.favoriteHour, isNull);
  });

  test('Nur als gesehen markierte Titel zählen nicht (z. B. ganze Staffel auf einmal)', () {
    final stats = computeWrapped(
      year: 2026,
      playedMovies: [
        _movie('echt', 110, '2026-02-10T20:00:00Z'),
        // Zwei Filme innerhalb von Sekunden: markiert, nicht geschaut.
        _movie('m1', 120, '2026-02-11T09:00:00Z'),
        _movie('m2', 130, '2026-02-11T09:00:20Z'),
      ],
      playedEpisodes: [
        // Eine ganze Staffel (10 Folgen) in derselben Minute markiert …
        for (var i = 0; i < 10; i++) _episode('bulk$i', 'nordlicht', 45, '2026-05-01T12:00:0${i % 10}Z'),
        // … und drei wirklich geschaute Folgen hintereinander.
        _episode('w1', 'signal', 50, '2026-05-02T20:00:00Z'),
        _episode('w2', 'signal', 50, '2026-05-02T20:52:00Z'),
        _episode('w3', 'signal', 50, '2026-05-02T21:45:00Z'),
      ],
    );
    expect(stats.movies, 1);
    expect(stats.episodes, 3);
    expect(stats.markedOnly, 12);
    expect(stats.totalMinutes, 110 + 3 * 50);
    expect(stats.bingeMinutes, 150, reason: 'Marathon-Tag zählt nur Geschautes');
  });
}
