import 'dart:ui' show ImageFilter;

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
import '../../widgets/page_header.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../home/hero_banner.dart' show TitleLogo;

/// Angekündigte Folgen, nach Tag sortiert.
final upcomingProvider = FutureProvider.autoDispose<List<BaseItem>>((ref) => ref.watch(apiProvider).getUpcoming());

/// So viele Tage zeigt die Leiste oben.
const _stripDays = 14;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Abstand in Kalendertagen – über UTC, damit Zeitumstellungen (23/25-Stunden-Tage) nicht stören.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "Demnächst": neue Folgen der eigenen Serien – oben eine Leiste mit den nächsten
/// zwei Wochen, darunter je Tag die Folgen als Bildkarten. Rein zum Nachschauen,
/// ohne Benachrichtigungen.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _scroll = ScrollController();
  final _dayKeys = <DateTime, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Folgen je Tag (Ortszeit), Tage aufsteigend.
  static Map<DateTime, List<BaseItem>> _byDay(List<BaseItem> items) {
    final days = <DateTime, List<BaseItem>>{};
    for (final item in items) {
      final date = item.premiereDate;
      if (date == null) continue;
      days.putIfAbsent(_day(date.toLocal()), () => []).add(item);
    }
    return Map.fromEntries(days.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  void _jumpTo(DateTime day) {
    final context = _dayKeys[day]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        alignment: 0.08,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingProvider);
    final today = _day(DateTime.now());
    final next = _nextEpisode(upcoming.value ?? const [], today);
    return Scaffold(
      body: Stack(
        children: [
          // Hintergrund: das Bild der nächsten Folge, weich und abgedunkelt – färbt die Seite.
          if (next != null) Positioned.fill(child: _AmbientBackdrop(episode: next)),
          SmoothScroll(
            controller: _scroll,
            builder: (context, physics) => CustomScrollView(
              controller: _scroll,
              physics: physics,
              slivers: [
                SliverToBoxAdapter(
                  child: PageHeader(title: tr.upcoming, subtitle: tr.upcomingHint),
                ),
                ...upcoming.when(
                  loading: () => [const SliverToBoxAdapter(child: RowsSkeleton())],
                  error: (e, _) => [
                    SliverToBoxAdapter(
                      child: ErrorView(
                        message: tr.contentCouldNotLoad(e),
                        onRetry: () => ref.invalidate(upcomingProvider),
                      ),
                    ),
                  ],
                  data: (items) {
                    final days = _byDay(items);
                    for (final d in days.keys) {
                      _dayKeys.putIfAbsent(d, GlobalKey.new);
                    }
                    return [
                      if (next != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 28),
                            child: _NextHero(episode: next, today: today),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _DayStrip(
                          today: today,
                          counts: {for (final e in days.entries) e.key: e.value.length},
                          onSelect: _jumpTo,
                        ),
                      ),
                      if (days.isEmpty)
                        SliverToBoxAdapter(
                          child: EmptyState(
                            icon: Icons.event_available_rounded,
                            title: tr.noUpcomingTitle,
                            hint: tr.noUpcoming,
                          ),
                        )
                      else
                        // Alle Tage gleich aufbauen (es sind nur wenige) – sonst fände der Sprung
                        // aus der Leiste weiter unten liegende Tage nicht.
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final e in days.entries)
                                _DaySection(key: _dayKeys[e.key], day: e.key, today: today, episodes: e.value),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 72)),
              ],
            ),
          ),
          TopScrim(scroll: _scroll),
        ],
      ),
    );
  }
}

/// Die nächste Folge ab heute (für das große Bild oben).
BaseItem? _nextEpisode(List<BaseItem> items, DateTime today) {
  final upcoming = [
    for (final i in items)
      if (i.premiereDate case final d? when _daysBetween(today, _day(d.toLocal())) >= 0) i,
  ]..sort((a, b) => a.premiereDate!.compareTo(b.premiereDate!));
  return upcoming.firstOrNull;
}

/// "Heute", "Morgen", "In 3 Tagen" – für das große Bild.
String _relativeLabel(DateTime day, DateTime today) => switch (_daysBetween(today, day)) {
  0 => tr.today,
  1 => tr.tomorrow,
  final n when n < 7 => tr.inDays(n),
  _ => tr.weekdayDate(day),
};

/// Weiches, abgedunkeltes Serienbild hinter der ganzen Seite.
class _AmbientBackdrop extends ConsumerWidget {
  const _AmbientBackdrop({required this.episode});

  final BaseItem episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final image = Images.backdrops(episode).firstOrNull ?? Images.backdrop(episode);
    if (image == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.75,
            widthFactor: 1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
              child: Opacity(
                opacity: 0.55,
                child: JfImage(url: api.imageUrlOrNull(image, maxWidth: 960), blurHash: image.blurHash),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.45, 0.75],
              colors: [
                AppColors.background.withValues(alpha: 0.35),
                AppColors.background.withValues(alpha: 0.8),
                AppColors.background,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Großes Bild der nächsten Folge: wann, welche Serie (Logo), welche Folge, worum es geht.
class _NextHero extends ConsumerWidget {
  const _NextHero({required this.episode, required this.today});

  final BaseItem episode;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final image = Images.backdrops(episode).firstOrNull ?? Images.landscape(episode);
    final day = _day(episode.premiereDate!.toLocal());
    final label = [?episode.episodeLabel, if (episode.name.isNotEmpty) episode.name].join('  ·  ');
    void open() => episode.seriesId == null ? null : context.push('/item/${episode.seriesId}');
    return Focusable(
      onTap: open,
      semanticLabel: '${episode.seriesName ?? ''}, $label',
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 340,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hovered ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
            width: hovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, 14)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: hovered ? 1.03 : 1,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              child: JfImage(
                url: api.imageUrlOrNull(image, maxWidth: 1600),
                blurHash: image?.blurHash,
                alignment: Alignment.topCenter,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0, 0.55, 1],
                  colors: [Color(0xF00A0B10), Color(0x990A0B10), Color(0x000A0B10)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 28, 34, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${tr.nextEpisodeAirs}  ·  ${_relativeLabel(day, today)}',
                        style: TextStyle(color: AppColors.onButton, fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TitleLogo(
                      logoUrl: api.imageUrlOrNull(Images.logo(episode), maxWidth: 600),
                      title: episode.seriesName ?? episode.name,
                      maxHeight: 70,
                      fontSize: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    if (episode.overview case final overview? when overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFCFD2DC), height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 18),
                    GlassButton(label: tr.goToSeries, icon: Icons.arrow_forward_rounded, onPressed: open),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Heute", "Morgen", "Gestern" oder "Donnerstag, 29. Oktober".
String _dayLabel(DateTime day, DateTime today) => switch (_daysBetween(today, day)) {
  0 => tr.today,
  1 => tr.tomorrow,
  -1 => tr.yesterday,
  _ => tr.weekdayDate(day),
};

/// Leiste mit den nächsten zwei Wochen; Tage mit Folgen tragen Punkte und springen zur Liste.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.today, required this.counts, required this.onSelect});

  final DateTime today;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
        itemCount: _stripDays,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final day = DateTime(today.year, today.month, today.day + i);
          final count = counts[day] ?? 0;
          return _DayPill(day: day, isToday: i == 0, count: count, onTap: count > 0 ? () => onSelect(day) : null);
        },
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.isToday, required this.count, this.onTap});

  final DateTime day;
  final bool isToday;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Focusable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: '${tr.weekdayDate(day)}: ${tr.episodesCount(count)}',
      builder: (context, highlighted) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.accent.withValues(alpha: 0.18)
              : (highlighted ? AppColors.surfaceHigh : AppColors.surface.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? AppColors.accent : (highlighted ? AppColors.textSecondary : AppColors.border),
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr.weekdayShort(day.weekday).toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isToday ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: active || isToday ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            // Ein Punkt je Folge (höchstens drei).
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Tag: links groß das Datum (heute in Akzentfarbe), rechts die Folgen.
class _DaySection extends StatelessWidget {
  const _DaySection({super.key, required this.day, required this.today, required this.episodes});

  final DateTime day;
  final DateTime today;
  final List<BaseItem> episodes;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final relative = _daysBetween(today, day).abs() <= 1 ? _dayLabel(day, today) : null;
    final color = isToday ? AppColors.accent : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 30, kPageGutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (relative ?? tr.weekdays[day.weekday - 1]).toUpperCase(),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(color: color, fontSize: 52, fontWeight: FontWeight.w900, height: 1.05),
                ),
                Text(
                  tr.months[day.month - 1],
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(tr.episodesCount(episodes.length), style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 150,
            margin: const EdgeInsets.only(right: 24, top: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [isToday ? AppColors.accent : AppColors.border, Colors.transparent],
              ),
            ),
          ),
          Expanded(
            child: Wrap(spacing: 18, runSpacing: 18, children: [for (final e in episodes) _EpisodeTile(episode: e)]),
          ),
        ],
      ),
    );
  }
}

/// Bild der Folge (sonst der Serie) mit Serienname und Folgenangabe darüber.
class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.episode});

  final BaseItem episode;

  static const _width = 320.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final image = Images.landscape(episode);
    final w = (_width * MediaQuery.devicePixelRatioOf(context)).round();
    final series = episode.seriesName ?? episode.name;
    final label = [?episode.episodeLabel, if (episode.name.isNotEmpty) episode.name].join('  ·  ');
    return Focusable(
      semanticLabel: '$series, $label',
      onTap: episode.seriesId == null ? null : () => context.push('/item/${episode.seriesId}'),
      builder: (context, highlighted) => AnimatedScale(
        scale: highlighted ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
              width: highlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: highlighted ? 0.5 : 0.3),
                blurRadius: highlighted ? 24 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                JfImage(
                  url: api.imageUrlOrNull(image, fillWidth: w, fillHeight: (w * 9 / 16).round()),
                  blurHash: image?.blurHash,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Color(0x00000000), Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        series,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      if (label.isNotEmpty)
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFD5D7E0)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
