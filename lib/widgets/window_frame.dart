import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';

/// Steuert, ob die Fensterleiste sichtbar ist (der Player blendet sie aus).
final windowChromeVisible = ValueNotifier<bool>(true);

/// Ob das Fenster im Vollbild ist (F11 überall, F/Doppelklick im Player).
final windowFullscreen = ValueNotifier<bool>(false);

Future<void> setWindowFullscreen(bool value) async {
  await windowManager.setFullScreen(value);
  windowFullscreen.value = value;
}

Future<void> toggleWindowFullscreen() => setWindowFullscreen(!windowFullscreen.value);

/// Legt eine schlanke, transparente Titelleiste über jede Seite:
/// links ein Zurück-Pfeil, rechts Minimieren/Maximieren/Schließen.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    // Der Router meldet sich teils mitten im Aufbau – daher immer erst nach dem Frame neu zeichnen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Pfad der obersten Seite (auch bei push), nicht nur die Basis-Adresse.
  /// Beim allerersten Aufbau gibt es noch keine Seite – dann leer.
  String _currentPath() {
    if (widget.router.routerDelegate.currentConfiguration.isEmpty) return '';
    return widget.router.state.uri.path;
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final path = _currentPath();
    final showBack = widget.router.canPop() && !path.startsWith('/play');

    final loggedInArea = path != '/login' && path != '/splash';

    return CallbackShortcuts(
      bindings: {
        // Strg+F öffnet überall (außer im Player) die Suche.
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (loggedInArea && !path.startsWith('/play') && path != '/search') widget.router.push('/search');
        },
        // F11 schaltet überall Vollbild um, Esc verlässt es.
        const SingleActivator(LogicalKeyboardKey.f11): toggleWindowFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (windowFullscreen.value) setWindowFullscreen(false);
        },
        // Alt+← bzw. Maus-"Zurück" wie im Browser.
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (showBack) widget.router.pop();
        },
      },
      // Fängt Tastendrücke auf, wenn sonst nichts fokussiert ist (z. B. auf der Startseite).
      child: Focus(
        autofocus: true,
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == kBackMouseButton && showBack) widget.router.pop();
          },
          child: _buildFrame(showBack),
        ),
      ),
    );
  }

  Widget _buildFrame(bool showBack) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kTitleBarHeight,
          child: ListenableBuilder(
            listenable: Listenable.merge([windowChromeVisible, windowFullscreen]),
            builder: (context, child) {
              // Im Vollbild keine Fensterknöpfe.
              final visible = windowChromeVisible.value && !windowFullscreen.value;
              return AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(ignoring: !visible, child: child),
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: showBack
                        ? _TitleBarButton(
                            key: const ValueKey('back'),
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Zurück',
                            onPressed: () => widget.router.pop(),
                          )
                        : const SizedBox(key: ValueKey('none'), width: 8),
                  ),
                  const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
                  _TitleBarButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Minimieren',
                    onPressed: () => windowManager.minimize(),
                  ),
                  _TitleBarButton(
                    icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                    iconSize: _maximized ? 14 : 16,
                    tooltip: _maximized ? 'Wiederherstellen' : 'Maximieren',
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  _TitleBarButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Schließen',
                    hoverColor: const Color(0xFFE81123),
                    onPressed: () => windowManager.close(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.hoverColor,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? hoverColor;
  final double iconSize;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: kTitleBarHeight,
          color: _hovered ? (widget.hoverColor ?? Colors.white.withValues(alpha: 0.10)) : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
