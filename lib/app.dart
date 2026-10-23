import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/branding.dart';
import 'core/route_observer.dart';
import 'core/session.dart';
import 'core/settings.dart';
import 'features/details/details_screen.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live_handler.dart';
import 'features/library/library_screen.dart';
import 'features/login/login_screen.dart';
import 'features/person/person_screen.dart';
import 'features/player/player_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/roulette/roulette_screen.dart';
import 'features/screensaver/screensaver.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash_screen.dart';
import 'features/wrapped/wrapped_screen.dart';
import 'theme.dart';
import 'widgets/window_frame.dart';
import 'l10n/strings.dart';
import 'features/home/home_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bei jeder An-/Abmeldung die Weiterleitungen neu prüfen.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    observers: [appRouteObserver],
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      if (!session.hasValue && !session.hasError) {
        return location == '/splash' ? null : '/splash';
      }
      final loggedIn = session.value != null;
      if (!loggedIn) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      GoRoute(path: '/roulette', builder: (_, _) => const RouletteScreen()),
      GoRoute(path: '/quiz', builder: (_, _) => const QuizScreen()),
      GoRoute(path: '/wrapped', builder: (_, _) => const WrappedScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/library/:id',
        builder: (_, state) => LibraryScreen(
          libraryId: state.pathParameters['id']!,
          name: state.uri.queryParameters['name'] ?? tr.library,
          collectionType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (_, state) => DetailsScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, state) => PersonScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/play/:id',
        builder: (_, state) => PlayerScreen(
          itemId: state.pathParameters['id']!,
          startTicks: int.tryParse(state.uri.queryParameters['start'] ?? ''),
          mediaSourceId: state.uri.queryParameters['source'],
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
  @override
  void initState() {
    super.initState();
    // Eigener Name/Logo: Fenstertitel und Taskleisten-Symbol mitziehen.
    ref.listenManual(
      settingsProvider.select((s) => (s.appName, s.logoPath)),
      (_, _) => applyWindowBranding(ref.read(settingsProvider)),
      fireImmediately: true,
    );
    // Andere Sprache: alles neu zeichnen und Reihen mit Überschriften neu laden.
    ref.listenManual(settingsProvider.select((s) => s.language), (_, _) {
      ref.invalidate(homeProvider);
      ref.invalidate(discoverProvider);
      ref.invalidate(seasonalSectionProvider);
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
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
      theme: buildTheme(),
      routerConfig: router,
      scrollBehavior: const _AppScrollBehavior(),
      scaffoldMessengerKey: appMessengerKey,
      builder: (context, child) => Screensaver(
        router: router,
        child: LiveHandler(
          router: router,
          child: WindowFrame(router: router, child: child!),
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
