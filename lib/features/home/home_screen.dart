import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/seasons.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/jf_image.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/seasonal_particles.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import 'hero_banner.dart';
import 'home_providers.dart';
import '../../widgets/focusable.dart';
import '../../l10n/strings.dart';
import '../../core/image_cache.dart';

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
    final season = ref.watch(activeSeasonProvider);
    final seasonal = ref.watch(seasonalSectionProvider).value;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.80).clamp(520.0, 920.0);

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
                      HeroBanner(height: heroHeight),
                      // Platz bleibt stabil, auch ohne Saison (Fokus im Banner bleibt erhalten).
                      Positioned.fill(
                        child: season == null ? const SizedBox.shrink() : SeasonalParticles(season: season),
                      ),
                    ],
                  ),
                ),
                ...home.when(
                  data: (data) {
                    // Saison-Reihe direkt nach "Weiterschauen"/"Als Nächstes".
                    final sections = [...data.sections];
                    if (seasonal != null) {
                      final at = sections.where((s) => s.style == SectionStyle.landscape).length;
                      sections.insert(at, seasonal);
                    }
                    return [
                      SliverList.separated(
                        itemCount: sections.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 26),
                        itemBuilder: (context, i) => _SectionRow(section: sections[i]),
                      ),
                      // Empfehlungen, Sammlungen, Genres – erscheinen, sobald geladen.
                      SliverList.list(
                        children: [
                          for (final section in ref.watch(discoverProvider).value ?? const <HomeSection>[])
                            Padding(
                              padding: const EdgeInsets.only(top: 26),
                              child: _SectionRow(section: section),
                            ),
                        ],
                      ),
                      if (data.libraries.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 26),
                            child: _LibrariesRow(libraries: data.libraries),
                          ),
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
          _TopNav(scroll: _scroll),
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

void openLibrary(BuildContext context, BaseItem library) {
  final query = Uri(queryParameters: {'name': library.name, 'type': ?library.collectionType}).query;
  context.push('/library/${library.id}?$query');
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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

/// Schwebende Navigationsleiste. Wird beim Herunterscrollen milchig-undurchsichtig.
class _TopNav extends ConsumerWidget {
  const _TopNav({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraries = ref.watch(libraryViewsProvider).value ?? const <BaseItem>[];
    final session = ref.watch(sessionProvider).value;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: scroll,
        builder: (context, child) {
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final t = (offset / 240).clamp(0.0, 1.0);
          final solid = AppColors.background.withValues(alpha: 0.72);
          final bar = Container(
            padding: const EdgeInsets.only(top: kTitleBarHeight - 4, left: kPageGutter, right: kPageGutter + 4),
            height: kTitleBarHeight + 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(Colors.black.withValues(alpha: 0.55), solid, t)!,
                  Color.lerp(Colors.black.withValues(alpha: 0), solid, t)!,
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06 * t)),
              ),
            ),
            child: child,
          );
          if (t == 0) return bar;
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24 * t, sigmaY: 24 * t),
              child: bar,
            ),
          );
        },
        child: Row(
          children: [
            const BrandLogo(size: 26),
            if (ref.watch(activeSeasonProvider) case final season?)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: season.title,
                  child: Text(seasonInfo[season]!.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            const SizedBox(width: 40),
            _NavLink(label: tr.home, active: true),
            for (final lib in libraries) _NavLink(label: lib.name, onTap: () => openLibrary(context, lib)),
            _NavLink(label: tr.downloads, onTap: () => context.push('/downloads')),
            const Spacer(),
            IconButton(
              tooltip: tr.movieQuiz,
              icon: const Icon(Icons.quiz_outlined, size: 24),
              onPressed: () => context.push('/quiz'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr.surpriseMe,
              icon: const Icon(Icons.casino_outlined, size: 25),
              onPressed: () => context.push('/roulette'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr.searchCtrlF,
              icon: const Icon(Icons.search_rounded, size: 26),
              onPressed: () => context.push('/search'),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: session?.userName ?? tr.profile,
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') ref.read(sessionProvider.notifier).logout();
                if (value == 'settings') context.push('/settings');
                if (value == 'switch') ref.read(sessionProvider.notifier).switchUser();
                if (value == 'wrapped') context.push('/wrapped');
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '${session?.userName ?? ''} · ${session?.serverName ?? ''}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [Icon(Icons.switch_account_outlined, size: 20), SizedBox(width: 12), Text(tr.switchUser)],
                  ),
                ),
                PopupMenuItem(
                  value: 'wrapped',
                  child: Row(
                    children: [Icon(Icons.auto_graph_rounded, size: 20), SizedBox(width: 12), Text(tr.yearlyRecap)],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text(tr.settings)],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [Icon(Icons.logout_rounded, size: 20), SizedBox(width: 12), Text(tr.signOut)]),
                ),
              ],
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Text(
                        (session?.userName.isNotEmpty ?? false) ? session!.userName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    // Profilbild aus Jellyfin, sobald geladen (sonst bleibt der Buchstabe).
                    if (ref.watch(userImageProvider).value case final url?)
                      Image(
                        image: CachedNetworkImage(url),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({required this.label, this.onTap, this.active = false});

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onTap ?? () {},
      scrollAlignment: 0,
      builder: (context, hovered) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 15,
            fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
            color: widget.active || hovered ? AppColors.textPrimary : AppColors.textSecondary,
            decoration: hovered ? TextDecoration.underline : null,
            decorationColor: AppColors.accent,
            decorationThickness: 2,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
