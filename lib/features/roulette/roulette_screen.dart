import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/backdrop_slideshow.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../details/details_screen.dart';
import '../../l10n/strings.dart';
import '../../core/ui_sounds.dart';

enum _Kind { movies, series, both }

/// "Überrasch mich": Ein Poster-Rad dreht sich wie ein Spielautomat und
/// bleibt auf einem zufälligen Titel stehen – mit Filtern für Art, Genre,
/// nur Ungesehenes und "bis wann muss der Film vorbei sein".
class RouletteScreen extends ConsumerStatefulWidget {
  const RouletteScreen({super.key});

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen> with TickerProviderStateMixin {
  static const _posterWidth = 170.0;
  static const _gap = 22.0;

  final _random = math.Random();
  final _scroll = ScrollController();
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  late final _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  _Kind _kind = _Kind.movies;
  bool _unplayedOnly = true;
  String? _genre;

  /// Spätestes Ende (Stunde, 24 = Mitternacht); `null` = egal.
  int? _endBy;

  List<String> _genres = const [];
  List<BaseItem> _reel = const [];
  double _offset = 0;
  double _spinFrom = 0;
  double _spinTo = 0;
  BaseItem? _winner;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _spin.addListener(() {
      final t = const Cubic(0.12, 0.9, 0.22, 1).transform(_spin.value);
      final next = _spinFrom + (_spinTo - _spinFrom) * t;
      // Jedes Poster, das an der Mitte vorbeizieht, macht "tick".
      if ((next + 0.5).floor() != (_offset + 0.5).floor()) UiSounds.play(UiSound.tick);
      setState(() => _offset = next);
    });
    _spin.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _winner = _reel[_spinTo.round()]);
        _confetti.forward(from: 0);
        UiSounds.play(UiSound.win);
        // Infos zum Gewinner ins Bild holen (bei kleinen Fenstern).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          );
        });
      }
    });
    _loadGenres();
    _fillReel();
  }

  @override
  void dispose() {
    _spin.dispose();
    _confetti.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _types => switch (_kind) {
    _Kind.movies => 'Movie',
    _Kind.series => 'Series',
    _Kind.both => 'Movie,Series',
  };

  Future<void> _loadGenres() async {
    try {
      final genres = await ref.read(apiProvider).getGenres(null, includeItemTypes: _types);
      if (mounted) setState(() => _genres = genres);
    } catch (_) {}
  }

  /// Passende Titel vom Server holen (zufällig) und lokal nach Laufzeit filtern.
  Future<List<BaseItem>> _candidates() async {
    final items = await ref
        .read(apiProvider)
        .getRandomPicks(includeItemTypes: _types, unplayedOnly: _unplayedOnly, genre: _genre);
    final wanted = _types.split(',');
    final limit = _endBy == null ? null : _minutesUntil(_endBy!);
    return items.where((i) {
      if (!wanted.contains(i.type)) return false;
      // "Fertig bis" gilt für Filme; Serienfolgen sind ohnehin kurz.
      if (limit != null && i.isMovie) {
        final runtime = i.runtime;
        if (runtime == null || runtime.inMinutes + 5 > limit) return false;
      }
      return true;
    }).toList();
  }

  int _minutesUntil(int hour) {
    final now = DateTime.now();
    var end = DateTime(now.year, now.month, now.day, hour % 24);
    if (hour >= 24 || !end.isAfter(now)) end = end.add(const Duration(days: 1));
    return end.difference(now).inMinutes;
  }

  /// Startbild: ein ruhendes Rad mit zufälligen Postern.
  Future<void> _fillReel() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final items = await _candidates();
      if (!mounted) return;
      setState(() {
        _reel = items;
        _offset = items.length > 2 ? 2 : 0;
        _winner = null;
        _message = items.isEmpty ? tr.nothingFoundLoosen : null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = tr.serverUnreachable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _spinNow() async {
    if (_spin.isAnimating || _loading) return;
    setState(() {
      _loading = true;
      _winner = null;
      _message = null;
    });
    List<BaseItem> items;
    try {
      items = await _candidates();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = tr.serverUnreachable;
        });
      }
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      setState(() {
        _loading = false;
        _message = tr.nothingFoundLoosen;
      });
      return;
    }
    // Das Rad: die gerade sichtbaren Poster, dann viele zufällige, der Gewinner
    // und ein paar dahinter (damit rechts vom Gewinner nichts leer ist).
    final visibleStart = math.max(0, _offset.round() - 4);
    final visible = _reel.isEmpty
        ? <BaseItem>[]
        : _reel.sublist(visibleStart, math.min(_reel.length, _offset.round() + 5));
    final winner = items[_random.nextInt(items.length)];
    final filler = <BaseItem>[];
    while (filler.length < 34) {
      filler.addAll(items..shuffle(_random));
    }
    final reel = [...visible, ...filler.take(34), winner, ...filler.skip(34).take(5), ...items.take(5)];
    setState(() {
      _reel = reel;
      _spinFrom = (_offset.round() - visibleStart).toDouble().clamp(0, reel.length - 1);
      _offset = _spinFrom;
      _spinTo = (visible.length + 34).toDouble();
      _loading = false;
    });
    await _spin.forward(from: 0);
  }

  Future<void> _play(BaseItem item) async {
    if (!item.isSeries) return playItem(context, item);
    // Serie: nächste (oder erste) Folge abspielen.
    final episode = await ref.read(seriesNextUpProvider(item.id).future);
    if (episode != null && mounted) playItem(context, episode);
  }

  @override
  Widget build(BuildContext context) {
    final winner = _winner;
    final backdrop = winner == null ? null : Images.backdrop(winner);
    return Scaffold(
      body: Stack(
        children: [
          // Hintergrund: Bild des Gewinners, sanft eingeblendet.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: backdrop == null
                  ? const SizedBox.expand(key: ValueKey('none'))
                  : Opacity(
                      key: ValueKey(winner!.id),
                      opacity: 0.35,
                      child: BackdropSlideshow(images: [backdrop]),
                    ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withAlpha(0xCC),
                    AppColors.background.withAlpha(0x99),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(0, kTitleBarHeight + 24, 0, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeader(
                        title: tr.surpriseMe,
                        subtitle: tr.letChanceDecide,
                        icon: Icons.casino_rounded,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),
                      _filters(),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _ReelView(
                  items: _reel,
                  offset: _offset,
                  posterWidth: _posterWidth,
                  gap: _gap,
                  spinning: _spin.isAnimating,
                  winnerFound: winner != null,
                  confetti: _confetti,
                ),
                const SizedBox(height: 26),
                Center(
                  child: PrimaryButton(
                    label: _spin.isAnimating ? tr.spinning : (winner == null ? tr.spin : tr.spinAgain),
                    icon: Icons.casino_rounded,
                    loading: _loading,
                    onPressed: _spin.isAnimating ? null : _spinNow,
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Center(
                      child: Text(_message!, style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: winner == null
                      ? const SizedBox(height: 40)
                      : _WinnerCard(
                          key: ValueKey(winner.id),
                          item: winner,
                          onPlay: () => _play(winner),
                          onDetails: () => context.push('/item/${winner.id}'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    void refilter(VoidCallback change) {
      setState(change);
      _fillReel();
    }

    String endLabel(int? h) => h == null ? tr.anyTime : (h == 24 ? tr.midnight : tr.timeOfDay(h));
    final now = DateTime.now().hour;
    // Sinnvolle Uhrzeiten: die nächsten Stunden bis 2 Uhr nachts.
    final hours = [for (var h = now + 2; h <= 26; h++) h].take(6).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (kind, label) in [(_Kind.movies, tr.movies), (_Kind.series, tr.shows), (_Kind.both, tr.both)])
          _Chip(
            label: label,
            selected: _kind == kind,
            onTap: () => refilter(() {
              _kind = kind;
              _genre = null;
              _loadGenres();
            }),
          ),
        const SizedBox(width: 10),
        _Chip(
          label: tr.unwatchedOnly,
          icon: _unplayedOnly ? Icons.check_rounded : null,
          selected: _unplayedOnly,
          onTap: () => refilter(() => _unplayedOnly = !_unplayedOnly),
        ),
        _MenuChip<String?>(
          label: tr.genreLabel(_genre ?? tr.all),
          options: [(null, tr.all), for (final g in _genres) (g, g)],
          onSelected: (g) => refilter(() => _genre = g),
        ),
        if (_kind != _Kind.series)
          _MenuChip<int?>(
            label: tr.finishedBy(endLabel(_endBy)),
            options: [(null, tr.anyTime), for (final h in hours) (h, endLabel(h % 24 == 0 ? 24 : h % 24))],
            onSelected: (h) => refilter(() => _endBy = h == null ? null : (h % 24 == 0 ? 24 : h % 24)),
          ),
      ],
    );
  }
}

/// Das Poster-Rad. [offset] = Index des Posters in der Mitte (mit Nachkommastellen).
class _ReelView extends ConsumerWidget {
  const _ReelView({
    required this.items,
    required this.offset,
    required this.posterWidth,
    required this.gap,
    required this.spinning,
    required this.winnerFound,
    required this.confetti,
  });

  final List<BaseItem> items;
  final double offset;
  final double posterWidth;
  final double gap;
  final bool spinning;
  final bool winnerFound;
  final Animation<double> confetti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final posterHeight = posterWidth * 1.5;
    final step = posterWidth + gap;
    return SizedBox(
      height: posterHeight * 1.2 + 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = constraints.maxWidth / 2;
          final first = math.max(0, (offset - center / step - 1).floor());
          final last = math.min(items.length - 1, (offset + center / step + 1).ceil());
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = first; i <= last; i++)
                () {
                  final distance = (i - offset).abs();
                  final focus = (1 - distance).clamp(0.0, 1.0);
                  final scale = 0.86 + 0.3 * focus;
                  final x = center + (i - offset) * step - posterWidth / 2;
                  final poster = Images.poster(items[i]);
                  return Positioned(
                    left: x,
                    top: 10 + (posterHeight * 1.2 - posterHeight) / 2,
                    width: posterWidth,
                    height: posterHeight,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: (1 - distance * 0.18).clamp(0.35, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (winnerFound && distance < 0.5 ? AppColors.accent : Colors.black).withValues(
                                  alpha: winnerFound && distance < 0.5 ? 0.6 : 0.4,
                                ),
                                blurRadius: winnerFound && distance < 0.5 ? 40 : 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.9 * focus), width: 2.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: JfImage(
                              url: api.imageUrlOrNull(poster, fillWidth: 340, fillHeight: 510),
                              blurHash: poster?.blurHash,
                              fallback: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(items[i].name, textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
              // Markierung oben und unten in der Mitte.
              Positioned(
                left: center - 10,
                top: 0,
                child: Icon(Icons.arrow_drop_down_rounded, size: 34, color: AppColors.accent),
              ),
              Positioned(
                left: center - 10,
                bottom: -6,
                child: Icon(Icons.arrow_drop_up_rounded, size: 34, color: AppColors.accent),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: confetti,
                    builder: (context, _) => CustomPaint(painter: _ConfettiPainter(confetti.value)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kleiner Konfetti-Regen aus der Mitte, wenn das Rad stehen bleibt.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;
  static final _pieces = List.generate(46, (i) {
    final r = math.Random(i * 7919);
    return (
      angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4,
      speed: 260 + r.nextDouble() * 320,
      spin: (r.nextDouble() - 0.5) * 12,
      color: [
        const Color(0xFF8B5CF6),
        const Color(0xFF22D3EE),
        const Color(0xFFF472B6),
        const Color(0xFFFACC15),
        Colors.white,
      ][i % 5],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height / 2);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in _pieces) {
      final d = p.speed * t;
      final pos = origin + Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + 420 * t * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      canvas.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), Paint()..color = p.color.withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({super.key, required this.item, required this.onPlay, required this.onDetails});

  final BaseItem item;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final runtime = item.runtime;
    final meta = [
      ?yearLabel(item),
      if (runtime != null && !item.isSeries) formatRuntime(runtime),
      if (runtime != null && !item.isSeries) tr.endsAt(formatClock(DateTime.now().add(runtime))),
      if (item.communityRating != null) '★ ${item.communityRating!.toStringAsFixed(1)}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 30, kPageGutter, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(meta.join('  ·  '), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              if (item.genres.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.genres.join('  ·  '), style: TextStyle(color: AppColors.textMuted)),
              ],
              if (item.overview != null) ...[
                const SizedBox(height: 14),
                Text(
                  item.overview!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5, color: Color(0xFFD5D7E0)),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryButton(
                    label: item.isSeries ? tr.startSeries : tr.play,
                    icon: Icons.play_arrow_rounded,
                    onPressed: onPlay,
                  ),
                  GlassButton(label: tr.details, icon: Icons.info_outline_rounded, onPressed: onDetails),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: hovered ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? AppColors.background : AppColors.textPrimary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.background : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({required this.label, required this.options, required this.onSelected});

  final String label;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (chipContext) => Focusable(
        onTap: () async {
          final box = chipContext.findRenderObject()! as RenderBox;
          final overlay = Overlay.of(chipContext).context.findRenderObject()! as RenderBox;
          final pos = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
          final index = await showMenu<int>(
            context: chipContext,
            position: RelativeRect.fromRect(pos & const Size(1, 1), Offset.zero & overlay.size),
            constraints: const BoxConstraints(minWidth: 200, maxHeight: 420),
            items: [for (var i = 0; i < options.length; i++) PopupMenuItem(value: i, child: Text(options[i].$2))],
          );
          if (index != null) onSelected(options[index].$1);
        },
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.only(left: 16, right: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: hovered ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
