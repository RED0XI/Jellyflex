import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/layouts.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import 'hero_banner.dart';
import 'home_providers.dart';

/// Kopf ohne Banner (Layouts "Bibliothek" und "Minimal"): Begrüßung nach Tageszeit.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key, required this.top});

  /// Platz oben (Titelleiste bzw. Navigation).
  final double top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).value?.userName ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 5 || hour >= 18
        ? tr.goodEvening
        : hour < 12
        ? tr.goodMorning
        : tr.goodAfternoon;
    final minimal = appLayout.nav == NavStyle.minimal;
    return Padding(
      padding: EdgeInsets.fromLTRB(kPageGutter, top, kPageGutter, minimal ? 36 : 22),
      child: Text(
        name.isEmpty ? greeting : '$greeting, $name',
        style: TextStyle(
          fontFamily: appLayout.headingFont ?? appLayout.bodyFont,
          fontSize: minimal ? 40 : 30,
          fontWeight: minimal ? FontWeight.w300 : FontWeight.w700,
          letterSpacing: minimal ? -0.5 : -0.3,
        ),
      ),
    );
  }
}

/// Titelgeschichte wie in einer Zeitschrift (Layout "Magazin"):
/// links Überschrift und Text, rechts das Bild. Wechselt alle 12 s.
class MagazineHero extends ConsumerStatefulWidget {
  const MagazineHero({super.key, required this.height});

  final double height;

  @override
  ConsumerState<MagazineHero> createState() => _MagazineHeroState();
}

class _MagazineHeroState extends ConsumerState<MagazineHero> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      final count = ref.read(featuredProvider).value?.length ?? 0;
      if (count > 1 && mounted) setState(() => _index = (_index + 1) % count);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(featuredProvider).value ?? const <BaseItem>[];
    if (items.isEmpty) return SizedBox(height: widget.height);
    final item = items[_index % items.length];
    final api = ref.watch(apiProvider);
    final image = Images.landscape(item);
    final serif = appLayout.headingFont;
    final meta = [
      ?yearLabel(item),
      if (item.isMovie && item.runtime != null) formatRuntime(item.runtime!),
      if (item.isSeries && item.childCount != null) tr.seasonsCount(item.childCount!),
      ...item.genres.take(2),
    ].join('  ·  ');

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 92, kPageGutter, 28),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Row(
            key: ValueKey(item.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Kleine Fenster: kleinere Überschrift, weniger Text.
                    final compact = box.maxHeight < 480;
                    // Passt der Inhalt trotzdem nicht, wird er verkleinert statt abgeschnitten.
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: box.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr.coverStory.toUpperCase(),
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12.5,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(width: 56, height: 3, color: AppColors.accent),
                            const SizedBox(height: 22),
                            Text(
                              item.name,
                              maxLines: compact ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: serif,
                                fontSize: compact ? 38 : 54,
                                height: 1.05,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              meta,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.overview != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                item.overview!,
                                maxLines: compact ? 2 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: serif,
                                  fontSize: 17,
                                  height: 1.55,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            SizedBox(height: compact ? 16 : 28),
                            Row(
                              children: [
                                if (item.isMovie)
                                  PrimaryButton(
                                    label: item.userData.hasResumePosition ? tr.resume : tr.play,
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () => playItem(context, item),
                                  )
                                else
                                  PrimaryButton(
                                    label: tr.watch,
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () => openItem(context, item),
                                  ),
                                const SizedBox(width: 12),
                                GlassButton(
                                  label: tr.moreInfo,
                                  icon: Icons.info_outline_rounded,
                                  onPressed: () => openItem(context, item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(appLayout.radius),
                        child: JfImage(
                          url: api.imageUrlOrNull(image, maxWidth: screenImageWidth(context) ~/ 2 * 2),
                          blurHash: image?.blurHash,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Container(
                            width: i == _index % items.length ? 26 : 10,
                            height: 3,
                            margin: const EdgeInsets.only(right: 6),
                            color: i == _index % items.length ? AppColors.textPrimary : AppColors.border,
                          ),
                        const Spacer(),
                        if (item.officialRating != null) RatingBadge(item.officialRating!),
                      ],
                    ),
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
