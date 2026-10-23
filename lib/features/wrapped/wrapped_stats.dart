import '../../core/models.dart';

/// Eine Person mit Anzahl der Titel, in denen man sie gesehen hat.
class WrappedPerson {
  const WrappedPerson(this.id, this.name, this.imageTag, this.count);

  final String id;
  final String name;
  final String? imageTag;
  final int count;
}

/// Jahresrückblick: aus den gesehenen Titeln eines Jahres berechnet.
///
/// Jellyfin merkt sich pro Titel nur, wann er *zuletzt* gesehen wurde – jeder
/// Film bzw. jede Folge zählt also einmal, im Jahr des letzten Ansehens.
/// Gezählt wird nur das eigene Profil (die Anfragen laufen mit der eigenen
/// Benutzer-ID). Nur als gesehen *markierte* Titel zählen nicht (siehe
/// [bulkMarkedIds]).
class WrappedStats {
  const WrappedStats({
    required this.year,
    required this.totalMinutes,
    required this.movies,
    required this.episodes,
    required this.series,
    required this.topGenres,
    required this.topSeries,
    required this.topSeriesEpisodes,
    required this.topActor,
    required this.bingeDay,
    required this.bingeMinutes,
    required this.hourHistogram,
    required this.longestMovie,
    this.markedOnly = 0,
  });

  final int year;
  final int totalMinutes;
  final int movies;
  final int episodes;
  final int series;

  /// Genre → Minuten, absteigend (höchstens 5).
  final List<(String, int)> topGenres;
  final BaseItem? topSeries;
  final int topSeriesEpisodes;
  final WrappedPerson? topActor;

  /// Tag mit den meisten geschauten Minuten.
  final DateTime? bingeDay;
  final int bingeMinutes;

  /// Anzahl gesehener Titel je Stunde (0–23, Ortszeit des letzten Ansehens).
  final List<int> hourHistogram;
  final BaseItem? longestMovie;

  /// Titel des Jahres, die nur als gesehen markiert wurden (nicht mitgezählt).
  final int markedOnly;

  bool get isEmpty => movies + episodes == 0;

  /// Stunde, zu der am meisten geschaut wurde.
  int? get favoriteHour {
    if (hourHistogram.every((n) => n == 0)) return null;
    var best = 0;
    for (var h = 1; h < 24; h++) {
      if (hourHistogram[h] > hourHistogram[best]) best = h;
    }
    return best;
  }
}

DateTime? _lastPlayed(BaseItem item) {
  final raw = item.userData.raw['LastPlayedDate'];
  return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
}

int _minutes(BaseItem item) => item.runtime?.inMinutes ?? 0;

/// Titel, die nur als gesehen *markiert* wurden – z. B. eine ganze Staffel oder
/// Sammlung auf einmal – statt wirklich geschaut. Erkennbar daran, dass mehrere
/// Titel fast denselben Zeitpunkt "zuletzt gesehen" haben: Wer schaut, braucht
/// zwischen zwei Titeln mindestens die Laufzeit.
///
/// Regel: Titel, deren Zeitpunkte jeweils höchstens 3 Minuten auseinander
/// liegen, bilden eine Gruppe. Ab 3 Titeln (oder 2 innerhalb einer Minute) gilt
/// die Gruppe als markiert.
Set<String> bulkMarkedIds(Iterable<BaseItem> items) {
  final dated = [
    for (final item in items)
      if (_lastPlayed(item) case final played?) (item.id, played),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final marked = <String>{};
  var group = <(String, DateTime)>[];
  void flush() {
    final quickPair = group.length == 2 && group[1].$2.difference(group[0].$2) < const Duration(minutes: 1);
    if (group.length >= 3 || quickPair) marked.addAll(group.map((e) => e.$1));
    group = [];
  }

  for (final entry in dated) {
    if (group.isNotEmpty && entry.$2.difference(group.last.$2) > const Duration(minutes: 3)) flush();
    group.add(entry);
  }
  flush();
  return marked;
}

/// Berechnet den Rückblick für [year] aus gesehenen Filmen und Folgen.
/// [seriesById]: die Serien zu den Folgen (für Genres, Besetzung und Bilder).
WrappedStats computeWrapped({
  required int year,
  required List<BaseItem> playedMovies,
  required List<BaseItem> playedEpisodes,
  Map<String, BaseItem> seriesById = const {},
}) {
  bool inYear(BaseItem i) => _lastPlayed(i)?.year == year;
  final yearMovies = playedMovies.where((i) => i.isMovie && inYear(i)).toList();
  final yearEpisodes = playedEpisodes.where((i) => i.isEpisode && inYear(i)).toList();
  // Nur markierte (nicht geschaute) Titel verfälschen Stunden und Marathon-Tag.
  final marked = bulkMarkedIds([...yearMovies, ...yearEpisodes]);
  final movies = yearMovies.where((i) => !marked.contains(i.id)).toList();
  final episodes = yearEpisodes.where((i) => !marked.contains(i.id)).toList();
  final all = [...movies, ...episodes];

  final total = all.fold(0, (sum, i) => sum + _minutes(i));

  // Genres nach Minuten; Folgen erben die Genres ihrer Serie.
  final genreMinutes = <String, int>{};
  for (final item in all) {
    final genres = item.genres.isNotEmpty ? item.genres : (seriesById[item.seriesId]?.genres ?? const <String>[]);
    for (final g in genres) {
      genreMinutes[g] = (genreMinutes[g] ?? 0) + _minutes(item);
    }
  }
  final topGenres = (genreMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => (e.key, e.value))
      .toList();

  // Serie mit den meisten Folgen.
  final perSeries = <String, int>{};
  for (final e in episodes) {
    final id = e.seriesId;
    if (id != null) perSeries[id] = (perSeries[id] ?? 0) + 1;
  }
  final topSeriesEntry = (perSeries.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;

  // Schauspieler: in Filmen und in den Serien (einmal je Serie) gezählt.
  final actorCount = <String, int>{};
  final actors = <String, Person>{};
  void countPeople(Iterable<Person> people) {
    for (final p in people.where((p) => p.type == 'Actor')) {
      actorCount[p.id] = (actorCount[p.id] ?? 0) + 1;
      actors[p.id] = p;
    }
  }

  for (final m in movies) {
    countPeople(m.people);
  }
  for (final id in perSeries.keys) {
    countPeople(seriesById[id]?.people ?? const []);
  }
  final topActorEntry = (actorCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;
  final topActor = topActorEntry == null
      ? null
      : WrappedPerson(
          topActorEntry.key,
          actors[topActorEntry.key]!.name,
          actors[topActorEntry.key]!.primaryImageTag,
          topActorEntry.value,
        );

  // Größter Serien-/Film-Marathon an einem Tag.
  final perDay = <DateTime, int>{};
  final hours = List.filled(24, 0);
  for (final item in all) {
    final played = _lastPlayed(item)!;
    final day = DateTime(played.year, played.month, played.day);
    perDay[day] = (perDay[day] ?? 0) + _minutes(item);
    hours[played.hour]++;
  }
  final binge = (perDay.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;

  final longest = movies.isEmpty
      ? null
      : (movies.toList()..sort((a, b) => (b.runTimeTicks ?? 0).compareTo(a.runTimeTicks ?? 0))).first;

  return WrappedStats(
    year: year,
    totalMinutes: total,
    movies: movies.length,
    episodes: episodes.length,
    series: perSeries.length,
    topGenres: topGenres,
    topSeries: topSeriesEntry == null ? null : seriesById[topSeriesEntry.key],
    topSeriesEpisodes: topSeriesEntry?.value ?? 0,
    topActor: topActor,
    bingeDay: binge?.key,
    bingeMinutes: binge?.value ?? 0,
    hourHistogram: hours,
    longestMovie: longest,
    markedOnly: marked.length,
  );
}
