import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/image_cache.dart';
import '../../core/layouts.dart';
import '../../core/models.dart';
import '../../core/seasons.dart';
import '../../core/session.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/focusable.dart';
import 'home_providers.dart';

/// Ein Ziel der Navigation (Startseite, Bibliothek, Downloads …).
class NavEntry {
  const NavEntry({required this.icon, required this.label, required this.path, required this.onTap});

  final IconData icon;
  final String label;

  /// Adresse, an der das Ziel "aktiv" ist.
  final String path;
  final VoidCallback onTap;
}

void openLibrary(BuildContext context, BaseItem library) => _openLibrary(GoRouter.of(context), library);

/// Router erst beim Klick holen: In der Seite liefert ihn der Kontext, die
/// Seitenleiste (außerhalb des Navigators) bekommt ihn direkt.
typedef RouterGetter = GoRouter Function();

void _openLibrary(GoRouter router, BaseItem library, {bool replace = false}) {
  final query = Uri(queryParameters: {'name': library.name, 'type': ?library.collectionType}).query;
  final location = '/library/${library.id}?$query';
  replace ? router.go(location) : router.push(location);
}

/// Hauptziele: Startseite, alle Bibliotheken, Downloads. [replace]: Ziele
/// ersetzen die Seite (Seitenleiste), statt sich zu stapeln.
List<NavEntry> navEntries(RouterGetter router, WidgetRef ref, {bool replace = false}) {
  final libraries = ref.watch(libraryViewsProvider).value ?? const <BaseItem>[];
  void open(String location) => replace ? router().go(location) : router().push(location);
  return [
    NavEntry(icon: Icons.home_rounded, label: tr.home, path: '/', onTap: () => router().go('/')),
    for (final lib in libraries)
      NavEntry(
        icon: switch (lib.collectionType) {
          'tvshows' => Icons.tv_rounded,
          'music' => Icons.music_note_rounded,
          'boxsets' => Icons.collections_bookmark_rounded,
          _ => Icons.movie_rounded,
        },
        label: lib.name,
        path: '/library/${lib.id}',
        onTap: () => _openLibrary(router(), lib, replace: replace),
      ),
    NavEntry(icon: Icons.download_rounded, label: tr.downloads, path: '/downloads', onTap: () => open('/downloads')),
  ];
}

/// Profilbild mit Menü (Benutzer wechseln, Jahresrückblick, Einstellungen, Abmelden).
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key, this.router, this.size = 38, this.extraActions = false});

  /// Nur außerhalb des Navigators nötig (Seitenleiste); sonst aus dem Kontext.
  final GoRouter? router;
  final double size;

  /// "Überrasch mich" mit ins Menü (für schlanke Leisten).
  final bool extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    Future<void> open() async {
      // Das Menü gehört auf den Seiten-Navigator – die Seitenleiste liegt außerhalb davon.
      final router = this.router ?? GoRouter.of(context);
      final overlayState = router.routerDelegate.navigatorKey.currentState?.overlay;
      final box = context.findRenderObject() as RenderBox?;
      if (overlayState == null || box == null) return;
      final navContext = overlayState.context;
      final overlay = navContext.findRenderObject()! as RenderBox;
      final topLeft = overlay.globalToLocal(box.localToGlobal(Offset(0, box.size.height + 8)));
      final value = await showMenu<String>(
        context: navContext,
        position: RelativeRect.fromRect(topLeft & const Size(1, 1), Offset.zero & overlay.size),
        items: _items(session),
      );
      switch (value) {
        case null:
          return;
        case 'logout':
          await ref.read(sessionProvider.notifier).logout();
        case 'switch':
          await ref.read(sessionProvider.notifier).switchUser();
        default:
          router.push(value);
      }
    }

    final button = Focusable(
      onTap: open,
      semanticLabel: session?.userName ?? tr.profile,
      builder: (context, hovered) => AnimatedScale(
        scale: hovered ? 1.08 : 1,
        duration: const Duration(milliseconds: 150),
        child: Avatar(size: size),
      ),
    );
    // Tooltips brauchen ein Overlay – das gibt es nur innerhalb des Navigators.
    return router == null ? Tooltip(message: session?.userName ?? tr.profile, child: button) : button;
  }

  List<PopupMenuEntry<String>> _items(AuthSession? session) {
    PopupMenuItem<String> entry(String value, IconData icon, String label) => PopupMenuItem(
      value: value,
      child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)]),
    );
    return [
      PopupMenuItem(
        enabled: false,
        child: Text(
          '${session?.userName ?? ''} · ${session?.serverName ?? ''}',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      const PopupMenuDivider(),
      if (extraActions) ...[
        entry('/roulette', Icons.casino_outlined, tr.surpriseMe),
      ],
      entry('/lists', Icons.bookmarks_outlined, tr.myLists),
      entry('switch', Icons.switch_account_outlined, tr.switchUser),
      entry('/wrapped', Icons.auto_graph_rounded, tr.yearlyRecap),
      entry('/settings', Icons.settings_outlined, tr.settings),
      entry('logout', Icons.logout_rounded, tr.signOut),
    ];
  }
}

/// Rundes Profilbild (oder Anfangsbuchstabe).
class Avatar extends ConsumerWidget {
  const Avatar({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              (session?.userName.isNotEmpty ?? false) ? session!.userName[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.42),
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
    );
  }
}

/// Schwebende Leiste über der Startseite. Wird beim Herunterscrollen milchig-undurchsichtig.
/// [minimal]: nur Name, Ziele und Suche – "Überrasch mich" wandert ins Profilmenü.
class TopNav extends ConsumerWidget {
  const TopNav({super.key, required this.scroll, this.minimal = false});

  final ScrollController scroll;
  final bool minimal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = navEntries(() => GoRouter.of(context), ref);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: _FrostedBar(
        scroll: scroll,
        height: kTitleBarHeight + 60,
        child: Row(
          children: [
            BrandLogo(size: minimal ? 20 : 26),
            if (!minimal)
              if (ref.watch(activeSeasonProvider) case final season?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: season.title,
                    child: Text(seasonInfo[season]!.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            SizedBox(width: minimal ? 28 : 40),
            for (final (i, e) in entries.indexed)
              _NavLink(label: e.label, active: i == 0, minimal: minimal, onTap: e.onTap),
            const Spacer(),
            if (!minimal) ...[
              IconButton(
                tooltip: tr.surpriseMe,
                icon: const Icon(Icons.casino_outlined, size: 25),
                onPressed: () => context.push('/roulette'),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: tr.searchCtrlF,
              icon: Icon(Icons.search_rounded, size: minimal ? 22 : 26),
              onPressed: () => context.push('/search'),
            ),
            const SizedBox(width: 10),
            ProfileMenuButton(size: minimal ? 32 : 38, extraActions: minimal),
          ],
        ),
      ),
    );
  }
}

/// Große Reiter in der Mitte – gut lesbar vom Sofa, mit Controller leicht zu treffen.
class TabsNav extends ConsumerWidget {
  const TabsNav({super.key, required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = navEntries(() => GoRouter.of(context), ref);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: _FrostedBar(
        scroll: scroll,
        height: kTitleBarHeight + 76,
        child: Row(
          children: [
            const BrandLogo(size: 24),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, e) in entries.indexed)
                        _TabPill(icon: e.icon, label: e.label, active: i == 0, onTap: e.onTap),
                      _TabPill(
                        icon: Icons.search_rounded,
                        label: tr.search,
                        active: false,
                        onTap: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const ProfileMenuButton(size: 44, extraActions: true),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Focusable(
        onTap: onTap,
        scrollAlignment: 0,
        semanticLabel: label,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: active
                ? AppColors.textPrimary
                : hovered
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: hovered && !active ? AppColors.accent : Colors.transparent, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: active ? AppColors.background : AppColors.textPrimary),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.background : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feste Seitenleiste (Layout "Bibliothek") – bleibt auf allen Übersichtsseiten stehen.
class SideNav extends ConsumerWidget {
  const SideNav({super.key, required this.router, required this.path});

  static const width = 236.0;

  /// Die Leiste liegt außerhalb des Seiten-Navigators – Router daher direkt.
  final GoRouter router;

  /// Aktuelle Adresse (für den markierten Eintrag).
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = navEntries(() => router, ref, replace: true);
    final session = ref.watch(sessionProvider).value;
    bool isActive(NavEntry e) => e.path == '/' ? path == '/' : path.startsWith(e.path);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, kTitleBarHeight + 10, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(10, 0, 10, 22), child: BrandLogo(size: 22)),
          _SideLink(
            icon: Icons.search_rounded,
            label: tr.search,
            active: path == '/search',
            onTap: () => router.go('/search'),
          ),
          const SizedBox(height: 14),
          _SideHeading(tr.libraries),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final e in entries) _SideLink(icon: e.icon, label: e.label, active: isActive(e), onTap: e.onTap),
                const SizedBox(height: 14),
                _SideLink(
                  icon: Icons.bookmarks_outlined,
                  label: tr.myLists,
                  active: path == '/lists',
                  onTap: () => router.go('/lists'),
                ),
                const SizedBox(height: 14),
                _SideHeading(tr.more),
                _SideLink(
                  icon: Icons.casino_outlined,
                  label: tr.surpriseMe,
                  active: false,
                  onTap: () => router.push('/roulette'),
                ),
                _SideLink(
                  icon: Icons.auto_graph_rounded,
                  label: tr.yearlyRecap,
                  active: false,
                  onTap: () => router.push('/wrapped'),
                ),
                _SideLink(
                  icon: Icons.settings_outlined,
                  label: tr.settings,
                  active: path == '/settings',
                  onTap: () => router.go('/settings'),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              ProfileMenuButton(router: router, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session?.userName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideHeading extends StatelessWidget {
  const _SideHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: AppColors.textMuted),
    ),
  );
}

class _SideLink extends StatelessWidget {
  const _SideLink({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(appLayout.radius),
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : hovered
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border.all(color: hovered ? AppColors.accent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: active ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active || hovered ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leiste mit Verlauf; beim Scrollen milchig (Unschärfe).
class _FrostedBar extends StatelessWidget {
  const _FrostedBar({required this.scroll, required this.height, required this.child});

  final ScrollController scroll;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final t = (offset / 240).clamp(0.0, 1.0);
        final solid = AppColors.background.withValues(alpha: 0.72);
        final bar = Container(
          padding: const EdgeInsets.only(top: kTitleBarHeight - 4, left: kPageGutter, right: kPageGutter + 4),
          height: height,
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
      child: child,
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap, this.active = false, this.minimal = false});

  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      scrollAlignment: 0,
      builder: (context, hovered) => Padding(
        padding: EdgeInsets.symmetric(horizontal: minimal ? 11 : 14, vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontFamily: appLayout.bodyFont,
            fontSize: minimal ? 13.5 : 15,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: minimal ? 0.6 : null,
            color: active || hovered ? AppColors.textPrimary : AppColors.textSecondary,
            decoration: hovered ? TextDecoration.underline : null,
            decorationColor: AppColors.accent,
            decorationThickness: 2,
          ),
          child: Text(minimal ? label.toUpperCase() : label),
        ),
      ),
    );
  }
}
