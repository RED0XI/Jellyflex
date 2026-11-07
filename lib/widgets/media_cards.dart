import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/images.dart';
import '../core/layouts.dart';
import '../core/models.dart';
import '../core/platform/device.dart';
import '../core/play_queue.dart';
import '../core/session.dart';
import '../core/settings.dart';
import '../features/item_actions.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'focusable.dart';
import 'hover_preview.dart';
import 'jf_image.dart';

/// Kartengrößen – abhängig vom Layout (siehe [AppLayout.cardScale]). Auf dem iPhone fest und kleiner:
/// gut drei Poster bzw. anderthalb Querformat-Karten nebeneinander, wie bei Streaming-Apps üblich.
double get _cardScale => isPhoneDevice ? 0.67 : appLayout.cardScale;
double get kPosterWidth => 168 * _cardScale;
double get kLandscapeWidth => 320 * _cardScale;

/// Platz für Titel unter den Karten (0, wenn das Layout sie im Bild zeigt).
double get kCardTextHeight => appLayout.cardTitles ? 52 : 0;

/// Fernseher: der Titel, dessen Karte gerade den Fokus hat (die Startseite zeigt oben sein Bild und
/// seine Infos).
final tvFocusedItem = ValueNotifier<BaseItem?>(null);

/// Öffnet die Detailseite eines Eintrags – sie wächst aus der angeklickten Karte heraus.
void openItem(BuildContext context, BaseItem item) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    expandFrom(box.localToGlobal(Offset.zero) & box.size);
  }
  context.push('/item/${item.id}');
}

/// Startet die Wiedergabe (ggf. an der gespeicherten Stelle) – optional eine
/// bestimmte Fassung ([mediaSourceId]), wenn es mehrere gibt.
void playItem(
  BuildContext context,
  BaseItem item, {
  bool fromStart = false,
  String? mediaSourceId,
  int? audioIndex,
  int? subtitleIndex,
}) {
  final ticks = item.userData.playbackPositionTicks;
  context.push(
    playPath(
      item.id,
      startTicks: fromStart ? 0 : ticks,
      mediaSourceId: mediaSourceId,
      audioIndex: audioIndex,
      subtitleIndex: subtitleIndex,
    ),
  );
}

/// Adresse des Players mit Startpunkt, Fassung und (auf der Detailseite gewählten) Spuren.
String playPath(String itemId, {int startTicks = 0, String? mediaSourceId, int? audioIndex, int? subtitleIndex}) {
  final query = Uri(
    queryParameters: {
      if (startTicks > 0) 'start': '$startTicks',
      'source': ?mediaSourceId,
      if (audioIndex != null) 'audio': '$audioIndex',
      if (subtitleIndex != null) 'sub': '$subtitleIndex',
    },
  ).query;
  return '/play/$itemId${query.isEmpty ? '' : '?$query'}';
}

/// "Zufällig abspielen": Titel unterhalb von [parentId] mischen und nacheinander abspielen.
Future<void> playShuffled(
  BuildContext context, {
  String? parentId,
  required String includeItemTypes,
  bool unplayedOnly = false,
  String? genre,
}) async {
  final api = ProviderScope.containerOf(context).read(apiProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.of(context);
  try {
    final items = await api.getShuffled(
      parentId,
      includeItemTypes: includeItemTypes,
      unplayedOnly: unplayedOnly,
      genre: genre,
    );
    if (items.isEmpty) {
      messenger?.showSnackBar(SnackBar(content: Text(tr.nothingToShuffle), behavior: SnackBarBehavior.floating));
      return;
    }
    PlayQueue.start([for (final i in items) i.id]);
    router.push('/play/${items.first.id}?queue=1');
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(tr.didNotWork), behavior: SnackBarBehavior.floating));
  }
}

/// Gemeinsame Hover-Logik: leicht vergrößern, Schatten, Rahmen.
class _HoverCard extends StatefulWidget {
  const _HoverCard({
    required this.builder,
    required this.onTap,
    this.onContextMenu,
    this.label,
    this.item,
    this.autofocus = false,
  });

  /// Titel der Karte – am Fernseher wird er beim Fokussieren zu [tvFocusedItem].
  final BaseItem? item;
  final bool autofocus;

  /// Name für Bildschirmleser (in Layouts, die den Titel nur beim Auswählen zeigen).
  final String? label;

  final Widget Function(bool hovered) builder;
  final VoidCallback onTap;

  /// Rechtsklick mit Bildschirmposition.
  final ValueChanged<Offset>? onContextMenu;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Focusable(
      tvRing: false,
      onTap: widget.onTap,
      onSecondaryTap: widget.onContextMenu,
      autofocus: widget.autofocus,
      onFocusChange: isTv && item != null ? (focused) => focused ? tvFocusedItem.value = item : null : null,
      semanticLabel: appLayout.cardTitles ? null : widget.label,
      builder: (context, highlighted) => widget.builder(highlighted),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.hovered,
    required this.aspectRatio,
    required this.child,
    this.title,
    this.subtitle,
    this.alwaysShowTitle = false,
  });

  final bool hovered;
  final double aspectRatio;
  final Widget child;

  /// Titel im Bild – nur in Layouts ohne Titel unter den Karten.
  final String? title;
  final String? subtitle;

  /// Titel immer zeigen (Querformat), sonst nur beim Auswählen.
  final bool alwaysShowTitle;

  @override
  Widget build(BuildContext context) {
    final layout = appLayout;
    final radius = BorderRadius.circular(layout.radius);
    final accent = AppColors.accent;
    final (scale, lift, border, shadow) = switch (layout.focus) {
      FocusStyle.zoom => (
        hovered ? 1.05 : 1.0,
        0.0,
        Border.all(
          color: hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.06),
          width: hovered ? 2 : 1,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: hovered ? 0.55 : 0.25),
          blurRadius: hovered ? 28 : 10,
          offset: Offset(0, hovered ? 12 : 4),
        ),
      ),
      FocusStyle.glow => (
        hovered ? 1.07 : 1.0,
        0.0,
        Border.all(color: hovered ? accent : Colors.white.withValues(alpha: 0.05), width: hovered ? 3 : 1),
        BoxShadow(
          color: hovered ? accent.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.25),
          blurRadius: hovered ? 34 : 10,
          spreadRadius: hovered ? 2 : 0,
        ),
      ),
      FocusStyle.outline => (
        1.0,
        0.0,
        Border.all(color: hovered ? accent : Colors.white.withValues(alpha: 0.06), width: hovered ? 3 : 1),
        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
      ),
      FocusStyle.lift => (
        1.0,
        hovered ? -10.0 : 0.0,
        Border.all(color: Colors.white.withValues(alpha: hovered ? 0.25 : 0.06)),
        BoxShadow(
          color: Colors.black.withValues(alpha: hovered ? 0.6 : 0.2),
          blurRadius: hovered ? 30 : 8,
          offset: Offset(0, hovered ? 18 : 3),
        ),
      ),
    };
    final showTitle = !layout.cardTitles && title != null && (alwaysShowTitle || hovered);

    return AnimatedSlide(
      offset: Offset(0, lift / 200),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(borderRadius: radius, boxShadow: [shadow]),
          foregroundDecoration: BoxDecoration(borderRadius: radius, border: border),
          child: ClipRRect(
            borderRadius: radius,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: !layout.cardTitles && title != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: showTitle ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: _TitleOverlay(title: title!, subtitle: subtitle),
                          ),
                        ),
                      ],
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Titel unten im Bild (Layouts ohne Titel unter den Karten).
class _TitleOverlay extends StatelessWidget {
  const _TitleOverlay({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0xE6000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF)),
            ),
        ],
      ),
    );
  }
}

class _CardLabels extends StatelessWidget {
  const _CardLabels({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (!appLayout.cardTitles) return const SizedBox.shrink();
    return SizedBox(
      height: kCardTextHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 4,
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.25)),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(decoration: BoxDecoration(gradient: AppColors.accentGradient)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleines Abzeichen oben rechts: Haken (gesehen) oder Anzahl ungesehener Folgen.
class _Badge extends StatelessWidget {
  const _Badge(this.item);

  final BaseItem item;

  @override
  Widget build(BuildContext context) {
    final data = item.userData;
    Widget? content;
    if (data.played) {
      content = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
    } else if ((data.unplayedItemCount ?? 0) > 0 && item.isSeries) {
      content = Text('${data.unplayedItemCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700));
    }
    if (content == null) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: content,
      ),
    );
  }
}

/// Hochformat-Karte (Poster).
class PosterCard extends ConsumerWidget {
  const PosterCard({super.key, required this.item, this.width, this.autofocus = false});

  final BaseItem item;
  final bool autofocus;

  /// Breite (Standard: Größe des Layouts).
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final poster = Images.poster(item);
    final width = this.width ?? kPosterWidth;
    final h = _bucket(width * 1.5 * dpr);
    return SizedBox(
      width: width,
      child: _HoverCard(
        item: item,
        autofocus: autofocus,
        label: [cardTitle(item), ?cardSubtitle(item)].join(', '),
        onTap: () => openItem(context, item),
        onContextMenu: (pos) => showItemContextMenu(context, item, pos),
        builder: (hovered) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardFrame(
              hovered: hovered,
              aspectRatio: 2 / 3,
              title: cardTitle(item),
              subtitle: cardSubtitle(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JfImage(
                    url: api.imageUrlOrNull(poster, fillWidth: (h * 2 / 3).round(), fillHeight: h),
                    blurHash: poster?.blurHash,
                    fallback: _TitleFallback(item.name),
                  ),
                  HoverPreview(item: item, active: hovered),
                  _Badge(item),
                  if (progressOf(item) case final p?) _ProgressBar(p),
                ],
              ),
            ),
            _CardLabels(title: cardTitle(item), subtitle: cardSubtitle(item)),
          ],
        ),
      ),
    );
  }
}

/// Querformat-Karte (Weiterschauen, Episoden). Beim Hover erscheint ein Play-Knopf.
class LandscapeCard extends ConsumerWidget {
  const LandscapeCard({
    super.key,
    required this.item,
    this.width,
    this.onTap,
    this.title,
    this.subtitle,
    this.autofocus = false,
  });

  final BaseItem item;
  final bool autofocus;

  /// Breite (Standard: Größe des Layouts).
  final double? width;
  final VoidCallback? onTap;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Images.landscape(item, episodeImages: ref.watch(settingsProvider).episodeImagesInRows);
    final width = this.width ?? kLandscapeWidth;
    final w = _bucket(width * dpr);
    return SizedBox(
      width: width,
      child: _HoverCard(
        item: item,
        autofocus: autofocus,
        label: [title ?? cardTitle(item), ?(subtitle ?? cardSubtitle(item))].join(', '),
        onTap: onTap ?? () => openItem(context, item),
        onContextMenu: (pos) => showItemContextMenu(context, item, pos),
        builder: (hovered) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardFrame(
              hovered: hovered,
              aspectRatio: 16 / 9,
              title: title ?? cardTitle(item),
              subtitle: subtitle ?? cardSubtitle(item),
              alwaysShowTitle: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JfImage(
                    url: api.imageUrlOrNull(image, fillWidth: w, fillHeight: (w * 9 / 16).round()),
                    blurHash: image?.blurHash,
                    fallback: _TitleFallback(cardTitle(item)),
                  ),
                  HoverPreview(item: item, active: hovered),
                  // Unsichtbar nicht antippbar – sonst startet ein Fingertipp aufs Bild sofort das Video.
                  IgnorePointer(
                    ignoring: !hovered,
                    child: AnimatedOpacity(
                      opacity: hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: _PlayCircle(onTap: () => playItem(context, item)),
                      ),
                    ),
                  ),
                  _Badge(item),
                  if (progressOf(item) case final p?) _ProgressBar(p),
                ],
              ),
            ),
            _CardLabels(title: title ?? cardTitle(item), subtitle: subtitle ?? cardSubtitle(item)),
          ],
        ),
      ),
    );
  }
}

class _PlayCircle extends StatefulWidget {
  const _PlayCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PlayCircle> createState() => _PlayCircleState();
}

class _PlayCircleState extends State<_PlayCircle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.12 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Icon(Icons.play_arrow_rounded, size: 36, color: AppColors.background),
          ),
        ),
      ),
    );
  }
}

class _TitleFallback extends StatelessWidget {
  const _TitleFallback(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bildgrößen in Stufen anfragen, damit der Server-Cache greift.
int _bucket(double px) {
  for (final size in const [240, 360, 480, 640, 800, 1000, 1280]) {
    if (px <= size) return size;
  }
  return 1600;
}

/// Folge als kompakte Zeile (iPhone): kleines Standbild links, Titel, Länge und Inhalt rechts –
/// so passen fünf, sechs Folgen auf den Bildschirm statt einer. Tippen spielt ab, lange drücken
/// öffnet das Menü.
class EpisodeListTile extends ConsumerWidget {
  const EpisodeListTile({super.key, required this.item, this.highlighted = false});

  final BaseItem item;

  /// Die Folge, von deren Seite man kommt ("Diese Folge").
  final bool highlighted;

  static const _imageWidth = 136.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Images.landscape(item);
    final w = _bucket(_imageWidth * dpr);
    final number = item.indexNumber;
    final meta = [if (item.runtime != null) formatRuntime(item.runtime!), if (highlighted) tr.thisEpisode].join(' · ');
    return Focusable(
      onTap: () => playItem(context, item),
      onSecondaryTap: (pos) => showItemContextMenu(context, item, pos),
      semanticLabel: '${number != null ? '$number. ' : ''}${item.name}',
      builder: (context, hovered) => GestureDetector(
        onLongPressStart: (d) => showItemContextMenu(context, item, d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlighted || hovered ? Colors.white.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? AppColors.accent.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: _imageWidth,
                  height: _imageWidth * 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      JfImage(
                        url: api.imageUrlOrNull(image, fillWidth: w, fillHeight: (w * 9 / 16).round()),
                        blurHash: image?.blurHash,
                        fallback: _TitleFallback(item.name),
                      ),
                      Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                      _Badge(item),
                      if (progressOf(item) case final p?) _ProgressBar(p),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${number != null ? '$number. ' : ''}${item.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: 12,
                          color: highlighted ? AppColors.accent : AppColors.textSecondary,
                          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                    if (item.overview case final overview? when overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
