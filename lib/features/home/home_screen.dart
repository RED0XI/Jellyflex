import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_shell.dart';
import '../../core/home_rows.dart';
import '../../core/images.dart';
import '../../core/lists.dart';
import '../../core/settings.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/seasonal_particles.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import 'hero_banner.dart';
import 'home_headers.dart';
import 'home_nav.dart';
import '../../core/layouts.dart';
import 'home_providers.dart';
import '../../widgets/focusable.dart';
import '../../l10n/strings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    // Startseite (neu) geladen: "Weiterschauen" auch in die Sprungliste der Taskleiste.
    ref.listen(homeProvider, (_, next) {
      final session = ref.read(sessionProvider).value;
      if (session == null || !next.hasValue || next.isLoading) return;
      final container = ProviderScope.containerOf(context, listen: false);
      AppShell.updateJumpList(
        ref.read(apiProvider),
        protectedProfile: session.hasPin,
        stillCurrent: () => container.read(sessionProvider).value?.accountKey == session.accountKey,
      );
    });
    final season = ref.watch(activeSeasonProvider);
    final seasonal = ref.watch(seasonalSectionProvider).value;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final layout = appLayout;
    // Mindesthöhe: Titel und Knöpfe dürfen nie unter die Navigation rutschen.
    final minHero = layout.nav == NavStyle.tabs ? 580.0 : 520.0;
    final heroHeight = (screenHeight * layout.heroHeight).clamp(minHero, 920.0);
    // Kopf je nach Layout: großes Banner, Titelgeschichte oder nur eine Begrüßung.
    final Widget header = switch (layout.hero) {
      HeroStyle.banner => HeroBanner(height: heroHeight),
      HeroStyle.split => MagazineHero(height: heroHeight),
      HeroStyle.none => GreetingHeader(
        top: layout.nav == NavStyle.sidebar ? kTitleBarHeight + 28 : kTitleBarHeight + 96,
      ),
    };

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
                  child: Stack(
                    children: [
                      header,
                      // Platz bleibt stabil, auch ohne Saison (Fokus im Banner bleibt erhalten).
                      Positioned.fill(
                        child: season == null ? const SizedBox.shrink() : SeasonalParticles(season: season),
                      ),
                    ],
                  ),
                ),
                ...home.when(
                  data: (data) {
                    // Reihen in der eingestellten Reihenfolge; Empfehlungen, Sammlungen
                    // und Genres erscheinen, sobald sie geladen sind.
                    final all = [
                      ...data.sections,
                      ?seasonal,
                      ...ref.watch(discoverProvider).value ?? const <HomeSection>[],
                    ];
                    final rows = <Widget>[
                      for (final row in HomeRows.parse(ref.watch(settingsProvider.select((s) => s.homeRows))))
                        if (row.visible)
                          ...switch (row.id) {
                            'libraries' => [if (data.libraries.isNotEmpty) _LibrariesRow(libraries: data.libraries)],
                            'watchlist' => [
                              if (ref.watch(watchlistProvider).value case final items? when items.isNotEmpty)
                                _SectionRow(
                                  section: HomeSection(tr.watchlist, items, SectionStyle.poster, group: 'watchlist'),
                                ),
                            ],
                            final id => [
                              for (final section in all.where((s) => s.group == id)) _SectionRow(section: section),
                            ],
                          },
                    ];
                    return [
                      SliverList.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => SizedBox(height: appLayout.rowGap),
                        itemBuilder: (context, i) => rows[i],
                      ),
                    ];
                  },
                  loading: () => [const SliverToBoxAdapter(child: RowsSkeleton())],
                  error: (e, _) => [
                    SliverToBoxAdapter(
                      child: ErrorView(
                        message: tr.homeCouldNotLoad(e),
                        onRetry: () => ref.invalidate(homeProvider),
                        // Ohne Verbindung: heruntergeladene Titel gehen trotzdem.
                        secondaryLabel: tr.viewDownloads,
                        onSecondary: () => context.push('/downloads'),
                      ),
                    ),
                  ],
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 72)),
              ],
            ),
          ),
          switch (layout.nav) {
            NavStyle.top => TopNav(scroll: _scroll),
            NavStyle.minimal => TopNav(scroll: _scroll, minimal: true),
            NavStyle.tabs => TabsNav(scroll: _scroll),
            // Die Seitenleiste steht neben allen Seiten (siehe LayoutShell).
            NavStyle.sidebar => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final landscape = section.style == SectionStyle.landscape;
    return MediaRow(
      title: section.title,
      itemCount: section.items.length,
      height: landscape ? kLandscapeWidth * 9 / 16 + kCardTextHeight : kPosterWidth * 1.5 + kCardTextHeight,
      itemBuilder: (context, i) {
        final item = section.items[i];
        return landscape ? LandscapeCard(item: item) : PosterCard(item: item);
      },
    );
  }
}

class _LibrariesRow extends ConsumerWidget {
  const _LibrariesRow({required this.libraries});

  final List<BaseItem> libraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaRow(
      title: tr.libraries,
      itemCount: libraries.length,
      height: 160,
      itemBuilder: (context, i) => _LibraryTile(library: libraries[i]),
    );
  }
}

class _LibraryTile extends ConsumerStatefulWidget {
  const _LibraryTile({required this.library});

  final BaseItem library;

  @override
  ConsumerState<_LibraryTile> createState() => _LibraryTileState();
}

class _LibraryTileState extends ConsumerState<_LibraryTile> {
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final lib = widget.library;
    final image = Images.landscape(lib);
    return Focusable(
      onTap: () => openLibrary(context, lib),
      builder: (context, hovered) => AnimatedScale(
        scale: hovered ? 1.05 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 284,
          height: 160,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(appLayout.radius + 2)),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(appLayout.radius + 2),
            border: Border.all(
              color: hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.06),
              width: hovered ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              JfImage(url: api.imageUrlOrNull(image, fillWidth: 640, fillHeight: 360), blurHash: image?.blurHash),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD000000), Color(0x00000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Icon(lib.collectionType == 'tvshows' ? Icons.tv_rounded : Icons.movie_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(lib.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
