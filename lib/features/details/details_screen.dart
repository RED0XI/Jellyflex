import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/backdrop_slideshow.dart';
import '../../widgets/buttons.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../home/hero_banner.dart';
import '../home/home_providers.dart';

final itemProvider = FutureProvider.autoDispose.family<BaseItem, String>((ref, id) {
  return ref.watch(apiProvider).getItem(id);
});

final seasonsProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, seriesId) {
  return ref.watch(apiProvider).getSeasons(seriesId);
});

final episodesProvider = FutureProvider.autoDispose.family<List<BaseItem>, (String, String)>((ref, args) {
  return ref.watch(apiProvider).getEpisodes(args.$1, args.$2);
});

/// Inhalt einer Sammlung (BoxSet).
final collectionItemsProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, id) {
  return ref.watch(apiProvider).getCollectionItems(id);
});

final similarProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, id) async {
  try {
    return await ref.watch(apiProvider).getSimilar(id);
  } catch (_) {
    return const [];
  }
});

/// Die nächste Folge einer Serie (oder `null`, wenn alles gesehen ist).
final seriesNextUpProvider = FutureProvider.autoDispose.family<BaseItem?, String>((ref, seriesId) async {
  final api = ref.watch(apiProvider);
  final resume = await api.getNextUp(seriesId: seriesId, limit: 1);
  if (resume.isNotEmpty) return resume.first;
  // Noch nichts gesehen → erste Folge der ersten Staffel.
  final seasons = await ref.watch(seasonsProvider(seriesId).future);
  final regular = seasons.where((s) => (s.indexNumber ?? 0) > 0).toList();
  final first = regular.isNotEmpty ? regular.first : (seasons.isNotEmpty ? seasons.first : null);
  if (first == null) return null;
  final episodes = await ref.watch(episodesProvider((seriesId, first.id)).future);
  return episodes.isNotEmpty ? episodes.first : null;
});

/// Nach Änderungen (Favorit, gesehen, Wiedergabe) alles neu laden.
void refreshItemData(WidgetRef ref, BaseItem item) {
  ref.invalidate(itemProvider(item.id));
  if (item.seriesId != null) ref.invalidate(itemProvider(item.seriesId!));
  ref.invalidate(homeProvider);
  ref.invalidate(seriesNextUpProvider);
  ref.invalidate(episodesProvider);
}

/// Wie [refreshItemData], aber für Stellen ohne WidgetRef (z. B. nach einem Menü).
void refreshItemDataIn(ProviderContainer container, BaseItem item) {
  container.invalidate(itemProvider(item.id));
  if (item.seriesId != null) container.invalidate(itemProvider(item.seriesId!));
  container.invalidate(homeProvider);
  container.invalidate(seriesNextUpProvider);
  container.invalidate(episodesProvider);
}

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemProvider(widget.itemId));
    return Scaffold(
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Inhalt konnte nicht geladen werden.\n$e',
          onRetry: () => ref.invalidate(itemProvider(widget.itemId)),
        ),
        data: (item) => _buildContent(context, item),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BaseItem item) {
    final size = MediaQuery.sizeOf(context);
    final people = item.people.where((p) => p.type == 'Actor' || p.type == 'GuestStar').take(24).toList();
    final similarId = item.isEpisode ? item.seriesId : item.id;

    return Stack(
      children: [
        // Hintergrundbild, wird beim Scrollen dunkler.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * 0.82,
          child: BackdropSlideshow(
            images: Images.backdrops(item).isNotEmpty ? Images.backdrops(item) : [?Images.backdrop(item)],
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.45, 0.85],
                colors: [Color(0xF20A0B10), Color(0xA60A0B10), Color(0x200A0B10)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * 0.82,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, 0.4, 1],
                colors: [AppColors.background, Color(0x000A0B10), Color(0x660A0B10)],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) {
            final offset = _scroll.hasClients ? _scroll.offset : 0.0;
            return IgnorePointer(
              child: Container(color: AppColors.background.withValues(alpha: (offset / 500).clamp(0.0, 0.85))),
            );
          },
        ),
        SmoothScroll(
          controller: _scroll,
          builder: (context, physics) => CustomScrollView(
            controller: _scroll,
            physics: physics,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(kPageGutter, size.height * 0.26, kPageGutter, 40),
                  child: _Header(item: item),
                ),
              ),
              if (item.isSeries) SliverToBoxAdapter(child: _SeasonsSection(series: item)),
              if (item.isCollection) SliverToBoxAdapter(child: _CollectionRow(collectionId: item.id)),
              if (item.isEpisode && item.seriesId != null && item.seasonId != null)
                SliverToBoxAdapter(
                  child: _EpisodesRow(
                    seriesId: item.seriesId!,
                    seasonId: item.seasonId!,
                    title: item.seasonName ?? 'Weitere Folgen',
                    highlightId: item.id,
                  ),
                ),
              if (people.isNotEmpty) SliverToBoxAdapter(child: _CastRow(people: people)),
              if (similarId != null) SliverToBoxAdapter(child: _SimilarRow(itemId: similarId)),
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            ],
          ),
        ),
        TopScrim(scroll: _scroll),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.item});

  final BaseItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final runtime = item.runtime;
    final remaining = item.runTimeTicks != null
        ? ticksToDuration(item.runTimeTicks! - item.userData.playbackPositionTicks)
        : null;

    final meta = <Widget>[
      if (item.communityRating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFC94D), size: 20),
            const SizedBox(width: 4),
            Text(item.communityRating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      if (item.criticRating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_florist_rounded,
              color: item.criticRating! >= 60 ? const Color(0xFFFF5A47) : const Color(0xFF7BC67B),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text('${item.criticRating!.round()} %'),
          ],
        ),
      if (yearLabel(item) case final year?) Text(year),
      if (runtime != null && !item.isSeries) Text(formatRuntime(runtime)),
      if (item.isSeries && item.childCount != null)
        Text('${item.childCount} ${item.childCount == 1 ? 'Staffel' : 'Staffeln'}'),
      if (item.officialRating != null) RatingBadge(item.officialRating!),
      if (remaining != null && !item.isSeries && remaining > Duration.zero)
        Text(
          'Endet um ${formatClock(DateTime.now().add(remaining))}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isEpisode) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: item.seriesId == null ? null : () => context.push('/item/${item.seriesId}'),
                  child: TitleLogo(
                    logoUrl: api.imageUrlOrNull(Images.logo(item), maxWidth: 800),
                    title: item.seriesName ?? '',
                    maxHeight: 80,
                    fontSize: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                [
                  if (item.parentIndexNumber != null) 'Staffel ${item.parentIndexNumber}',
                  if (item.indexNumber != null) 'Folge ${item.indexNumber}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(item.name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ] else
              TitleLogo(
                logoUrl: api.imageUrlOrNull(Images.logo(item), maxWidth: 800),
                title: item.name,
                maxHeight: 150,
                fontSize: 56,
              ),
            const SizedBox(height: 18),
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15),
              child: Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: meta),
            ),
            if (item.genres.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(item.genres.join('  ·  '), style: const TextStyle(color: AppColors.textSecondary)),
            ],
            if (item.taglines.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                item.taglines.first,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16, color: Color(0xFFDADCE5)),
              ),
            ],
            if (item.overview != null) ...[
              const SizedBox(height: 14),
              Text(
                item.overview!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, height: 1.55, color: Color(0xFFD5D7E0)),
              ),
            ],
            const SizedBox(height: 28),
            _ActionButtons(item: item),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({required this.item});

  final BaseItem item;

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool? _favorite;
  bool? _played;

  @override
  void didUpdateWidget(covariant _ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    _favorite = null;
    _played = null;
  }

  Future<void> _toggleFavorite() async {
    final next = !(_favorite ?? widget.item.userData.isFavorite);
    setState(() => _favorite = next);
    try {
      await ref.read(apiProvider).setFavorite(widget.item.id, next);
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    }
  }

  Future<void> _togglePlayed() async {
    final next = !(_played ?? widget.item.userData.played);
    setState(() => _played = next);
    try {
      await ref.read(apiProvider).setPlayed(widget.item.id, next);
      if (mounted) refreshItemData(ref, widget.item);
    } catch (_) {
      if (mounted) setState(() => _played = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final favorite = _favorite ?? item.userData.isFavorite;
    final played = _played ?? item.userData.played;

    final Widget playButtons;
    if (item.isCollection) {
      // Erster noch nicht gesehener Teil der Sammlung.
      final items = ref.watch(collectionItemsProvider(item.id)).value ?? const <BaseItem>[];
      final next = items.where((i) => !i.userData.played).firstOrNull ?? items.firstOrNull;
      playButtons = PrimaryButton(
        label: next == null ? 'Abspielen' : 'Abspielen  ·  ${next.name}',
        icon: Icons.play_arrow_rounded,
        onPressed: next == null || next.isSeries ? null : () => playItem(context, next),
      );
    } else if (item.isSeries) {
      final nextUp = ref.watch(seriesNextUpProvider(item.id));
      final episode = nextUp.value;
      final resuming = episode?.userData.hasResumePosition ?? false;
      playButtons = PrimaryButton(
        label: episode == null
            ? 'Abspielen'
            : '${resuming ? 'Fortsetzen' : 'Abspielen'}  ·  ${episode.episodeLabel ?? episode.name}',
        icon: Icons.play_arrow_rounded,
        loading: nextUp.isLoading,
        onPressed: episode == null ? null : () => playItem(context, episode),
      );
    } else {
      final resuming = item.userData.hasResumePosition;
      playButtons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: resuming ? 'Fortsetzen  ·  ${remainingLabel(item) ?? ''}' : 'Abspielen',
            icon: Icons.play_arrow_rounded,
            onPressed: () => playItem(context, item),
          ),
          if (resuming) ...[
            const SizedBox(width: 12),
            GlassButton(
              label: 'Von vorne',
              icon: Icons.replay_rounded,
              onPressed: () => playItem(context, item, fromStart: true),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        playButtons,
        CircleIconButton(
          icon: Icons.check_rounded,
          tooltip: played ? 'Als ungesehen markieren' : 'Als gesehen markieren',
          active: played,
          activeColor: AppColors.accentAlt,
          onPressed: _togglePlayed,
        ),
        CircleIconButton(
          icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          tooltip: favorite ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen',
          active: favorite,
          activeColor: const Color(0xFFFF5C8A),
          onPressed: _toggleFavorite,
        ),
      ],
    );
  }
}

class _SeasonsSection extends ConsumerStatefulWidget {
  const _SeasonsSection({required this.series});

  final BaseItem series;

  @override
  ConsumerState<_SeasonsSection> createState() => _SeasonsSectionState();
}

class _SeasonsSectionState extends ConsumerState<_SeasonsSection> {
  String? _selectedSeasonId;

  @override
  Widget build(BuildContext context) {
    final seasons = ref.watch(seasonsProvider(widget.series.id)).value ?? const <BaseItem>[];
    if (seasons.isEmpty) return const SizedBox(height: 200);

    // Standardmäßig die Staffel der nächsten Folge zeigen.
    final nextUpSeason = ref.watch(seriesNextUpProvider(widget.series.id)).value?.seasonId;
    final selected = _selectedSeasonId ?? (seasons.any((s) => s.id == nextUpSeason) ? nextUpSeason! : seasons.first.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
            itemCount: seasons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final season = seasons[i];
              return _SeasonChip(
                label: season.name,
                selected: season.id == selected,
                onTap: () => setState(() => _selectedSeasonId = season.id),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _EpisodesRow(key: ValueKey(selected), seriesId: widget.series.id, seasonId: selected),
        ),
      ],
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? Colors.white : Colors.white.withValues(alpha: _hovered ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: widget.selected ? AppColors.background : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodesRow extends ConsumerWidget {
  const _EpisodesRow({super.key, required this.seriesId, required this.seasonId, this.title, this.highlightId});

  final String seriesId;
  final String seasonId;
  final String? title;
  final String? highlightId;

  static const _width = 340.0;
  static const _overviewHeight = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(episodesProvider((seriesId, seasonId))).value;
    final height = _width * 9 / 16 + kCardTextHeight + _overviewHeight;
    if (episodes == null) {
      return SizedBox(height: height + 28 + (title != null ? 30 : 0));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MediaRow(
        title: title,
        itemCount: episodes.length,
        height: height,
        itemBuilder: (context, i) {
          final ep = episodes[i];
          return SizedBox(
            width: _width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LandscapeCard(
                  item: ep,
                  width: _width,
                  title: '${ep.indexNumber != null ? '${ep.indexNumber}. ' : ''}${ep.name}',
                  subtitle: [
                    if (ep.runtime != null) formatRuntime(ep.runtime!),
                    if (ep.id == highlightId) 'Diese Folge',
                  ].join(' · '),
                  onTap: () => playItem(context, ep),
                ),
                SizedBox(
                  height: _overviewHeight,
                  child: Text(
                    ep.overview ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CastRow extends ConsumerWidget {
  const _CastRow({required this.people});

  final List<Person> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: MediaRow(
        title: 'Besetzung',
        itemCount: people.length,
        height: 190,
        spacing: 22,
        itemBuilder: (context, i) {
          final p = people[i];
          return SizedBox(
            width: 120,
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: JfImage(
                      url: api.imageUrlOrNull(Images.person(p), fillWidth: 240, fillHeight: 360),
                      blurHash: p.blurHash,
                      alignment: Alignment.topCenter,
                      fallback: const Icon(Icons.person_rounded, size: 48, color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                if (p.role != null)
                  Text(
                    p.role!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SimilarRow extends ConsumerWidget {
  const _SimilarRow({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(similarProvider(itemId)).value ?? const <BaseItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return MediaRow(
      title: 'Das könnte dir auch gefallen',
      itemCount: items.length,
      height: kPosterWidth * 1.5 + kCardTextHeight,
      itemBuilder: (context, i) => PosterCard(item: items[i]),
    );
  }
}

/// Alle Filme/Serien einer Sammlung.
class _CollectionRow extends ConsumerWidget {
  const _CollectionRow({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionItemsProvider(collectionId)).value ?? const <BaseItem>[];
    if (items.isEmpty) return const SizedBox(height: 40);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MediaRow(
        title: 'In dieser Sammlung',
        itemCount: items.length,
        height: kPosterWidth * 1.5 + kCardTextHeight,
        itemBuilder: (context, i) => PosterCard(item: items[i]),
      ),
    );
  }
}
