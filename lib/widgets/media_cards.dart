import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/images.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/settings.dart';
import '../features/item_actions.dart';
import '../theme.dart';
import 'focusable.dart';
import 'jf_image.dart';

const double kPosterWidth = 168;
const double kLandscapeWidth = 320;
const double kCardTextHeight = 52;

/// Öffnet die Detailseite eines Eintrags.
void openItem(BuildContext context, BaseItem item) => context.push('/item/${item.id}');

/// Startet die Wiedergabe (ggf. an der gespeicherten Stelle).
void playItem(BuildContext context, BaseItem item, {bool fromStart = false}) {
  final ticks = item.userData.playbackPositionTicks;
  final query = !fromStart && ticks > 0 ? '?start=$ticks' : '';
  context.push('/play/${item.id}$query');
}

/// Gemeinsame Hover-Logik: leicht vergrößern, Schatten, Rahmen.
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.builder, required this.onTap, this.onContextMenu});

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
    return Focusable(
      onTap: widget.onTap,
      onSecondaryTap: widget.onContextMenu,
      builder: (context, highlighted) => widget.builder(highlighted),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.hovered, required this.aspectRatio, required this.child});

  final bool hovered;
  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: hovered ? 1.05 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.55 : 0.25),
              blurRadius: hovered ? 28 : 10,
              offset: Offset(0, hovered ? 12 : 4),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.06),
            width: hovered ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: aspectRatio, child: child),
        ),
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
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
                child: Container(decoration: const BoxDecoration(gradient: AppColors.accentGradient)),
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
  const PosterCard({super.key, required this.item, this.width = kPosterWidth});

  final BaseItem item;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final poster = Images.poster(item);
    final h = _bucket(width * 1.5 * dpr);
    return SizedBox(
      width: width,
      child: _HoverCard(
        onTap: () => openItem(context, item),
        onContextMenu: (pos) => showItemContextMenu(context, item, pos),
        builder: (hovered) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardFrame(
              hovered: hovered,
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JfImage(
                    url: api.imageUrlOrNull(poster, fillWidth: (h * 2 / 3).round(), fillHeight: h),
                    blurHash: poster?.blurHash,
                    fallback: _TitleFallback(item.name),
                  ),
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
    this.width = kLandscapeWidth,
    this.onTap,
    this.title,
    this.subtitle,
  });

  final BaseItem item;
  final double width;
  final VoidCallback? onTap;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Images.landscape(item, episodeImages: ref.watch(settingsProvider).episodeImagesInRows);
    final w = _bucket(width * dpr);
    return SizedBox(
      width: width,
      child: _HoverCard(
        onTap: onTap ?? () => openItem(context, item),
        onContextMenu: (pos) => showItemContextMenu(context, item, pos),
        builder: (hovered) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardFrame(
              hovered: hovered,
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JfImage(
                    url: api.imageUrlOrNull(image, fillWidth: w, fillHeight: (w * 9 / 16).round()),
                    blurHash: image?.blurHash,
                    fallback: _TitleFallback(cardTitle(item)),
                  ),
                  AnimatedOpacity(
                    opacity: hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: _PlayCircle(onTap: () => playItem(context, item)),
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
            child: const Icon(Icons.play_arrow_rounded, size: 36, color: AppColors.background),
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
      decoration: const BoxDecoration(
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
        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
