import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/backdrop_slideshow.dart';
import '../../widgets/focusable.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../details/details_screen.dart';
import '../../l10n/strings.dart';

/// Filme und Serien einer Person auf dem Server.
final personItemsProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, id) {
  return ref.watch(apiProvider).getPersonItems(id);
});

/// Einzelne Folgen, in denen die Person auftritt (z. B. Gastrollen).
final personEpisodesProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, id) async {
  try {
    return await ref.watch(apiProvider).getPersonItems(id, includeItemTypes: 'Episode', limit: 40);
  } catch (_) {
    return const [];
  }
});

enum _Filter { all, movies, series }

/// Schauspieler-/Personenseite: Foto, Lebensdaten, Biografie und alles,
/// was es von dieser Person auf dem Server gibt.
class PersonScreen extends ConsumerStatefulWidget {
  const PersonScreen({super.key, required this.personId});

  final String personId;

  @override
  ConsumerState<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends ConsumerState<PersonScreen> {
  final _scroll = ScrollController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personAsync = ref.watch(itemProvider(widget.personId));
    return Scaffold(
      body: personAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(message: tr.personCouldNotLoad(e), onRetry: () => ref.invalidate(itemProvider(widget.personId))),
        data: (person) => _buildContent(context, person),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BaseItem person) {
    final size = MediaQuery.sizeOf(context);
    final itemsAsync = ref.watch(personItemsProvider(person.id));
    final items = itemsAsync.value ?? const <BaseItem>[];
    final episodes = ref.watch(personEpisodesProvider(person.id)).value ?? const <BaseItem>[];
    final movies = items.where((i) => i.isMovie).toList();
    final series = items.where((i) => i.isSeries).toList();
    final shown = switch (_filter) {
      _Filter.all => items,
      _Filter.movies => movies,
      _Filter.series => series,
    };
    // Hintergrund: Bilder aus den Filmen/Serien der Person.
    final backdrops = [for (final i in items) ?Images.backdrop(i)].take(6).toList();

    return Stack(
      children: [
        if (backdrops.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.7,
            child: Opacity(opacity: 0.45, child: BackdropSlideshow(images: backdrops)),
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
                stops: [0, 0.55, 1],
                colors: [
                  AppColors.background,
                  AppColors.background.withAlpha(0xB3),
                  AppColors.background.withAlpha(0x80),
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
                stops: [0, 0.6, 1],
                colors: [
                  AppColors.background.withAlpha(0xE6),
                  AppColors.background.withAlpha(0x80),
                  AppColors.background.withAlpha(0x20),
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
                  padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 64, kPageGutter, 36),
                  child: _Header(person: person, movieCount: movies.length, seriesCount: series.length),
                ),
              ),
              if (itemsAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (items.isEmpty && episodes.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: kPageGutter, vertical: 20),
                    child: Text(tr.noTitlesWithPerson, style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              if (items.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 20),
                    child: Row(
                      children: [
                        Text(tr.onYourServer, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 24),
                        // Filter nur, wenn es beides gibt.
                        if (movies.isNotEmpty && series.isNotEmpty)
                          for (final (f, label) in [
                            (_Filter.all, tr.allCount(items.length)),
                            (_Filter.movies, tr.moviesCount(movies.length)),
                            (_Filter.series, tr.showsCount(series.length)),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _FilterChip(
                                label: label,
                                selected: _filter == f,
                                onTap: () => setState(() => _filter = f),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                  // Spalten aus dem verfügbaren Platz berechnen (wie in der Bibliothek).
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 22.0;
                      final width = constraints.crossAxisExtent;
                      final columns = ((width + spacing) / (kPosterWidth + spacing)).floor().clamp(2, 12);
                      final cardWidth = (width - spacing * (columns - 1)) / columns;
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: 26,
                          mainAxisExtent: cardWidth * 1.5 + kCardTextHeight,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => PosterCard(item: shown[i], width: cardWidth),
                      );
                    },
                  ),
                ),
              ],
              if (episodes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: MediaRow(
                      title: tr.guestAppearances,
                      itemCount: episodes.length,
                      height: kLandscapeWidth * 9 / 16 + kCardTextHeight,
                      itemBuilder: (context, i) => LandscapeCard(item: episodes[i]),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            ],
          ),
        ),
        TopScrim(scroll: _scroll),
      ],
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.person, required this.movieCount, required this.seriesCount});

  final BaseItem person;
  final int movieCount;
  final int seriesCount;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final person = widget.person;
    final photo = Images.poster(person);
    final born = person.premiereDate;
    final died = person.endDate;
    final place = person.productionLocations.firstOrNull;
    final bio = person.overview?.trim();

    final facts = <String>[
      if (born != null)
        tr.bornOn(formatDate(born), died == null ? ageAt(born) : null, place)
      else if (place != null)
        tr.bornIn(place),
      if (died != null) tr.diedOn(formatDate(died), born != null ? ageAt(born, died) : null),
    ];
    final counts = [
      if (widget.movieCount > 0) tr.movieCount(widget.movieCount),
      if (widget.seriesCount > 0) tr.showCount(widget.seriesCount),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 240,
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: JfImage(
              url: api.imageUrlOrNull(photo, fillWidth: 480, fillHeight: 720),
              blurHash: photo?.blurHash,
              alignment: Alignment.topCenter,
              fallback: Icon(Icons.person_rounded, size: 96, color: AppColors.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 44),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  person.name,
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1),
                ),
                const SizedBox(height: 14),
                for (final fact in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(fact, style: const TextStyle(fontSize: 15.5, color: Color(0xFFDADCE5))),
                  ),
                if (counts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tr.onYourServerCounts(counts.join(' · ')),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  // Kurze Texte ganz zeigen, lange auf- und zuklappbar.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const style = TextStyle(fontSize: 15.5, height: 1.6, color: Color(0xFFD5D7E0));
                      // Mit derselben Schrift messen, die auch angezeigt wird.
                      final painter = TextPainter(
                        text: TextSpan(text: bio, style: DefaultTextStyle.of(context).style.merge(style)),
                        maxLines: 6,
                        textDirection: TextDirection.ltr,
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(maxWidth: constraints.maxWidth);
                      final long = painter.didExceedMaxLines;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: Text(
                              bio,
                              maxLines: _expanded ? null : 6,
                              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: style,
                            ),
                          ),
                          if (long)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextButton.icon(
                                onPressed: () => setState(() => _expanded = !_expanded),
                                icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                                label: Text(_expanded ? tr.showLess : tr.showMore),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: hovered ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.background : AppColors.textPrimary),
        ),
      ),
    );
  }
}
