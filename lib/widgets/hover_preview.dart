import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/image_cache.dart';
import '../core/images.dart';
import '../core/jellyfin_api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/settings.dart';
import 'jf_image.dart';

/// Lebendige Vorschau auf Karten: Nach kurzem Verweilen (Maus, Tastatur, Controller) blättert
/// die Karte durch Szenen des Titels – Trickplay-Bilder vom eigenen Server, kein Video.
/// Ohne Szenenbilder (Serien, Staffeln, Titel ohne Trickplay): langsamer Zoom durch die
/// Hintergrundbilder.
class HoverPreview extends ConsumerStatefulWidget {
  const HoverPreview({super.key, required this.item, required this.active});

  final BaseItem item;

  /// Karte ist gerade ausgewählt (Maus darüber oder fokussiert).
  final bool active;

  /// Wartezeit, bevor die Vorschau startet – beim schnellen Darüberfahren lädt nichts.
  static const delay = Duration(milliseconds: 650);

  /// So lange bleibt eine Szene stehen.
  static const frameTime = Duration(milliseconds: 1100);

  @override
  ConsumerState<HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends ConsumerState<HoverPreview> {
  Timer? _startTimer;
  Timer? _frameTimer;
  _Preview? _preview;
  int _frame = 0;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule();
  }

  @override
  void didUpdateWidget(HoverPreview old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) widget.active ? _schedule() : _stop();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (!ref.read(settingsProvider).hoverPreview) return;
    _startTimer?.cancel();
    _startTimer = Timer(HoverPreview.delay, _start);
  }

  Future<void> _start() async {
    final api = ref.read(apiProvider);
    final preview = await _previewFor(api, widget.item);
    if (!mounted || !widget.active || preview == null) return;
    // Erst zeigen, wenn das erste Bild da ist (sonst blitzt eine leere Fläche auf).
    await preview.precache(context, api, 0);
    if (!mounted || !widget.active) return;
    setState(() {
      _preview = preview;
      _frame = 0;
      _shown = true;
    });
    _frameTimer?.cancel();
    if (preview.length < 2) return;
    _frameTimer = Timer.periodic(HoverPreview.frameTime, (_) {
      if (!mounted) return;
      final next = (_frame + 1) % preview.length;
      preview.precache(context, api, (next + 1) % preview.length);
      setState(() => _frame = next);
    });
  }

  void _stop() {
    _startTimer?.cancel();
    _frameTimer?.cancel();
    if (_shown) setState(() => _shown = false);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final api = ref.watch(apiProvider);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        child: preview == null
            ? const SizedBox.shrink()
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                // Jede Szene füllt die ganze Karte (sonst bliebe sie in ihrer kleinen Größe).
                layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
                child: KeyedSubtree(
                  key: ValueKey(_frame),
                  child: _SlowZoom(
                    duration: preview.length < 2 ? const Duration(seconds: 8) : HoverPreview.frameTime * 1.5,
                    child: preview.frame(api, _frame),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Leichtes Heranzoomen, damit auch ein einzelnes Bild lebendig wirkt.
class _SlowZoom extends StatelessWidget {
  const _SlowZoom({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.08),
      duration: duration,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Vorschau-Daten eines Titels: Szenenbilder (Trickplay) oder Hintergrundbilder.
sealed class _Preview {
  int get length;
  Widget frame(JellyfinApi api, int index);
  Future<void> precache(BuildContext context, JellyfinApi api, int index);
}

class _ScenePreview extends _Preview {
  _ScenePreview(this.itemId, this.sourceId, this.info, this.frames);

  final String itemId;
  final String sourceId;
  final TrickplayInfo info;

  /// Nummern der gezeigten Vorschaubilder.
  final List<int> frames;

  @override
  int get length => frames.length;

  ImageProvider _tile(JellyfinApi api, int tile) => NetworkImage(
    api.trickplayTileUrl(itemId, sourceId, info.width, tile),
    headers: {'Authorization': api.authorizationHeader},
  );

  int _tileOf(int frame) => frame ~/ (info.tileWidth * info.tileHeight);

  @override
  Future<void> precache(BuildContext context, JellyfinApi api, int index) async {
    try {
      await precacheImage(_tile(api, _tileOf(frames[index])), context);
    } catch (_) {}
  }

  /// Ein Vorschaubild aus der Kachel ausschneiden und die Karte damit füllen.
  @override
  Widget frame(JellyfinApi api, int index) {
    final n = frames[index];
    final inTile = n % (info.tileWidth * info.tileHeight);
    final col = inTile % info.tileWidth;
    final row = inTile ~/ info.tileWidth;
    final w = info.width.toDouble();
    final h = info.height.toDouble();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(-col * w, -row * h),
              child: Image(
                image: _tile(api, _tileOf(n)),
                width: w * info.tileWidth,
                height: h * info.tileHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackdropPreview extends _Preview {
  _BackdropPreview(this.images);

  final List<ImageRef> images;

  @override
  int get length => images.length;

  String? _url(JellyfinApi api, int index) => api.imageUrlOrNull(images[index], maxWidth: 960);

  @override
  Future<void> precache(BuildContext context, JellyfinApi api, int index) async {
    final url = _url(api, index);
    if (url == null) return;
    try {
      await precacheImage(CachedNetworkImage(url), context);
    } catch (_) {}
  }

  @override
  Widget frame(JellyfinApi api, int index) => JfImage(url: _url(api, index), blurHash: images[index].blurHash);
}

/// Schon geladene Vorschauen (auch "keine") – pro Sitzung, höchstens [_cacheSize] Titel.
final _cache = <String, Future<_Preview?>>{};
const _cacheSize = 300;

Future<_Preview?> _previewFor(JellyfinApi api, BaseItem item) {
  final cached = _cache[item.id];
  if (cached != null) return cached;
  if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
  return _cache[item.id] = _load(api, item);
}

Future<_Preview?> _load(JellyfinApi api, BaseItem item) async {
  var full = item;
  if (item.isMovie || item.isEpisode) {
    try {
      // Listen enthalten keine Trickplay-Angaben – der einzelne Titel schon.
      full = await api.getItem(item.id);
      final source = full.mediaSources.firstOrNull;
      final info = source == null ? null : full.trickplay(source.id);
      if (source != null && info != null && info.thumbnailCount >= 20) {
        return _ScenePreview(full.id, source.id, info, scenesFrom(info));
      }
    } catch (_) {
      // Server gerade nicht erreichbar – dann eben die Hintergrundbilder.
    }
  }
  final backdrops = Images.backdrops(full).take(4).toList();
  return backdrops.isEmpty ? null : _BackdropPreview(backdrops);
}

/// Szenen aus drei Kacheln (Anfang, Mitte, Ende) – so muss pro Titel nur wenig geladen
/// werden. Abspann und die allerersten Sekunden bleiben außen vor.
@visibleForTesting
List<int> scenesFrom(TrickplayInfo info) {
  final count = info.thumbnailCount;
  final perTile = info.tileWidth * info.tileHeight;
  final frames = <int>[];
  for (final at in const [0.12, 0.42, 0.72]) {
    final tileStart = (count * at).floor() ~/ perTile * perTile;
    final inThisTile = (count - tileStart).clamp(0, perTile);
    for (final f in const [0.15, 0.5, 0.85]) {
      final n = tileStart + (inThisTile * f).floor();
      if (n < count && !frames.contains(n)) frames.add(n);
    }
  }
  return frames;
}
