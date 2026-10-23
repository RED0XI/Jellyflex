import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/gamepad_input.dart';
import '../theme.dart';
import 'focus_navigation.dart';
import 'focusable.dart';
import 'shortcut_sheet.dart';
import '../l10n/strings.dart';

/// Steuert, ob die Fensterleiste sichtbar ist (der Player blendet sie aus).
final windowChromeVisible = ValueNotifier<bool>(true);

/// Ob das Fenster im Vollbild ist (F11 überall, F/Doppelklick im Player).
final windowFullscreen = ValueNotifier<bool>(false);

Future<void> setWindowFullscreen(bool value) async {
  await windowManager.setFullScreen(value);
  windowFullscreen.value = value;
}

Future<void> toggleWindowFullscreen() => setWindowFullscreen(!windowFullscreen.value);

/// Mini-Player: kleines Fenster unten rechts, immer im Vordergrund.
final windowMiniPlayer = ValueNotifier<bool>(false);
Rect? _boundsBeforeMini;
bool _maximizedBeforeMini = false;

Future<void> setWindowMiniPlayer(bool value) async {
  if (value == windowMiniPlayer.value) return;
  if (value) {
    if (windowFullscreen.value) await setWindowFullscreen(false);
    _maximizedBeforeMini = await windowManager.isMaximized();
    if (_maximizedBeforeMini) await windowManager.unmaximize();
    _boundsBeforeMini = await windowManager.getBounds();
    final area = await _workAreaAround(_boundsBeforeMini!.center);
    // Erst auf die kleine Bedienung umschalten, dann verkleinern (sonst ist die
    // große Steuerleiste kurz zu breit für das Fenster).
    windowMiniPlayer.value = true;
    await WidgetsBinding.instance.endOfFrame;
    const size = Size(480, 270);
    await windowManager.setMinimumSize(const Size(320, 180));
    await windowManager.setAspectRatio(16 / 9);
    await windowManager.setBounds(
      Rect.fromLTWH(area.right - size.width - 24, area.bottom - size.height - 24, size.width, size.height),
    );
    await windowManager.setAlwaysOnTop(true);
  } else {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAspectRatio(0);
    await windowManager.setMinimumSize(const Size(1024, 640));
    final bounds = _boundsBeforeMini;
    if (bounds != null) await windowManager.setBounds(bounds);
    if (_maximizedBeforeMini) await windowManager.maximize();
    // Erst wieder groß, dann die normale Bedienung zeigen.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    windowMiniPlayer.value = false;
  }
}

/// Nutzbarer Bereich (ohne Taskleiste) des Bildschirms, auf dem [point] liegt.
Future<Rect> _workAreaAround(Offset point) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    for (final d in displays) {
      final pos = d.visiblePosition ?? Offset.zero;
      final area = pos & (d.visibleSize ?? d.size);
      if (area.contains(point)) return area;
    }
    final primary = await screenRetriever.getPrimaryDisplay();
    return (primary.visiblePosition ?? Offset.zero) & (primary.visibleSize ?? primary.size);
  } catch (_) {
    return const Rect.fromLTWH(0, 0, 1920, 1032);
  }
}

/// Legt eine schlanke, transparente Titelleiste über jede Seite:
/// links ein Zurück-Pfeil, rechts Minimieren/Maximieren/Schließen.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

final _arrowDirections = {
  LogicalKeyboardKey.arrowUp: TraversalDirection.up,
  LogicalKeyboardKey.arrowDown: TraversalDirection.down,
  LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
  LogicalKeyboardKey.arrowRight: TraversalDirection.right,
};

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  final _frameFocus = FocusNode(debugLabel: 'WindowFrame');
  bool _sheetOpen = false;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    GamepadInput.start(_onPadAction);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    GamepadInput.stop();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _frameFocus.dispose();
    super.dispose();
  }

  /// Liegt der Fokus auf keinem Element (ganz oben im Fenster), erreichen Tasten
  /// die Seite nicht – Pfeiltasten hier direkt in Fokus-Navigation umsetzen.
  bool _onHardwareKey(KeyEvent event) {
    final primary = FocusManager.instance.primaryFocus;
    // "?" zeigt überall die Tastenkürzel – außer beim Tippen in ein Textfeld.
    if (event is KeyDownEvent && event.character == '?' && !_sheetOpen) {
      final ctx = primary?.context;
      final typing =
          ctx != null && (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null);
      final navContext = widget.router.routerDelegate.navigatorKey.currentState?.overlay?.context;
      if (!typing && navContext != null) {
        _sheetOpen = true;
        showShortcutSheet(navContext).whenComplete(() => _sheetOpen = false);
        return true;
      }
    }
    if (primary != null && primary != FocusManager.instance.rootScope && primary != _frameFocus) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final direction = _arrowDirections[event.logicalKey];
    if (direction == null) return false;
    moveFocusInDirection(direction);
    return true;
  }

  /// Controller außerhalb des Players: Fokus bewegen, auswählen, zurück …
  void _onPadAction(PadAction action) {
    final focus = FocusManager.instance.primaryFocus;
    final direction = switch (action) {
      PadAction.up => TraversalDirection.up,
      PadAction.down => TraversalDirection.down,
      PadAction.left => TraversalDirection.left,
      PadAction.right => TraversalDirection.right,
      _ => null,
    };
    if (direction != null) {
      moveFocusInDirection(direction);
      return;
    }
    final context = focus?.context;
    switch (action) {
      case PadAction.select:
        if (context != null) Actions.maybeInvoke(context, const ActivateIntent());
      case PadAction.menu:
        if (context != null) Actions.maybeInvoke(context, const ShowContextMenuIntent());
      case PadAction.back:
        // Schließt ein offenes Menü bzw. geht eine Seite zurück.
        if (context != null) {
          Navigator.maybeOf(context)?.maybePop();
        } else if (widget.router.canPop()) {
          widget.router.pop();
        }
      case PadAction.search:
        if (_currentPath() != '/search') widget.router.push('/search');
      default:
    }
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
        // Strg+, öffnet die Einstellungen.
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          if (loggedInArea && !path.startsWith('/play') && path != '/settings') widget.router.push('/settings');
        },
        // F11 schaltet überall Vollbild um.
        const SingleActivator(LogicalKeyboardKey.f11): toggleWindowFullscreen,
      },
      // Esc und Alt+← nur abfangen, wenn sie hier etwas bewirken – sonst bleiben sie
      // für Menüs, Dialoge usw. (z. B. Esc schließt ein Kontextmenü).
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _ExitFullscreenIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _GoBackIntent(),
        },
        child: Actions(
          actions: {
            _ExitFullscreenIntent: _WhenAction<_ExitFullscreenIntent>(
              () => windowFullscreen.value,
              () => setWindowFullscreen(false),
            ),
            _GoBackIntent: _WhenAction<_GoBackIntent>(() => showBack, () => widget.router.pop()),
          },
          // Fängt Tastendrücke auf, wenn sonst nichts fokussiert ist (z. B. auf der Startseite).
          child: Focus(
            autofocus: true,
            focusNode: _frameFocus,
            // Pfeiltasten bewegen den Fokus (eigene, TV-artige Regel). Textfelder und der
            // Player verarbeiten ihre Pfeiltasten vorher selbst.
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
              final direction = _arrowDirections[event.logicalKey];
              if (direction == null) return KeyEventResult.ignored;
              // Auch wenn es in die Richtung nichts gibt: Fokus bleibt, wo er ist.
              moveFocusInDirection(direction);
              return KeyEventResult.handled;
            },
            child: Listener(
              onPointerDown: (e) {
                if (e.buttons == kBackMouseButton && showBack) widget.router.pop();
              },
              child: _buildFrame(showBack),
            ),
          ),
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
            listenable: Listenable.merge([windowChromeVisible, windowFullscreen, windowMiniPlayer]),
            builder: (context, child) {
              // Im Vollbild und im Mini-Player keine Fensterknöpfe.
              final visible = windowChromeVisible.value && !windowFullscreen.value && !windowMiniPlayer.value;
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
                            tooltip: tr.back,
                            onPressed: () => widget.router.pop(),
                          )
                        : const SizedBox(key: ValueKey('none'), width: 8),
                  ),
                  const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
                  _TitleBarButton(
                    icon: Icons.remove_rounded,
                    tooltip: tr.minimize,
                    onPressed: () => windowManager.minimize(),
                  ),
                  _TitleBarButton(
                    icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                    iconSize: _maximized ? 14 : 16,
                    tooltip: _maximized ? tr.restore : tr.maximize,
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
                    tooltip: tr.close,
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

class _ExitFullscreenIntent extends Intent {
  const _ExitFullscreenIntent();
}

class _GoBackIntent extends Intent {
  const _GoBackIntent();
}

/// Aktion, die nur greift (und die Taste nur dann "verbraucht"), wenn [enabled] gilt.
class _WhenAction<T extends Intent> extends Action<T> {
  _WhenAction(this.enabled, this.run);

  final bool Function() enabled;
  final VoidCallback run;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    run();
    return null;
  }
}
