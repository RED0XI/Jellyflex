import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import 'home_providers.dart';

/// Großes Banner oben auf der Startseite. Wechselt alle paar Sekunden
/// mit Überblendung und langsamem Zoom ("Ken-Burns-Effekt").
class HeroBanner extends ConsumerStatefulWidget {
  const HeroBanner({super.key, required this.height});

  final double height;

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> {
  static const _interval = Duration(seconds: 9);

  int _index = 0;
  bool _hovered = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!_hovered && mounted) setState(() => _index++);
    });
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(featuredProvider).value ?? const <BaseItem>[];
    final api = ref.watch(apiProvider);
    final width = MediaQuery.sizeOf(context).width;

    if (items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const DecoratedBox(
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

    return MouseRegion(
      onEnter: (_) => _hovered = true,
      onExit: (_) => _hovered = false,
      child: SizedBox(
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
            // Abdunkeln links (für den Text) und unten (Übergang zu den Reihen).
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0, 0.35, 0.75],
                    colors: [Color(0xF00A0B10), Color(0x990A0B10), Color(0x000A0B10)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0, 0.35, 1],
                    colors: [AppColors.background, Color(0x000A0B10), Color(0x550A0B10)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: kPageGutter,
              bottom: 84,
              width: math.min(600, width * 0.46),
              child: AnimatedSwitcher(
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
            Positioned(
              left: kPageGutter,
              bottom: 40,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    GestureDetector(
                      onTap: () => _goTo(i),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 8),
                          width: i == current ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == current ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
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
      if (item.isSeries && item.childCount != null)
        '${item.childCount} ${item.childCount == 1 ? 'Staffel' : 'Staffeln'}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TitleLogo(logoUrl: logo, title: item.name, maxHeight: 130, fontSize: 52),
        const SizedBox(height: 18),
        DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, shadows: shadow),
          child: Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.communityRating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC94D), size: 20),
                    const SizedBox(width: 4),
                    Text(item.communityRating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              for (final m in meta) Text(m),
              if (item.officialRating != null) RatingBadge(item.officialRating!),
            ],
          ),
        ),
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.genres.take(3).join('  ·  '),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, shadows: shadow),
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
                label: item.userData.hasResumePosition ? 'Fortsetzen' : 'Abspielen',
                icon: Icons.play_arrow_rounded,
                onPressed: () => playItem(context, item),
              )
            else
              PrimaryButton(label: 'Ansehen', icon: Icons.play_arrow_rounded, onPressed: () => openItem(context, item)),
            const SizedBox(width: 12),
            GlassButton(
              label: 'Mehr Infos',
              icon: Icons.info_outline_rounded,
              onPressed: () => openItem(context, item),
            ),
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
      child: Image.network(
        logoUrl!,
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
