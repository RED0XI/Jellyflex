import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_lock.dart';
import '../core/layouts.dart';
import '../core/platform/device.dart';
import '../core/route_observer.dart';
import '../core/settings.dart';
import '../features/home/home_nav.dart';
import 'focus_navigation.dart';
import 'mobile_tab_bar.dart';
import 'window_frame.dart';

/// Rahmen um alle Seiten, der vom Layout abhängt:
/// - "Bibliothek": feste Seitenleiste links neben allen Übersichtsseiten
/// - "Retro VHS": Bildzeilen und Vignette über der Oberfläche
/// - iPhone: Tab-Leiste unten statt Seitenleiste
///
/// Der Seiten-Navigator ([child]) bleibt dabei immer an derselben Stelle im
/// Baum – ein Layout-Wechsel verliert also nie den Seitenverlauf.
class LayoutShell extends ConsumerStatefulWidget {
  const LayoutShell({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<LayoutShell> createState() => _LayoutShellState();
}

class _LayoutShellState extends ConsumerState<LayoutShell> {
  /// Seiten, neben denen die Seitenleiste steht (nicht Player, Glücksrad, Anmeldung …).
  static bool _isBrowsePage(String path) =>
      path == '/' ||
      const [
        '/library/',
        '/item/',
        '/person/',
        '/downloads',
        '/search',
        '/settings',
        '/lists',
        '/calendar',
        '/genre/',
      ].any(path.startsWith);

  /// Fokusbereich der Seitenleiste (für Pfeiltasten/Controller).
  final _sideScope = FocusScopeNode(debugLabel: 'Seitenleiste');
  bool _sidebarShown = false;

  /// Zuletzt gewählter Tab (iPhone) – bleibt auf Unterseiten hervorgehoben.
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onChange);
    windowChromeVisible.addListener(_onChange);
    // Fernseher: Leiste klappt mit Fokus auf.
    _sideScope.addListener(_onSideFocus);
    focusEdgeHandler = _onFocusEdge;
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onChange);
    windowChromeVisible.removeListener(_onChange);
    if (focusEdgeHandler == _onFocusEdge) focusEdgeHandler = null;
    _sideScope.removeListener(_onSideFocus);
    _sideScope.dispose();
    super.dispose();
  }

  bool _railExpanded = false;

  void _onSideFocus() {
    if (_sideScope.hasFocus != _railExpanded && mounted) setState(() => _railExpanded = _sideScope.hasFocus);
  }

  /// Pfeiltaste am Rand: von der Seite nach links in die Leiste, aus der Leiste
  /// nach rechts zurück auf die Seite. Nie aus offenen Dialogen/Menüs heraus.
  bool _onFocusEdge(TraversalDirection direction) {
    // Gesperrt: der Fokus darf nicht hinter den Sperrbildschirm wandern.
    if (appLocked.value || !_sidebarShown || popupTracker.open.value > 0) return false;
    final inSidebar = _sideScope.hasFocus;
    if (direction == TraversalDirection.left && !inSidebar) {
      _sideScope.requestFocus();
      return moveFocusInDirection(TraversalDirection.down);
    }
    if (direction == TraversalDirection.right && inSidebar) {
      final page = widget.router.routerDelegate.navigatorKey.currentState?.focusNode;
      if (page == null) return false;
      page.requestFocus();
      return moveFocusInDirection(TraversalDirection.right);
    }
    return false;
  }

  /// Der Router meldet sich teils mitten im Aufbau – erst nach dem Frame neu zeichnen.
  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final layout = layoutById(ref.watch(settingsProvider.select((s) => s.layoutId)));
    final router = widget.router;
    final path = router.routerDelegate.currentConfiguration.isEmpty ? '' : router.state.uri.path;
    final media = MediaQuery.of(context);
    final phone = isPhone(context);
    final browse = _isBrowsePage(path) && windowChromeVisible.value;
    // Fernseher: immer die schmale Symbolleiste (TvNavRail) statt Leiste oben oder Seitenleiste.
    final tvRail = isTv && browse;
    final sidebar = !phone && !isTv && layout.nav == NavStyle.sidebar && browse;
    // Während getippt wird (Tastatur offen), macht die Leiste der Tastatur Platz.
    final tabBar = phone && browse && media.viewInsets.bottom == 0;
    _lastTab = MobileTabBar.indexFor(path) ?? _lastTab;
    _sidebarShown = sidebar || tvRail;
    final scanlines = layout.retro && !path.startsWith('/play');
    final width = sidebar
        ? SideNav.width
        : tvRail
        ? TvNavRail.collapsedWidth
        : 0.0;
    final barHeight = tabBar ? MobileTabBar.height + media.padding.bottom : 0.0;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: width,
                    // Außerhalb des Navigators gibt es kein Material (Textstil, Tintenflecken).
                    child: sidebar
                        ? ValueListenableBuilder<int>(
                            valueListenable: popupTracker.open,
                            // Solange ein Dialog/Menü offen ist, ist die Leiste gesperrt und abgedunkelt
                            // (wie der Rest der Seite hinter dem Dialog).
                            builder: (context, popups, child) => IgnorePointer(
                              ignoring: popups > 0,
                              child: ExcludeFocus(
                                excluding: popups > 0,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    child!,
                                    if (popups > 0) const ColoredBox(color: Color(0x8A000000)),
                                  ],
                                ),
                              ),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: FocusScope(
                                node: _sideScope,
                                child: SideNav(router: router, path: path),
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: MediaQuery(
                      data: media.copyWith(
                        size: Size(media.size.width - width, media.size.height - barHeight),
                        // Die Tab-Leiste hält den Abstand zur Home-Leiste schon selbst.
                        padding: tabBar ? media.padding.copyWith(bottom: 0) : null,
                        viewPadding: tabBar ? media.viewPadding.copyWith(bottom: 0) : null,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
            if (tabBar) MobileTabBar(router: router, active: _lastTab),
          ],
        ),
        // Fernseher: die Leiste liegt über der Seite (aufgeklappt deckt sie sie teilweise ab).
        if (tvRail)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ValueListenableBuilder<int>(
              valueListenable: popupTracker.open,
              builder: (context, popups, child) => ExcludeFocus(excluding: popups > 0, child: child!),
              child: Material(
                type: MaterialType.transparency,
                child: FocusScope(
                  node: _sideScope,
                  child: TvNavRail(router: router, path: path, expanded: _railExpanded),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: scanlines ? const RepaintBoundary(child: CustomPaint(painter: _Scanlines())) : null,
          ),
        ),
      ],
    );
  }
}

/// Bildzeilen wie auf einem Röhrenfernseher, dazu dunklere Ränder.
class _Scanlines extends CustomPainter {
  const _Scanlines();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0x1F000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x73000000)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Scanlines oldDelegate) => false;
}
