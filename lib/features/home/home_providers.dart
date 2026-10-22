import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/session.dart';

enum SectionStyle { poster, landscape }

class HomeSection {
  const HomeSection(this.title, this.items, this.style);

  final String title;
  final List<BaseItem> items;
  final SectionStyle style;
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
    if (resume.isNotEmpty) HomeSection('Weiterschauen', resume, SectionStyle.landscape),
    if (nextUp.isNotEmpty) HomeSection('Als Nächstes', nextUp, SectionStyle.landscape),
    for (var i = 0; i < libraries.length; i++)
      if (latest[i].isNotEmpty) HomeSection('Neu in ${libraries[i].name}', latest[i], SectionStyle.poster),
    if (favorites.isNotEmpty) HomeSection('Deine Favoriten', favorites, SectionStyle.poster),
  ]);
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
