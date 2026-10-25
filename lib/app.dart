import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/branding.dart';
import 'core/changelog.dart';
import 'core/version.dart';
import 'widgets/whats_new_dialog.dart';
import 'core/download_notify.dart';
import 'core/update_check.dart';
import 'features/settings/about_section.dart';
import 'core/route_observer.dart';
import 'core/session.dart';
import 'core/settings.dart';
import 'features/details/details_screen.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live_handler.dart';
import 'features/library/library_screen.dart';
import 'features/lists/lists_screen.dart';
import 'features/login/login_screen.dart';
import 'features/person/person_screen.dart';
import 'features/player/player_screen.dart';
import 'features/roulette/roulette_screen.dart';
import 'features/lock/idle_lock.dart';
import 'features/screensaver/screensaver.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'features/wrapped/wrapped_screen.dart';
import 'theme.dart';
import 'widgets/window_frame.dart';
import 'l10n/strings.dart';
import 'features/home/home_providers.dart';
import 'widgets/offline_banner.dart';
import 'widgets/layout_shell.dart';

/// Seite mit Material-Übergang (siehe buildTheme). go_router erkennt die App
/// sonst nicht zuverlässig als MaterialApp und blendet Seiten ohne Übergang ein.
GoRoute _route(String path, Widget Function(GoRouterState state) build) => GoRoute(
  path: path,
  pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, name: state.uri.path, child: build(state)),
);

final routerProvider = Provider<GoRouter>((ref) {
  // Bei jeder An-/Abmeldung die Weiterleitungen neu prüfen.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(settingsProvider.select((s) => s.setupDone), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    observers: [appRouteObserver, popupTracker],
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      if (!session.hasValue && !session.hasError) {
        return location == '/splash' ? null : '/splash';
      }
      final loggedIn = session.value != null;
      if (!loggedIn) {
        // Frisch installiert: erst der Einrichtungs-Assistent, dann die Anmeldung.
        if (!ref.read(settingsProvider).setupDone) return location == '/welcome' ? null : '/welcome';
        return location == '/login' ? null : '/login';
      }
      if (location == '/login' || location == '/splash' || location == '/welcome') return '/';
      return null;
    },
    routes: [
      _route('/splash', (_) => const SplashScreen()),
      _route('/welcome', (_) => const WelcomeScreen()),
      _route('/login', (_) => const LoginScreen()),
      _route('/', (_) => const HomeScreen()),
      _route('/search', (_) => const SearchScreen()),
      _route('/downloads', (_) => const DownloadsScreen()),
      _route('/roulette', (_) => const RouletteScreen()),
      _route('/wrapped', (_) => const WrappedScreen()),
      _route('/settings', (_) => const SettingsScreen()),
      _route('/lists', (_) => const ListsScreen()),
      _route('/calendar', (_) => const CalendarScreen()),
      _route(
        '/library/:id',
        (state) => LibraryScreen(
          // Eigener Schlüssel je Bibliothek – sonst blieben beim Wechsel die alten Titel stehen.
          key: ValueKey('library-${state.pathParameters['id']}'),
          libraryId: state.pathParameters['id']!,
          name: state.uri.queryParameters['name'] ?? tr.library,
          collectionType: state.uri.queryParameters['type'],
        ),
      ),
      _route('/item/:id', (state) => DetailsScreen(itemId: state.pathParameters['id']!)),
      _route('/person/:id', (state) => PersonScreen(personId: state.pathParameters['id']!)),
      _route(
        '/play/:id',
        (state) => PlayerScreen(
          itemId: state.pathParameters['id']!,
          startTicks: int.tryParse(state.uri.queryParameters['start'] ?? ''),
          mediaSourceId: state.uri.queryParameters['source'],
          audioIndex: int.tryParse(state.uri.queryParameters['audio'] ?? ''),
          subtitleIndex: int.tryParse(state.uri.queryParameters['sub'] ?? ''),
          autoPlayed: state.uri.queryParameters['auto'] == '1',
          fromQueue: state.uri.queryParameters['queue'] == '1',
          restoreFullscreen: switch (state.uri.queryParameters['rf']) {
            '1' => true,
            '0' => false,
            _ => null,
          },
        ),
      ),
    ],
  );
});

class JellyflexApp extends ConsumerStatefulWidget {
  const JellyflexApp({super.key});

  @override
  ConsumerState<JellyflexApp> createState() => _JellyflexAppState();
}

class _JellyflexAppState extends ConsumerState<JellyflexApp> {
  bool _whatsNewChecked = false;

  /// Neuigkeiten seit der zuletzt gesehenen Version zeigen. Nach einer frischen
  /// Installation nicht (dann gibt es noch keine Einstellungen); Versionen vor 0.3.4
  /// kannten das Fenster nicht – dort gelten die Neuigkeiten ab 0.3.4.
  void _maybeShowWhatsNew() {
    if (_whatsNewChecked) return;
    _whatsNewChecked = true;
    final controller = ref.read(settingsProvider.notifier);
    final last = controller.current.lastSeenVersion;
    if (last == appVersion) return;
    controller.update((s) => s.copyWith(lastSeenVersion: () => appVersion));
    if (last == null && !controller.existedOnStart) return;
    final changes = changesSince(last ?? '0.3.3', appVersion);
    if (changes.isEmpty) return;
    // Erst wenn die Startseite steht.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      final context = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (mounted && context != null && context.mounted) showWhatsNew(context, changes);
    });
  }

  @override
  void initState() {
    super.initState();
    // Freiwillige Update-Prüfung (Standard: aus) – einmal pro Start, etwas verzögert.
    if (ref.read(settingsProvider).updateCheck) {
      Future<void>.delayed(const Duration(seconds: 8), () async {
        final latest = await UpdateCheck.latestRelease();
        if (!mounted || latest == null || !UpdateCheck.isNewer(latest.version)) return;
        final router = ref.read(routerProvider);
        await offerUpdate(
          latest,
          () => router.routerDelegate.navigatorKey.currentContext,
          automatic: ref.read(settingsProvider).autoUpdate,
        );
      });
    }
    // "Was ist neu": einmal nach einem Update – sobald jemand angemeldet ist.
    ref.listenManual(sessionProvider, (_, session) {
      if (session.value != null) _maybeShowWhatsNew();
    }, fireImmediately: true);
    // Eigener Name/Logo: Fenstertitel und Taskleisten-Symbol mitziehen.
    ref.listenManual(
      settingsProvider.select((s) => (s.appName, s.logoPath)),
      (_, _) => applyWindowBranding(ref.read(settingsProvider)),
      fireImmediately: true,
    );
    void rebuildAll() {
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    }

    // Andere Sprache: Reihen mit Überschriften neu laden und alles neu zeichnen.
    ref.listenManual(settingsProvider.select((s) => s.language), (_, _) {
      ref.invalidate(homeProvider);
      ref.invalidate(discoverProvider);
      ref.invalidate(seasonalSectionProvider);
      rebuildAll();
    });
    // Andere Farben oder anderes Layout: nur neu zeichnen – die Daten bleiben.
    ref.listenManual(settingsProvider.select((s) => (s.themeId, s.layoutId)), (_, _) => rebuildAll());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: appDisplayName(ref.watch(settingsProvider)),
      debugShowCheckedModeBanner: false,
      locale: Locale(ref.watch(settingsProvider.select((s) => s.language)).name),
      supportedLocales: [for (final l in AppLanguage.values) Locale(l.name)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(ref.watch(settingsProvider.select((s) => '${s.themeId}/${s.layoutId}'))),
      routerConfig: router,
      scrollBehavior: const _AppScrollBehavior(),
      scaffoldMessengerKey: appMessengerKey,
      builder: (context, child) => Screensaver(
        router: router,
        child: IdleLock(
          router: router,
          child: LiveHandler(
            router: router,
            child: DownloadNotifier(
              messenger: appMessengerKey,
              child: WindowFrame(
                router: router,
                child: LayoutShell(
                  router: router,
                  child: OfflineBanner(router: router, child: child!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keine automatischen Scrollbalken – die App blendet sie gezielt selbst ein.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
