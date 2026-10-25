import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../core/route_observer.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/rating_badges.dart';
import 'home_providers.dart';
import '../../l10n/strings.dart';
import '../../core/system_certs.dart';
import '../../core/image_cache.dart';

/// Großes Banner oben auf der Startseite. Wechselt alle paar Sekunden
/// mit Überblendung und langsamem Zoom ("Ken-Burns-Effekt").
class HeroBanner extends ConsumerStatefulWidget {
  const HeroBanner({super.key, required this.height});

  final double height;

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> with RouteAware, SingleTickerProviderStateMixin {
  static const _interval = Duration(seconds: 9);
  static const _trailerDelay = Duration(seconds: 4);

  /// Stumme Trailer laufen höchstens so lange, dann geht es weiter. Mit Ton (jemand schaut
  /// bewusst zu) läuft der Trailer bis zum Ende.
  static const _trailerMax = Duration(seconds: 30);

  int _index = 0;
  bool _hovered = false;

  /// Zeit bis zum nächsten Titel – treibt das Weiterblättern und den Fortschritt im aktiven
  /// Punkt. Hält an, solange die Maus auf Text/Punkten steht, ein Trailer läuft oder eine
  /// andere Seite offen ist.
  late final AnimationController _cycle = AnimationController(vsync: this, duration: _interval)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _pageVisible) _goTo(_index + 1);
    });

  // --- Trailer im Hintergrund ---
  Player? _trailerPlayer;
  VideoController? _trailerVideo;
  StreamSubscription<bool>? _trailerPlayingSub;
  StreamSubscription<bool>? _trailerDoneSub;
  Timer? _trailerTimer;
  Timer? _trailerLimit;
  String? _trailerItemId;
  bool _trailerVisible = false;
  bool _muted = true;
  bool _pageVisible = true;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _cycle.dispose();
    _trailerTimer?.cancel();
    _trailerLimit?.cancel();
    _trailerPlayingSub?.cancel();
    _trailerDoneSub?.cancel();
    _trailerPlayer?.dispose();
    super.dispose();
  }

  // Andere Seite geöffnet → Trailer anhalten und seinen Player freigeben (ein eigener
  // Video-Player belegt um die 60 MB – die braucht man beim Schauen woanders); zurück → neu.
  @override
  void didPushNext() {
    _pageVisible = false;
    _syncCycle();
    _stopTrailer();
    _releaseTrailerPlayer();
  }

  void _releaseTrailerPlayer() {
    final player = _trailerPlayer;
    if (player == null) return;
    _trailerPlayingSub?.cancel();
    _trailerDoneSub?.cancel();
    _trailerPlayer = null;
    if (mounted) setState(() => _trailerVideo = null);
    player.dispose();
  }

  @override
  void didPopNext() {
    _pageVisible = true;
    _restartTimer();
    _scheduleTrailer();
  }

  void _restartTimer() {
    _cycle.value = 0;
    _syncCycle();
  }

  /// Weiterlaufen lassen oder anhalten – je nach Maus, Trailer und sichtbarer Seite.
  void _syncCycle() {
    if (_hovered || _trailerVisible || !_pageVisible) {
      _cycle.stop();
    } else if (!_cycle.isAnimating && _cycle.value < 1) {
      _cycle.forward();
    }
  }

  void _advance(int index) {
    _stopTrailer();
    setState(() => _index = index);
    _scheduleTrailer();
  }

  void _goTo(int index) {
    _advance(index);
    _restartTimer();
  }

  /// Nach kurzer Zeit den Trailer des aktuellen Titels starten (falls vorhanden).
  void _scheduleTrailer() {
    _trailerTimer?.cancel();
    if (!ref.read(settingsProvider).bannerTrailers || !_pageVisible) return;
    final items = ref.read(featuredProvider).value ?? const <BaseItem>[];
    if (items.isEmpty) return;
    final item = items[_index % items.length];
    _trailerTimer = Timer(_trailerDelay, () => _startTrailer(item));
  }

  Future<void> _startTrailer(BaseItem item) async {
    final api = ref.read(apiProvider);
    final trailer = await api.getTrailer(item.id);
    if (trailer == null || !mounted || !_pageVisible) return;
    final items = ref.read(featuredProvider).value ?? const <BaseItem>[];
    if (items.isEmpty || items[_index % items.length].id != item.id) return; // inzwischen weitergeblättert

    final player = _trailerPlayer ??= Player(
      configuration: const PlayerConfiguration(title: 'Jellyflex Trailer', bufferSize: 32 * 1024 * 1024),
    );
    _trailerVideo ??= VideoController(player);
    _trailerItemId = item.id;
    _trailerPlayingSub?.cancel();
    _trailerDoneSub?.cancel();
    _trailerPlayingSub = player.stream.playing.listen((playing) {
      // Erst einblenden, wenn wirklich Bilder kommen.
      if (playing && mounted && _trailerItemId == item.id) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted || _trailerItemId != item.id || _trailerVisible) return;
          setState(() => _trailerVisible = true);
          _syncCycle();
          _trailerLimit?.cancel();
          _trailerLimit = Timer(_trailerMax, () {
            if (mounted && _muted && _trailerItemId == item.id) _goTo(_index + 1);
          });
        });
      }
    });
    _trailerDoneSub = player.stream.completed.listen((done) {
      if (done && mounted && _trailerItemId == item.id) _goTo(_index + 1);
    });
    await player.setVolume(_muted ? 0 : 70);
    // Zertifikate prüfen, bevor mit dem Anmelde-Token gestreamt wird.
    await SystemCerts.secure(player);
    final sourceId = trailer.mediaSources.firstOrNull?.id ?? trailer.id;
    await player.open(
      Media(
        api.streamUrl(trailer.id, mediaSourceId: sourceId),
        httpHeaders: {'Authorization': api.authorizationHeader},
      ),
    );
    // Trailer im Hintergrund ohne Untertitel.
    await player.setSubtitleTrack(SubtitleTrack.no());
  }

  void _stopTrailer() {
    _trailerTimer?.cancel();
    _trailerLimit?.cancel();
    _trailerItemId = null;
    _trailerPlayer?.stop();
    if (_trailerVisible && mounted) setState(() => _trailerVisible = false);
    if (mounted) _syncCycle();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _trailerPlayer?.setVolume(_muted ? 0 : 70);
  }

  @override
  Widget build(BuildContext context) {
    // Erste Daten da → ersten Trailer einplanen.
    ref.listen(featuredProvider, (prev, next) {
      if ((prev?.value ?? const []).isEmpty && (next.value ?? const []).isNotEmpty) _scheduleTrailer();
    });
    // Trailer in den Einstellungen ausgeschaltet → laufenden sofort beenden.
    ref.listen(settingsProvider.select((s) => s.bannerTrailers), (_, on) => on ? _scheduleTrailer() : _stopTrailer());
    final items = ref.watch(featuredProvider).value ?? const <BaseItem>[];
    final api = ref.watch(apiProvider);
    final width = MediaQuery.sizeOf(context).width;

    if (items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surface, AppColors.background],
            ),
          ),
        ),
      );
    }

    final current = _index % items.length;
    final item = items[current];
    final backdrop = Images.backdrop(item);

    // Nur über Text, Knöpfen und Punkten anhalten – das Banner ist zu groß, als dass die Maus
    // sonst je woanders stünde.
    Widget pauseOnHover(Widget child) => MouseRegion(
      onEnter: (_) {
        _hovered = true;
        _syncCycle();
      },
      onExit: (_) {
        _hovered = false;
        _syncCycle();
      },
      child: child,
    );

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1100),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _KenBurnsBackdrop(
                key: ValueKey(item.id),
                url: api.imageUrlOrNull(backdrop, maxWidth: screenImageWidth(context)),
                blurHash: backdrop?.blurHash,
              ),
            ),
          ),
          // Trailer blendet weich über das Hintergrundbild. Der Platz bleibt immer im Baum –
          // sonst baut Flutter den Rest des Banners neu und der Fokus (Tastatur/Controller) ginge verloren.
          Positioned.fill(
            child: _trailerVideo == null
                ? const SizedBox.shrink()
                : IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _trailerVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOut,
                      child: ClipRect(
                        child: Video(
                          controller: _trailerVideo!,
                          controls: NoVideoControls,
                          fit: BoxFit.cover,
                          fill: Colors.transparent,
                          wakelock: false,
                        ),
                      ),
                    ),
                  ),
          ),
          // Abdunkeln links (für den Text) und unten (Übergang zu den Reihen).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0, 0.35, 0.75],
                  colors: [
                    AppColors.background.withAlpha(0xF0),
                    AppColors.background.withAlpha(0x99),
                    AppColors.background.withAlpha(0x00),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0, 0.35, 1],
                  colors: [
                    AppColors.background,
                    AppColors.background.withAlpha(0x00),
                    AppColors.background.withAlpha(0x55),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: kPageGutter,
            bottom: 84,
            width: math.min(600, width * 0.46),
            child: pauseOnHover(
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: _HeroInfo(key: ValueKey(item.id), item: item),
              ),
            ),
          ),
          Positioned(
            left: kPageGutter,
            bottom: 40,
            child: pauseOnHover(
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    GestureDetector(
                      onTap: () => _goTo(i),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        // Der aktive Punkt füllt sich bis zum nächsten Titel (wie bei Stories).
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 8),
                          width: i == current ? 36 : 8,
                          height: 8,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withValues(alpha: i == current ? 0.35 : 0.3),
                          ),
                          alignment: Alignment.centerLeft,
                          child: i == current
                              ? AnimatedBuilder(
                                  animation: _cycle,
                                  builder: (context, _) => FractionallySizedBox(
                                    widthFactor: _cycle.value,
                                    heightFactor: 1,
                                    child: const ColoredBox(color: Colors.white),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Ton an/aus, solange ein Trailer läuft.
          Positioned(
            right: kPageGutter,
            bottom: 84,
            child: AnimatedOpacity(
              opacity: _trailerVisible ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: ExcludeFocus(
                excluding: !_trailerVisible,
                child: IgnorePointer(
                  ignoring: !_trailerVisible,
                  child: CircleIconButton(
                    icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    tooltip: _muted ? tr.soundOn : tr.soundOff,
                    size: 46,
                    onPressed: _toggleMute,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KenBurnsBackdrop extends StatelessWidget {
  const _KenBurnsBackdrop({super.key, required this.url, required this.blurHash});

  final String? url;
  final String? blurHash;

  @override
  Widget build(BuildContext context) {
    // ClipRect: Das gezoomte Bild darf nicht über das Banner hinausragen.
    return RepaintBoundary(
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.07),
          duration: const Duration(seconds: 14),
          curve: Curves.easeOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, alignment: Alignment.topRight, child: child),
          child: JfImage(url: url, blurHash: blurHash, alignment: Alignment.topCenter),
        ),
      ),
    );
  }
}

class _HeroInfo extends ConsumerWidget {
  const _HeroInfo({super.key, required this.item});

  final BaseItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final logo = api.imageUrlOrNull(Images.logo(item), maxWidth: 800);
    const shadow = [Shadow(color: Colors.black87, blurRadius: 16)];

    final meta = <String>[
      ?yearLabel(item),
      if (item.isMovie && item.runtime != null) formatRuntime(item.runtime!),
      if (item.isSeries && item.childCount != null) tr.seasonsCount(item.childCount!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TitleLogo(logoUrl: logo, title: item.name, maxHeight: 130, fontSize: 52),
        const SizedBox(height: 18),
        DefaultTextStyle.merge(
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, shadows: shadow),
          child: Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.communityRating != null) RatingBadges(item: item, critics: false),
              for (final m in meta) Text(m),
              if (item.officialRating != null) RatingBadge(item.officialRating!),
            ],
          ),
        ),
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.genres.take(3).join('  ·  '),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, shadows: shadow),
          ),
        ],
        if (item.overview != null) ...[
          const SizedBox(height: 16),
          Text(
            item.overview!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15.5, height: 1.5, color: Color(0xFFDADCE5), shadows: shadow),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            if (item.isMovie)
              PrimaryButton(
                label: item.userData.hasResumePosition ? tr.resume : tr.play,
                icon: Icons.play_arrow_rounded,
                onPressed: () => playItem(context, item),
              )
            else
              PrimaryButton(label: tr.watch, icon: Icons.play_arrow_rounded, onPressed: () => openItem(context, item)),
            const SizedBox(width: 12),
            GlassButton(label: tr.moreInfo, icon: Icons.info_outline_rounded, onPressed: () => openItem(context, item)),
          ],
        ),
      ],
    );
  }
}

/// Zeigt das Titel-Logo, oder – falls keins existiert – den Titel als Text.
class TitleLogo extends StatelessWidget {
  const TitleLogo({super.key, required this.logoUrl, required this.title, this.maxHeight = 120, this.fontSize = 48});

  final String? logoUrl;
  final String title;
  final double maxHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 20)],
      ),
    );
    if (logoUrl == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 460),
      child: Image(
        image: CachedNetworkImage(logoUrl!),
        fit: BoxFit.contain,
        alignment: Alignment.bottomLeft,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              ),
        errorBuilder: (_, _, _) => text,
      ),
    );
  }
}

/// Kleines umrandetes Altersfreigabe-Abzeichen ("FSK-12", "PG-13" …).
class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
