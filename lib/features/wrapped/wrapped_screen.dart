import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/jf_image.dart';
import 'wrapped_stats.dart';
import '../../l10n/strings.dart';
import '../../core/platform/app_paths.dart';

/// Gesehene Filme, Folgen und die zugehörigen Serien (für alle Jahre).
final _wrappedDataProvider = FutureProvider.autoDispose<(List<BaseItem>, List<BaseItem>, Map<String, BaseItem>)>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  final (movies, episodes) = await (api.getPlayedItems('Movie'), api.getPlayedItems('Episode')).wait;
  final seriesIds = {for (final e in episodes) ?e.seriesId}.toList();
  final series = <BaseItem>[];
  // In Portionen, damit die Adresse nicht zu lang wird.
  for (var i = 0; i < seriesIds.length; i += 60) {
    series.addAll(await api.getItemsByIds(seriesIds.sublist(i, (i + 60).clamp(0, seriesIds.length))));
  }
  return (movies, episodes, {for (final s in series) s.id: s});
});

/// Jahresrückblick wie "Spotify Wrapped": Karten mit großen Zahlen, die von
/// selbst weiterblättern (Klick/Pfeiltasten blättern sofort).
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  static const slideTime = Duration(seconds: 8);

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> with SingleTickerProviderStateMixin {
  late final _timer = AnimationController(vsync: this, duration: WrappedScreen.slideTime);
  final _focus = FocusNode(debugLabel: 'Wrapped');
  final _summaryKey = GlobalKey();
  int? _year;
  int _slide = 0;

  @override
  void initState() {
    super.initState();
    _timer.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go(1);
    });
  }

  @override
  void dispose() {
    _timer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta, [int? count]) {
    final total = count ?? _slideCount;
    final next = (_slide + delta).clamp(0, total - 1);
    if (next == _slide && delta > 0) return;
    setState(() => _slide = next);
    // Letzte Karte bleibt stehen.
    if (next < total - 1) {
      _timer.forward(from: 0);
    } else {
      _timer.value = 1;
      _timer.stop();
    }
  }

  int _slideCount = 1;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.space) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveImage(WrappedStats stats) async {
    final boundary = _summaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = Directory(AppPaths.pictures);
      await dir.create(recursive: true);
      final name = '${tr.recapFileName(appDisplayName(ref.read(settingsProvider)), stats.year)}.png'.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '',
      );
      final file = File(AppPaths.join(dir.path, name));
      await file.writeAsBytes(png!.buffer.asUint8List());
      messenger?.showSnackBar(
        SnackBar(
          content: Text(tr.savedToPictures(name)),
          behavior: SnackBarBehavior.floating,
          width: 520,
          action: SnackBarAction(label: tr.show, onPressed: () => AppPaths.reveal(file.path)),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(tr.imageNotSaved), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_wrappedDataProvider);
    return Scaffold(
      body: data.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(tr.calculatingYear, style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Text(tr.serverUnreachable, style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (d) {
          final (movies, episodes, series) = d;
          // Jahre mit Daten; Standard: dieses Jahr, im Januar ohne Daten das letzte.
          final years = <int>{
            for (final i in [...movies, ...episodes])
              ?DateTime.tryParse((i.userData.raw['LastPlayedDate'] as String?) ?? '')?.toLocal().year,
          }.toList()..sort((a, b) => b.compareTo(a));
          final now = DateTime.now().year;
          final year = _year ?? (years.contains(now) || years.isEmpty ? now : years.first);
          final stats = computeWrapped(year: year, playedMovies: movies, playedEpisodes: episodes, seriesById: series);
          final slides = _slides(stats, years);
          _slideCount = slides.length;
          if (_slide >= slides.length) _slide = slides.length - 1;
          if (!_timer.isAnimating && _slide == 0 && _timer.value == 0 && slides.length > 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_timer.isAnimating && _timer.value == 0) _timer.forward(from: 0);
            });
          }
          return Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: KeyedSubtree(key: ValueKey('$year-$_slide'), child: slides[_slide]),
                ),
                // Links/rechts tippen = zurück/weiter (wie bei Stories).
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _go(-1)),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _go(1)),
                    ),
                  ],
                ),
                // Fortschrittsbalken oben.
                Positioned(
                  top: kTitleBarHeight + 6,
                  left: kPageGutter,
                  right: kPageGutter,
                  child: AnimatedBuilder(
                    animation: _timer,
                    builder: (context, _) => Row(
                      children: [
                        for (var i = 0; i < slides.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: i < _slide ? 1 : (i == _slide ? _timer.value : 0),
                                minHeight: 4,
                                backgroundColor: Colors.white24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_slide == slides.length - 1 && !stats.isEmpty)
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Wrap(
                        spacing: 12,
                        children: [
                          PrimaryButton(
                            label: tr.saveAsImage,
                            icon: Icons.download_rounded,
                            onPressed: () => _saveImage(stats),
                          ),
                          GlassButton(label: tr.watchAgain, icon: Icons.replay_rounded, onPressed: () => _go(-99)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _slides(WrappedStats s, List<int> years) {
    final name = appDisplayName(ref.watch(settingsProvider));
    final hours = s.totalMinutes / 60;
    final posters = [for (final t in s.titles) ?Images.poster(t)];
    ImageRef? backdrop(BaseItem? item) => item == null ? null : Images.backdrop(item);
    final intro = _Slide(
      colors: const [Color(0xFF3B1E6E), Color(0xFF0B0B18)],
      wall: posters,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          tr.yourYear(s.year),
          style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1),
        ),
        const SizedBox(height: 16),
        Text(
          s.isEmpty ? tr.nothingThisYear : tr.letsLookBack,
          style: const TextStyle(fontSize: 22, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        // Klarstellen, was gezählt wird: nur dieses Profil, nur wirklich Geschautes.
        Text(
          s.markedOnly > 0 ? '${tr.recapOnlyYou}  ·  ${tr.recapMarkedNote(s.markedOnly)}' : tr.recapOnlyYou,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white54),
        ),
        if (years.length > 1) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            children: [
              for (final y in years.take(5))
                ChoiceChip(
                  label: Text('$y'),
                  selected: y == s.year,
                  onSelected: (_) {
                    setState(() {
                      _year = y;
                      _slide = 0;
                    });
                    _timer.forward(from: 0);
                  },
                ),
            ],
          ),
        ],
      ],
    );
    if (s.isEmpty) return [intro];

    final topGenre = s.topGenres.firstOrNull;
    final favHour = s.favoriteHour;
    return [
      intro,
      _Slide(
        colors: const [Color(0xFF0E5E6F), Color(0xFF07131A)],
        background: backdrop(s.titles.firstOrNull),
        children: [
          Text(tr.youWatched, style: TextStyle(fontSize: 26, color: Colors.white70)),
          _CountUp(
            value: hours,
            decimals: hours < 10 ? 1 : 0,
            suffix: tr.hoursSuffix,
            style: const TextStyle(fontSize: 92, fontWeight: FontWeight.w900, letterSpacing: -2),
          ),
          Text(
            tr.watchedComparison(_timeComparison(s.totalMinutes)),
            style: const TextStyle(fontSize: 24, color: Colors.white70),
          ),
        ],
      ),
      _Slide(
        colors: const [Color(0xFF7A2E5A), Color(0xFF160A12)],
        background: backdrop(s.titles.elementAtOrNull(1)),
        side: _PosterFan(posters: posters),
        children: [
          Text(tr.thatWas, style: TextStyle(fontSize: 26, color: Colors.white70)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 56,
            runSpacing: 20,
            children: [
              _BigStat(value: s.movies, label: s.movies == 1 ? tr.movieWord : tr.moviesWord),
              _BigStat(value: s.episodes, label: s.episodes == 1 ? tr.episodeWord : tr.episodesWord),
              _BigStat(value: s.series, label: s.series == 1 ? tr.showWord : tr.showsWord),
            ],
          ),
          if (s.longestMovie case final longest?) ...[
            const SizedBox(height: 26),
            Text(
              tr.longestMovie(longest.name, formatRuntime(longest.runtime ?? Duration.zero)),
              style: const TextStyle(fontSize: 20, color: Colors.white70),
            ),
          ],
        ],
      ),
      if (topGenre != null)
        _Slide(
          colors: const [Color(0xFF8A4B12), Color(0xFF1A0E05)],
          background: backdrop(s.genreTitle),
          side: _PosterFan(posters: [?Images.poster(s.genreTitle ?? s.titles.first)]),
          children: [
            Text(tr.favoriteGenre, style: TextStyle(fontSize: 26, color: Colors.white70)),
            Text(topGenre.$1, style: const TextStyle(fontSize: 84, fontWeight: FontWeight.w900, letterSpacing: -2)),
            const SizedBox(height: 26),
            for (final (genre, minutes) in s.topGenres) _GenreBar(label: genre, minutes: minutes, max: topGenre.$2),
          ],
        ),
      if (s.topSeries case final series?)
        _Slide(
          colors: const [Color(0xFF1C2F7A), Color(0xFF070A18)],
          background: Images.backdrop(series),
          side: _PosterFan(posters: [?Images.poster(series)]),
          children: [
            Text(tr.showOfTheYear, style: TextStyle(fontSize: 26, color: Colors.white70)),
            Text(series.name, style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
            Text(tr.episodesWatched(s.topSeriesEpisodes), style: const TextStyle(fontSize: 26, color: Colors.white70)),
          ],
        ),
      if (s.topActor case final actor?)
        _Slide(
          colors: const [Color(0xFF1F6B3A), Color(0xFF06140B)],
          background: backdrop(s.actorTitle),
          children: [
            Text(tr.seenMostOften, style: TextStyle(fontSize: 26, color: Colors.white70)),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: JfImage(
                      url: ref
                          .watch(apiProvider)
                          .imageUrlOrNull(
                            actor.imageTag == null ? null : ImageRef(actor.id, ImageType.primary, actor.imageTag!),
                            fillWidth: 300,
                            fillHeight: 300,
                          ),
                      alignment: Alignment.topCenter,
                      fallback: const Icon(Icons.person_rounded, size: 64, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actor.name, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
                    Text(tr.inTitles(actor.count), style: const TextStyle(fontSize: 26, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
      if (s.bingeDay case final day? when s.bingeMinutes >= 90)
        _Slide(
          colors: const [Color(0xFF6E1E1E), Color(0xFF160606)],
          background: backdrop(s.bingeTitles.firstOrNull),
          side: _PosterFan(posters: [for (final t in s.bingeTitles) ?Images.poster(t)]),
          children: [
            Text(tr.biggestMarathon, style: TextStyle(fontSize: 26, color: Colors.white70)),
            Text(
              formatWeekdayDate(day),
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
            Text(
              tr.inOneDay(formatRuntime(Duration(minutes: s.bingeMinutes))),
              style: const TextStyle(fontSize: 26, color: Colors.white70),
            ),
          ],
        ),
      if (favHour != null)
        _Slide(
          colors: const [Color(0xFF2C2366), Color(0xFF09071A)],
          background: backdrop(s.hourTitle),
          children: [
            Text(_watcherType(favHour), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
            Text(tr.favoriteHourText(favHour), style: const TextStyle(fontSize: 24, color: Colors.white70)),
            const SizedBox(height: 30),
            _HourChart(histogram: s.hourHistogram),
          ],
        ),
      _Slide(
        colors: const [Color(0xFF3B1E6E), Color(0xFF0B0B18)],
        wall: posters,
        children: [
          RepaintBoundary(
            key: _summaryKey,
            child: _SummaryCard(stats: s, appName: name, posters: posters.take(6).toList()),
          ),
        ],
      ),
    ];
  }

  String _timeComparison(int minutes) {
    final days = minutes / 1440;
    if (days >= 1) return tr.daysInARow(tr.decimal(days, 1));
    final titanic = minutes / 195;
    if (titanic >= 1) return tr.asLongAsTitanic(tr.decimal(titanic, 1));
    return '';
  }

  static String _watcherType(int hour) => switch (hour) {
    >= 22 || <= 3 => tr.nightOwl,
    >= 4 && <= 11 => tr.earlyBird,
    >= 17 && <= 21 => tr.eveningWatcher,
    _ => tr.afternoonWatcher,
  };
}

/// Eine Karte: Farbverlauf, darüber ein Bild aus dem eigenen Jahr (langsam zoomend) oder
/// eine Posterwand, dann die Farbe der Karte (links dichter, damit der Text lesbar bleibt).
class _Slide extends ConsumerWidget {
  const _Slide({required this.colors, required this.children, this.background, this.wall = const [], this.side});

  final List<Color> colors;
  final List<Widget> children;

  /// Großes Hintergrundbild.
  final ImageRef? background;

  /// Posterwand im Hintergrund (wenn es kein Hintergrundbild gibt).
  final List<ImageRef> wall;

  /// Bild rechts neben dem Text (z. B. Poster) – nur in breiten Fenstern.
  final Widget? side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final [base, deep] = colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null)
            _KenBurns(
              child: Opacity(
                opacity: 0.7,
                child: JfImage(url: api.imageUrlOrNull(background, maxWidth: 1920), blurHash: background!.blurHash),
              ),
            )
          else if (wall.isNotEmpty)
            _PosterWall(posters: wall),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [deep.withValues(alpha: 0.94), base.withValues(alpha: 0.6), base.withValues(alpha: 0.2)],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [deep.withValues(alpha: 0.9), deep.withValues(alpha: 0)],
                stops: const [0, 0.45],
              ),
            ),
          ),
          _Glow(color: base),
          Padding(
            padding: const EdgeInsets.fromLTRB(kPageGutter * 1.5, kTitleBarHeight + 40, kPageGutter * 1.5, 110),
            child: _Rise(
              child: LayoutBuilder(
                builder: (context, box) {
                  final text = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
                  final side = this.side;
                  if (side == null || box.maxWidth < 1050) return text;
                  return Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 40),
                      _Rise(delay: 0.25, child: side),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Einblenden von unten (beim Erscheinen der Karte); [delay] als Anteil der Dauer.
class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (700 * (1 + delay)).round()),
      curve: Interval(delay / (1 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Langsames Heranzoomen und Schwenken ("Ken Burns") über die Zeit einer Karte.
class _KenBurns extends StatelessWidget {
  const _KenBurns({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: WrappedScreen.slideTime + const Duration(seconds: 2),
        builder: (context, t, child) =>
            Transform.scale(scale: 1.04 + 0.1 * t, alignment: Alignment(0.4 - 0.5 * t, -0.2), child: child),
        child: child,
      ),
    );
  }
}

/// Schräge Wand aus Postern des Jahres, die langsam nach oben wandert.
class _PosterWall extends ConsumerWidget {
  const _PosterWall({required this.posters});

  final List<ImageRef> posters;

  static const _width = 150.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return LayoutBuilder(
      builder: (context, box) {
        // Größer als das Fenster, damit auch gedreht keine Ecke frei bleibt.
        final width = box.maxWidth * 1.5;
        final height = box.maxHeight * 1.7;
        final columns = (width / (_width + _gap)).ceil();
        final rows = (height / (_width * 1.5 + _gap)).ceil();
        return ClipRect(
          child: Opacity(
            opacity: 0.5,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: WrappedScreen.slideTime + const Duration(seconds: 2),
              builder: (context, t, child) => Transform.translate(offset: Offset(0, -80 * t), child: child),
              child: OverflowBox(
                maxWidth: width,
                maxHeight: height,
                child: Transform.rotate(
                  angle: -0.16,
                  child: Wrap(
                    spacing: _gap,
                    runSpacing: _gap,
                    children: [
                      for (var i = 0; i < columns * rows; i++)
                        // Versetzt wiederholen, damit gleiche Poster nicht untereinander stehen.
                        _PosterImage(
                          ref: posters[(i + (i ~/ columns) * 3) % posters.length],
                          url: api.imageUrlOrNull(
                            posters[(i + (i ~/ columns) * 3) % posters.length],
                            fillWidth: 300,
                            fillHeight: 450,
                          ),
                          width: _width,
                          shadow: false,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fächer aus bis zu vier Postern (rechts neben dem Text).
class _PosterFan extends ConsumerWidget {
  const _PosterFan({required this.posters});

  final List<ImageRef> posters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final shown = posters.take(4).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const width = 210.0;
    const step = 64.0;
    return SizedBox(
      width: width + step * (shown.length - 1) + 30,
      height: width * 1.5 + 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Das wichtigste Poster liegt oben.
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: step * (shown.length - 1 - i) + 15,
              top: 30 + i * 8.0,
              child: Transform.rotate(
                angle: (i - (shown.length - 1) / 2) * -0.07,
                child: _PosterImage(
                  ref: shown[i],
                  url: api.imageUrlOrNull(shown[i], fillWidth: 420, fillHeight: 630),
                  width: width - i * 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ein Poster mit runden Ecken (und Schatten).
class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.ref, required this.url, required this.width, this.shadow = true});

  final ImageRef ref;
  final String? url;
  final double width;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.5,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(width * 0.07),
        boxShadow: shadow ? const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14))] : null,
      ),
      child: JfImage(url: url, blurHash: ref.blurHash),
    );
  }
}

/// Weicher Lichtfleck in der Farbe der Karte, der langsam wandert.
class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: WrappedScreen.slideTime,
        curve: Curves.easeInOut,
        builder: (context, t, _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.9 + 0.5 * t, -0.8 + 0.3 * t),
              radius: 1.2,
              colors: [Color.lerp(color, Colors.white, 0.15)!.withValues(alpha: 0.55), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zahl, die beim Erscheinen hochzählt.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, this.decimals = 0, this.suffix = ''});

  final double value;
  final TextStyle style;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text('${tr.decimal(v, decimals)}$suffix', style: style),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountUp(
          value: value.toDouble(),
          style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1),
        ),
        Text(label, style: const TextStyle(fontSize: 24, color: Colors.white70)),
      ],
    );
  }
}

class _GenreBar extends StatelessWidget {
  const _GenreBar({required this.label, required this.minutes, required this.max});

  final String label;
  final int minutes;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 420,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: max == 0 ? 0 : minutes / max),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v.clamp(0.02, 1.0),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(tr.hours((minutes / 60).round()), style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _HourChart extends StatelessWidget {
  const _HourChart({required this.histogram});

  final List<int> histogram;

  @override
  Widget build(BuildContext context) {
    final max = histogram.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var h = 0; h < 24; h++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: max == 0 ? 0 : histogram[h] / max),
                    duration: Duration(milliseconds: 600 + h * 30),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      width: 18,
                      height: 4 + 100 * v,
                      decoration: BoxDecoration(
                        color: histogram[h] == max ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 16,
                    child: Text(h % 6 == 0 ? '$h' : '', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Abschlusskarte (auch als Bild speicherbar).
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.stats, required this.appName, this.posters = const []});

  final WrappedStats stats;
  final String appName;

  /// Die meistgeschauten Titel als kleine Poster-Reihe.
  final List<ImageRef> posters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    Widget stat(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
    return Container(
      width: 620,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B2A9E), Color(0xFF1D7FB0)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr.recapTitle(appName, stats.year), style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 44,
            runSpacing: 18,
            children: [
              stat('${(stats.totalMinutes / 60).round()}', tr.hoursWord),
              stat('${stats.movies}', tr.moviesTitle),
              stat('${stats.episodes}', tr.episodesTitle),
              stat('${stats.series}', tr.showsTitle),
            ],
          ),
          const SizedBox(height: 22),
          if (stats.topGenres.firstOrNull case final g?) _line(tr.favoriteGenreShort, g.$1),
          if (stats.topSeries case final series?) _line(tr.showOfTheYearShort, series.name),
          if (stats.topActor case final actor?) _line(tr.seenMostOften, actor.name),
          if (stats.favoriteHour case final hour?) _line(tr.favoriteTime, tr.timeOfDay(hour)),
          if (posters.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                for (final p in posters)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _PosterImage(
                      ref: p,
                      url: api.imageUrlOrNull(p, fillWidth: 180, fillHeight: 270),
                      width: 82,
                      shadow: false,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        SizedBox(
          width: 200,
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ],
    ),
  );
}
