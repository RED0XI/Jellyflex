import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/seasons.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../l10n/strings.dart';

enum SectionStyle { poster, landscape }

class HomeSection {
  const HomeSection(this.title, this.items, this.style, {this.group = ''});

  final String title;
  final List<BaseItem> items;
  final SectionStyle style;

  /// Art der Reihe (siehe [HomeRows]) – für Reihenfolge und Ausblenden.
  final String group;
}

class HomeData {
  const HomeData(this.libraries, this.sections);

  final List<BaseItem> libraries;
  final List<HomeSection> sections;
}

/// Bibliotheken mit Filmen oder Serien (Musik etc. wird vorerst ausgeblendet).
bool isVideoLibrary(BaseItem view) => view.collectionType == 'movies' || view.collectionType == 'tvshows';

Future<List<BaseItem>> _safe(Future<List<BaseItem>> future) async {
  try {
    return await future;
  } catch (_) {
    return const [];
  }
}

final libraryViewsProvider = FutureProvider.autoDispose<List<BaseItem>>((ref) async {
  final views = await ref.watch(apiProvider).getUserViews();
  return views.where(isVideoLibrary).toList();
});

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final api = ref.watch(apiProvider);
  final libraries = await ref.watch(libraryViewsProvider.future);

  final resumeFuture = _safe(api.getResume());
  final nextUpFuture = _safe(api.getNextUp());
  final latestFuture = Future.wait(libraries.map((lib) => _safe(api.getLatest(lib.id))));
  final favoritesFuture = _safe(api.getFavorites());

  final resume = await resumeFuture;
  final nextUp = await nextUpFuture;
  final latest = await latestFuture;
  final favorites = await favoritesFuture;

  return HomeData(libraries, [
    if (resume.isNotEmpty) HomeSection(tr.continueWatching, resume, SectionStyle.landscape, group: 'resume'),
    if (nextUp.isNotEmpty) HomeSection(tr.nextUp, nextUp, SectionStyle.landscape, group: 'nextUp'),
    for (var i = 0; i < libraries.length; i++)
      if (latest[i].isNotEmpty)
        HomeSection(tr.newIn(libraries[i].name), latest[i], SectionStyle.poster, group: 'latest'),
    if (favorites.isNotEmpty) HomeSection(tr.yourFavorites, favorites, SectionStyle.poster, group: 'favorites'),
  ]);
});

/// Zusätzliche Reihen zum Stöbern: Empfehlungen, Sammlungen und drei
/// zufällige Genres. Lädt getrennt, damit die Startseite schneller erscheint.
final discoverProvider = FutureProvider.autoDispose<List<HomeSection>>((ref) async {
  final api = ref.watch(apiProvider);
  final recommendationsFuture = api.getRecommendations().catchError((_) => <Recommendation>[]);
  final collectionsFuture = _safe(api.getCollections());
  final genresFuture = api.getGenres(null).catchError((_) => <String>[]);

  final recommendations = await recommendationsFuture;
  final collections = await collectionsFuture;
  final genres = [...await genresFuture]..shuffle();
  final genreRows = await Future.wait(genres.take(3).map((g) async => (g, await _safe(api.getByGenre(g)))));

  return [
    for (final r in recommendations)
      if (r.items.length >= 3) HomeSection(r.title, r.items, SectionStyle.poster, group: 'recommendations'),
    if (collections.isNotEmpty) HomeSection(tr.collections, collections, SectionStyle.poster, group: 'collections'),
    for (final (genre, items) in genreRows)
      if (items.length >= 4) HomeSection(genre, items, SectionStyle.poster, group: 'genres'),
  ];
});

/// Aktuelle Saison (Halloween, Weihnachten …), falls eingeschaltet.
final activeSeasonProvider = Provider.autoDispose<Season?>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.seasonalThemes))) return null;
  return currentSeason();
});

/// Reihe zur Saison: passende Genres plus Titel mit Stichwörtern ("Weihnacht" …).
final seasonalSectionProvider = FutureProvider.autoDispose<HomeSection?>((ref) async {
  final season = ref.watch(activeSeasonProvider);
  if (season == null) return null;
  final info = seasonInfo[season]!;
  final api = ref.watch(apiProvider);
  final results = await Future.wait([
    if (info.genres.isNotEmpty) _safe(api.getByGenre(info.genres.join('|'), limit: 30)),
    for (final word in info.keywords) _safe(api.search(word, limit: 12)),
  ]);
  final seen = <String>{};
  // Stichwort-Treffer zuerst (sie passen am besten), dann die Genres gemischt.
  final byKeyword = results.skip(info.genres.isEmpty ? 0 : 1).expand((r) => r);
  final byGenre = info.genres.isEmpty ? <BaseItem>[] : ([...results.first]..shuffle());
  final items = [
    for (final item in [...byKeyword, ...byGenre])
      if ((item.isMovie || item.isSeries) && seen.add(item.id)) item,
  ].take(24).toList();
  if (items.length < 3) return null;
  return HomeSection('${info.emoji}  ${season.title}', items, SectionStyle.poster, group: 'seasonal');
});

/// URL des Profilbilds des angemeldeten Benutzers (oder `null`).
final userImageProvider = FutureProvider.autoDispose<String?>((ref) async {
  final api = ref.watch(apiProvider);
  final user = await api.getCurrentUser();
  return api.userImageUrl(user['Id'] as String, user['PrimaryImageTag'] as String?);
});

final featuredProvider = FutureProvider.autoDispose<List<BaseItem>>((ref) {
  return ref.watch(apiProvider).getFeatured();
});
