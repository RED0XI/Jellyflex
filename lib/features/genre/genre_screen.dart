import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';

/// Reihen einer Genre-Seite: am besten bewertet, neu, noch nicht gesehen, Serien.
typedef GenreRows = ({List<BaseItem> topRated, List<BaseItem> newest, List<BaseItem> unwatched, List<BaseItem> series});

final genreRowsProvider = FutureProvider.autoDispose.family<GenreRows, String>((ref, genre) async {
  final api = ref.watch(apiProvider);
  final (topRated, newest, unwatched, series) = await (
    api.getGenreItems(genre, includeItemTypes: 'Movie', sortBy: 'CommunityRating', descending: true),
    api.getGenreItems(genre, sortBy: 'DateCreated', descending: true),
    api.getGenreItems(genre, includeItemTypes: 'Movie', unplayedOnly: true),
    api.getGenreItems(genre, includeItemTypes: 'Series', sortBy: 'CommunityRating', descending: true),
  ).wait;
  return (topRated: topRated, newest: newest, unwatched: unwatched, series: series);
});

/// Je Genre ein passendes Hintergrundbild für die Kacheln – aus einer einzigen Anfrage
/// (zufällige Titel mit Hintergrundbild), damit die Suche schnell bleibt.
final genreArtProvider = FutureProvider.autoDispose<Map<String, BaseItem>>((ref) async {
  final items = await ref.watch(apiProvider).getRandomWithBackdrops();
  final art = <String, BaseItem>{};
  for (final item in items) {
    for (final g in item.genres) {
      art.putIfAbsent(g, () => item);
    }
  }
  return art;
});

/// Eigene Seite für ein Genre: großes Bild, "Zufällig abspielen", dann Reihen.
class GenreScreen extends ConsumerStatefulWidget {
  const GenreScreen({super.key, required this.genre});

  final String genre;

  @override
  ConsumerState<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends ConsumerState<GenreScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(genreRowsProvider(widget.genre));
    final api = ref.watch(apiProvider);
    final size = MediaQuery.sizeOf(context);
    final posterHeight = kPosterWidth * 1.5 + kCardTextHeight;

    return Scaffold(
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: tr.contentCouldNotLoad(e),
          onRetry: () => ref.invalidate(genreRowsProvider(widget.genre)),
        ),
        data: (r) {
          final all = [...r.topRated, ...r.newest, ...r.series];
          final hero = all.where((i) => Images.backdrops(i).isNotEmpty).firstOrNull ?? all.firstOrNull;
          final heroImage = hero == null ? null : Images.backdrop(hero);
          Widget row(String title, List<BaseItem> items) => items.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: MediaRow(
                    title: title,
                    itemCount: items.length,
                    height: posterHeight,
                    itemBuilder: (context, i) => PosterCard(item: items[i]),
                  ),
                );
          return Stack(
            children: [
              // Großes Bild oben, nach unten und links in den Hintergrund auslaufend.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.7,
                child: heroImage == null
                    ? const SizedBox.shrink()
                    : JfImage(
                        url: api.imageUrlOrNull(heroImage, maxWidth: 1920),
                        blurHash: heroImage.blurHash,
                        alignment: Alignment.topCenter,
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.55, 1],
                      colors: [
                        AppColors.background,
                        AppColors.background.withValues(alpha: 0.55),
                        AppColors.background.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, 0.5, 1],
                      colors: [
                        AppColors.background.withValues(alpha: 0.9),
                        AppColors.background.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SmoothScroll(
                controller: _scroll,
                builder: (context, physics) => CustomScrollView(
                  controller: _scroll,
                  physics: physics,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(kPageGutter, size.height * 0.24, kPageGutter, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.genre.toUpperCase(),
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.4,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.genre,
                              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                            ),
                            if (hero != null) ...[
                              const SizedBox(height: 6),
                              Text(tr.genreHeroCaption(hero.name), style: TextStyle(color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 26),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                PrimaryButton(
                                  label: tr.shufflePlay,
                                  icon: Icons.shuffle_rounded,
                                  onPressed: () =>
                                      playShuffled(context, includeItemTypes: 'Movie', genre: widget.genre),
                                ),
                                GlassButton(
                                  label: tr.unwatchedOnly,
                                  icon: Icons.visibility_off_outlined,
                                  onPressed: () => playShuffled(
                                    context,
                                    includeItemTypes: 'Movie',
                                    genre: widget.genre,
                                    unplayedOnly: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          row(tr.genreTopRated, r.topRated),
                          row(tr.genreNewest, r.newest),
                          row(tr.genreUnwatched, r.unwatched),
                          row(tr.shows, r.series),
                          if (all.isEmpty)
                            EmptyState(icon: Icons.theater_comedy_outlined, title: tr.nothingFoundFor(widget.genre)),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  ],
                ),
              ),
              TopScrim(scroll: _scroll),
            ],
          );
        },
      ),
    );
  }
}

/// Große Kacheln je Genre mit Hintergrundbild eines passenden Titels; Klick öffnet die Genre-Seite.
class GenreTiles extends ConsumerWidget {
  const GenreTiles({super.key, required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(genreArtProvider).value ?? const <String, BaseItem>{};
    return LayoutBuilder(
      builder: (context, box) {
        // So viele Spalten wie passen (Kacheln 240–320 breit).
        final columns = (box.maxWidth / 280).floor().clamp(2, 6);
        const gap = 14.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, g) in genres.indexed) _GenreTile(genre: g, item: art[g], width: width, colorSeed: i),
          ],
        );
      },
    );
  }
}

class _GenreTile extends ConsumerWidget {
  const _GenreTile({required this.genre, required this.item, required this.width, required this.colorSeed});

  final String genre;
  final BaseItem? item;
  final double width;
  final int colorSeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final image = item == null ? null : Images.backdrop(item!);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Ohne Bild: Verlauf aus Akzentfarben, je Genre etwas anders.
    final tint = HSLColor.fromColor(AppColors.accent)
        .withHue((HSLColor.fromColor(AppColors.accent).hue + colorSeed * 37) % 360)
        .toColor();
    return Focusable(
      semanticLabel: genre,
      onTap: () => context.push('/genre/${Uri.encodeComponent(genre)}'),
      builder: (context, hovered) => AnimatedScale(
        scale: hovered ? 1.04 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: width * 0.46,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovered ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.06),
              width: hovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: hovered ? 0.5 : 0.25),
                blurRadius: hovered ? 22 : 10,
              ),
            ],
            gradient: LinearGradient(colors: [tint, AppColors.surfaceHigh]),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                AnimatedScale(
                  scale: hovered ? 1.08 : 1,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  child: JfImage(
                    url: api.imageUrlOrNull(
                      image,
                      fillWidth: (width * dpr).round(),
                      fillHeight: (width * 0.46 * dpr).round(),
                    ),
                    blurHash: image.blurHash,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [Colors.black.withValues(alpha: 0.85), tint.withValues(alpha: 0.25)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Text(
                  genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
