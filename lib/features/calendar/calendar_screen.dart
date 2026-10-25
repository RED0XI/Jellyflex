import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/focusable.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/page_header.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';

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
    return Scaffold(
      body: Stack(
        children: [
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

/// Ein Tag: Überschrift mit Akzentstrich, darunter die Folgen.
class _DaySection extends StatelessWidget {
  const _DaySection({super.key, required this.day, required this.today, required this.episodes});

  final DateTime day;
  final DateTime today;
  final List<BaseItem> episodes;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 34, kPageGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.accent : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(_dayLabel(day, today), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (_daysBetween(today, day).abs() <= 1) ...[
                const SizedBox(width: 10),
                Text(tr.weekdayDate(day), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              ],
              const SizedBox(width: 10),
              Text('·  ${tr.episodesCount(episodes.length)}', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 18, runSpacing: 18, children: [for (final e in episodes) _EpisodeTile(episode: e)]),
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
