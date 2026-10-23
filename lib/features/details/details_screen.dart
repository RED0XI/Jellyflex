import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/downloads.dart';
import '../downloads/downloads_screen.dart';
import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/media_info.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/backdrop_slideshow.dart';
import '../../widgets/buttons.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/people_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../home/hero_banner.dart';
import '../home/home_providers.dart';
import '../../widgets/focusable.dart';
import 'media_info_dialog.dart';
import 'theme_music.dart';
import '../lists/list_actions.dart';
import '../../l10n/strings.dart';

final itemProvider = FutureProvider.autoDispose.family<BaseItem, String>((ref, id) async {
  try {
    return await ref.watch(apiProvider).getItem(id);
  } catch (_) {
    // Offline: gespeicherte Infos eines Downloads verwenden.
    final local = ref.read(downloadsProvider.notifier).entryFor(id)?.loadItem();
    if (local != null) return local;
    rethrow;
  }
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

  /// Gewählte Fassung (bei mehreren Versionen); `null` = Standard.
  String? _sourceId;

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
        error: (e, _) =>
            ErrorView(message: tr.contentCouldNotLoad(e), onRetry: () => ref.invalidate(itemProvider(widget.itemId))),
        data: (item) => _buildContent(context, item),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BaseItem item) {
    final size = MediaQuery.sizeOf(context);
    final people = item.people.where((p) => p.type == 'Actor' || p.type == 'GuestStar').take(24).toList();
    final similarId = item.isEpisode ? item.seriesId : item.id;
    final sources = item.mediaSources;
    final source = sources.where((s) => s.id == _sourceId).firstOrNull ?? sources.firstOrNull;

    return Stack(
      children: [
        ThemeMusic(itemId: item.isEpisode ? (item.seriesId ?? item.id) : item.id),
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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.45, 0.85],
                colors: [
                  AppColors.background.withAlpha(0xF2),
                  AppColors.background.withAlpha(0xA6),
                  AppColors.background.withAlpha(0x20),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * 0.82,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, 0.4, 1],
                colors: [
                  AppColors.background,
                  AppColors.background.withAlpha(0x00),
                  AppColors.background.withAlpha(0x66),
                ],
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
                  child: _Header(item: item, source: source, onSelectSource: (id) => setState(() => _sourceId = id)),
                ),
              ),
              if (item.isSeries) SliverToBoxAdapter(child: _SeasonsSection(series: item)),
              if (item.isCollection) SliverToBoxAdapter(child: _CollectionRow(collectionId: item.id)),
              if (item.isEpisode && item.seriesId != null && item.seasonId != null)
                SliverToBoxAdapter(
                  child: _EpisodesRow(
                    seriesId: item.seriesId!,
                    seasonId: item.seasonId!,
                    title: item.seasonName ?? tr.moreEpisodes,
                    highlightId: item.id,
                  ),
                ),
              if (people.isNotEmpty)
                SliverToBoxAdapter(
                  child: PeopleRow(title: tr.cast, people: people),
                ),
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
  const _Header({required this.item, this.source, required this.onSelectSource});

  final BaseItem item;

  /// Gewählte Fassung (für Abzeichen, Abspielen, Medieninfo).
  final MediaSource? source;
  final ValueChanged<String> onSelectSource;

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
      if (item.isSeries && item.childCount != null) Text(tr.seasonsCount(item.childCount!)),
      if (item.officialRating != null) RatingBadge(item.officialRating!),
      if (source != null && !item.isSeries && !item.isCollection)
        for (final badge in qualityBadges(source!)) _QualityBadge(badge),
      if (remaining != null && !item.isSeries && remaining > Duration.zero)
        Text(tr.endsAt(formatClock(DateTime.now().add(remaining))), style: TextStyle(color: AppColors.textSecondary)),
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
                  if (item.parentIndexNumber != null) tr.seasonN(item.parentIndexNumber!),
                  if (item.indexNumber != null) tr.episodeN(item.indexNumber!),
                ].join(' · '),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
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
              Text(item.genres.join('  ·  '), style: TextStyle(color: AppColors.textSecondary)),
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
            _ActionButtons(item: item, source: source, onSelectSource: onSelectSource),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({required this.item, this.source, required this.onSelectSource});

  final BaseItem item;
  final MediaSource? source;
  final ValueChanged<String> onSelectSource;

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

  static String _shortVersion(MediaSource source) {
    final short = [?resolutionLabel(source.videoStream), ?hdrLabel(source.videoStream)].join(' ');
    return short.isNotEmpty ? short : (source.name ?? '?');
  }

  /// Nur bei mehreren Fassungen gezielt eine abspielen, sonst entscheidet der Server.
  String? get _chosenSourceId => widget.item.mediaSources.length > 1 ? widget.source?.id : null;

  Future<void> _chooseVersion(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
    final current = widget.source?.id;
    final previousFocus = FocusManager.instance.primaryFocus;
    final chosen = await showMenu<String>(
      context: buttonContext,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      constraints: const BoxConstraints(minWidth: 320),
      items: [
        for (final s in widget.item.mediaSources)
          PopupMenuItem(
            value: s.id,
            height: 56,
            child: Row(
              children: [
                Icon(
                  s.id == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 20,
                  color: s.id == current ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(versionLabel(s), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (versionDetails(s).isNotEmpty)
                        Text(versionDetails(s), style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    previousFocus?.requestFocus();
    if (chosen != null) widget.onSelectSource(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final source = widget.source;
    final favorite = _favorite ?? item.userData.isFavorite;
    final played = _played ?? item.userData.played;

    final Widget playButtons;
    if (item.isCollection) {
      // Erster noch nicht gesehener Teil der Sammlung.
      final items = ref.watch(collectionItemsProvider(item.id)).value ?? const <BaseItem>[];
      final next = items.where((i) => !i.userData.played).firstOrNull ?? items.firstOrNull;
      playButtons = PrimaryButton(
        label: next == null ? tr.play : '${tr.play}  ·  ${next.name}',
        icon: Icons.play_arrow_rounded,
        onPressed: next == null || next.isSeries ? null : () => playItem(context, next),
      );
    } else if (item.isSeries) {
      final nextUp = ref.watch(seriesNextUpProvider(item.id));
      final episode = nextUp.value;
      final resuming = episode?.userData.hasResumePosition ?? false;
      playButtons = PrimaryButton(
        label: episode == null
            ? tr.play
            : '${resuming ? tr.resume : tr.play}  ·  ${episode.episodeLabel ?? episode.name}',
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
            label: resuming ? '${tr.resume}  ·  ${remainingLabel(item) ?? ''}' : tr.play,
            icon: Icons.play_arrow_rounded,
            onPressed: () => playItem(context, item, mediaSourceId: _chosenSourceId),
          ),
          if (resuming) ...[
            const SizedBox(width: 12),
            GlassButton(
              label: tr.fromStart,
              icon: Icons.replay_rounded,
              onPressed: () => playItem(context, item, fromStart: true, mediaSourceId: _chosenSourceId),
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
        if (item.mediaSources.length > 1 && source != null)
          Builder(
            builder: (buttonContext) => GlassButton(
              label: tr.versionLabel(_shortVersion(source)),
              icon: Icons.video_settings_rounded,
              onPressed: () => _chooseVersion(buttonContext),
            ),
          ),
        CircleIconButton(
          icon: Icons.check_rounded,
          tooltip: played ? tr.markUnplayed : tr.markPlayed,
          active: played,
          activeColor: AppColors.accentAlt,
          onPressed: _togglePlayed,
        ),
        CircleIconButton(
          icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          tooltip: favorite ? tr.removeFavorite : tr.addFavorite,
          active: favorite,
          activeColor: const Color(0xFFFF5C8A),
          onPressed: _toggleFavorite,
        ),
        if (!item.isCollection) WatchlistButton(item: item),
        if (!item.isSeries && !item.isCollection) _DownloadButton(item: item, mediaSourceId: _chosenSourceId),
        if (source != null && !item.isSeries && !item.isCollection)
          CircleIconButton(
            icon: Icons.info_outline_rounded,
            tooltip: tr.mediaInfoTooltip,
            onPressed: () => showMediaInfoDialog(context, item, source),
          ),
      ],
    );
  }
}

/// Herunterladen / Fortschritt / Fertig – je nach Zustand des Downloads.
class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.item, this.mediaSourceId});

  final BaseItem item;

  /// Gewählte Fassung (bei mehreren Versionen).
  final String? mediaSourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(downloadedProvider(item.id));
    final manager = ref.read(downloadsProvider.notifier);
    if (entry == null) {
      return CircleIconButton(
        icon: Icons.download_rounded,
        tooltip: tr.downloadOffline,
        onPressed: () => manager.enqueue(item, mediaSourceId: mediaSourceId),
      );
    }
    if (entry.isDone) {
      return CircleIconButton(
        icon: Icons.download_done_rounded,
        tooltip: tr.downloadedClickToDelete,
        active: true,
        activeColor: AppColors.accentAlt,
        onPressed: () async {
          if (await confirmRemoveDownload(context, item.name)) manager.remove(item.id);
        },
      );
    }
    // Läuft gerade oder wartet: Fortschrittsring, Klick pausiert bzw. setzt fort.
    final running = entry.status == DownloadStatus.downloading || entry.status == DownloadStatus.queued;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: CircularProgressIndicator(
            value: entry.total > 0 ? entry.progress : null,
            strokeWidth: 3,
            color: AppColors.accent,
            backgroundColor: Colors.white12,
          ),
        ),
        CircleIconButton(
          icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: running ? tr.pauseDownload : tr.resumeDownload,
          size: 44,
          onPressed: () => running ? manager.pause(item.id) : manager.resume(item.id),
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
                watched: season.userData.played,
                selected: season.id == selected,
                onTap: () => setState(() => _selectedSeasonId = season.id),
              );
            },
          ),
        ),
        _SeasonTools(
          series: widget.series,
          season: seasons.firstWhere((s) => s.id == selected, orElse: () => seasons.first),
          // Nach "als gesehen markieren" springt "Als Nächstes" in die nächste Staffel –
          // die gewählte Staffel bleibt trotzdem stehen.
          onAction: () => setState(() => _selectedSeasonId = selected),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _EpisodesRow(key: ValueKey(selected), seriesId: widget.series.id, seasonId: selected),
        ),
      ],
    );
  }
}

/// Kleines Abzeichen für Bild-/Tonqualität (4K, HDR10, Atmos …).
class _QualityBadge extends StatelessWidget {
  const _QualityBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({required this.label, required this.selected, required this.onTap, this.watched = false});

  final String label;
  final bool selected;

  /// Alle Folgen gesehen → kleiner Haken.
  final bool watched;
  final VoidCallback onTap;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.selected ? Colors.white : Colors.white.withValues(alpha: hovered ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.watched) ...[
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: widget.selected ? AppColors.background : AppColors.accent,
                semanticLabel: tr.watched,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.selected ? AppColors.background : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Werkzeuge für die gewählte Staffel: Fortschritt, ganz als gesehen/ungesehen
/// markieren, herunterladen – mit Fortschritt der Downloads dieser Staffel.
class _SeasonTools extends ConsumerWidget {
  const _SeasonTools({required this.series, required this.season, required this.onAction});

  final BaseItem series;
  final BaseItem season;

  /// Vor jeder Aktion: Auswahl der Staffel festhalten.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(episodesProvider((series.id, season.id))).value ?? const <BaseItem>[];
    final watched = episodes.where((e) => e.userData.played).length;
    final allWatched = episodes.isNotEmpty && watched == episodes.length;
    final ids = {for (final e in episodes) e.id};
    final downloads = ref.watch(myDownloadsProvider).where((d) => ids.contains(d.itemId)).toList();
    final done = downloads.where((d) => d.isDone).length;
    final total = downloads.fold(0, (sum, d) => sum + (d.isDone ? d.received : d.total));
    final received = downloads.fold(0, (sum, d) => sum + d.received);
    final downloading = downloads.length > done;
    final messenger = ScaffoldMessenger.maybeOf(context);

    void snack(String text) =>
        messenger?.showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, width: 420));

    Future<void> markAll(bool played) async {
      if (played && !await _confirmMarkSeason(context, season.name, episodes.length)) return;
      onAction();
      try {
        // Jellyfin markiert mit der Staffel alle ihre Folgen.
        await ref.read(apiProvider).setPlayed(season.id, played);
        ref.invalidate(episodesProvider((series.id, season.id)));
        ref.invalidate(seasonsProvider(series.id));
        ref.invalidate(seriesNextUpProvider(series.id));
        ref.invalidate(homeProvider);
        snack(played ? tr.seasonMarkedWatched(season.name) : tr.seasonMarkedUnwatched(season.name));
      } catch (_) {
        snack(tr.didNotWork);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 12, kPageGutter, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (episodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                tr.episodesWatchedOf(watched, episodes.length),
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          TextButton.icon(
            onPressed: episodes.isEmpty ? null : () => markAll(!allWatched),
            icon: Icon(allWatched ? Icons.remove_done_rounded : Icons.done_all_rounded, size: 18),
            label: Text(allWatched ? tr.markSeasonUnwatched : tr.markSeasonWatched),
          ),
          TextButton.icon(
            onPressed: episodes.isEmpty
                ? null
                : () async {
                    final added = await ref.read(downloadsProvider.notifier).enqueueAll(episodes);
                    snack(added == 0 ? tr.seasonAlreadyDownloaded : tr.episodesDownloading(added));
                  },
            icon: Icon(
              done == episodes.length && episodes.isNotEmpty ? Icons.download_done_rounded : Icons.download_rounded,
              size: 18,
            ),
            label: Text(downloads.isEmpty ? tr.downloadSeason : tr.downloadedOf(done, episodes.length)),
          ),
          if (downloading)
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total > 0 ? received / total : null,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> _confirmMarkSeason(BuildContext context, String season, int count) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr.markSeasonWatchedQuestion(season)),
      content: Text(tr.markSeasonWatchedDetail(count)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr.markSeasonWatched)),
      ],
    ),
  );
  return ok ?? false;
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
                    if (ep.id == highlightId) tr.thisEpisode,
                  ].join(' · '),
                  onTap: () => playItem(context, ep),
                ),
                SizedBox(
                  height: _overviewHeight,
                  child: Text(
                    ep.overview ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
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

class _SimilarRow extends ConsumerWidget {
  const _SimilarRow({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(similarProvider(itemId)).value ?? const <BaseItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return MediaRow(
      title: tr.youMightLike,
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
        title: tr.inThisCollection,
        itemCount: items.length,
        height: kPosterWidth * 1.5 + kCardTextHeight,
        itemBuilder: (context, i) => PosterCard(item: items[i]),
      ),
    );
  }
}
