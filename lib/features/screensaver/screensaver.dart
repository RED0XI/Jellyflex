import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/gamepad_input.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/jf_image.dart';

/// Startet den Bildschirmschoner sofort (z. B. Vorschau in den Einstellungen).
final screensaverPreview = ValueNotifier<int>(0);

/// Bildschirmschoner: Nach einigen Minuten ohne Eingabe gleiten langsam die
/// Hintergrundbilder der eigenen Filme und Serien vorbei (Ken-Burns-Effekt),
/// mit Titel-Logo und Uhr. Jede Eingabe (Maus, Tastatur, Controller) beendet ihn.
///
/// Nie im Player und nie ohne Anmeldung.
class Screensaver extends ConsumerStatefulWidget {
  const Screensaver({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<Screensaver> createState() => _ScreensaverState();
}

class _ScreensaverState extends ConsumerState<Screensaver> {
  Timer? _idle;
  bool _active = false;

  /// Solange aktiv, liegt der Tastatur-Fokus hier – so lösen Tasten darunter
  /// (z. B. Strg+F) nichts aus. Danach bekommt das vorherige Element ihn zurück.
  final _focus = FocusNode(debugLabel: 'Screensaver');
  FocusNode? _previousFocus;

  /// Nach dem Aufwecken per Taste: Tasten schlucken, bis alle losgelassen sind.
  bool _swallowKeys = false;

  /// Mausbewegung seit dem Start – kleines Zittern soll ihn nicht beenden.
  double _moved = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onAnyKey);
    GamepadInput.overlayHandler = _onPad;
    screensaverPreview.addListener(_start);
    _restartTimer();
  }

  @override
  void dispose() {
    _idle?.cancel();
    HardwareKeyboard.instance.removeHandler(_onAnyKey);
    if (GamepadInput.overlayHandler == _onPad) GamepadInput.overlayHandler = null;
    screensaverPreview.removeListener(_start);
    _focus.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _idle?.cancel();
    final minutes = ref.read(settingsProvider).screensaverMinutes;
    if (minutes <= 0) return;
    _idle = Timer(Duration(minutes: minutes), _startIfAllowed);
  }

  void _startIfAllowed() {
    final loggedIn = ref.read(sessionProvider).value != null;
    final config = widget.router.routerDelegate.currentConfiguration;
    final path = config.isEmpty ? '' : widget.router.state.uri.path;
    if (!loggedIn || path.startsWith('/play') || path == '/login' || path == '/splash') {
      _restartTimer();
      return;
    }
    _start();
  }

  void _start() {
    if (_active || !mounted) return;
    _moved = 0;
    _previousFocus = FocusManager.instance.primaryFocus;
    setState(() => _active = true);
    _focus.requestFocus();
  }

  /// Beendet den Bildschirmschoner. [byKey]: Fokus erst zurückgeben, wenn die
  /// Tasten losgelassen sind.
  void _stop({bool byKey = false}) {
    _restartTimer();
    if (!_active) return;
    setState(() => _active = false);
    if (byKey) {
      _swallowKeys = true;
    } else {
      _restoreFocus();
    }
  }

  void _restoreFocus() {
    final previous = _previousFocus;
    _previousFocus = null;
    if (previous != null && previous.context != null) {
      previous.requestFocus();
    } else {
      _focus.unfocus();
    }
  }

  /// Jede Taste irgendwo startet die Wartezeit neu (verarbeitet wird sie normal).
  bool _onAnyKey(KeyEvent event) {
    if (!_active && !_swallowKeys) _restartTimer();
    return false;
  }

  KeyEventResult _onOverlayKey(FocusNode node, KeyEvent event) {
    if (_active) {
      if (event is KeyDownEvent) _stop(byKey: true);
      return KeyEventResult.handled;
    }
    if (_swallowKeys) {
      if (HardwareKeyboard.instance.logicalKeysPressed.isEmpty) {
        _swallowKeys = false;
        _restoreFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _onPad(PadAction action) {
    if (!_active) {
      _restartTimer();
      return false;
    }
    _stop();
    return true;
  }

  void _onPointer(PointerEvent event) {
    if (!_active) {
      _restartTimer();
      return;
    }
    if (event is PointerHoverEvent || event is PointerMoveEvent) {
      _moved += event.delta.distance;
      if (_moved < 40) return;
    }
    _stop();
  }

  @override
  Widget build(BuildContext context) {
    // Geänderte Wartezeit in den Einstellungen sofort übernehmen.
    ref.listen(settingsProvider.select((s) => s.screensaverMinutes), (_, _) => _restartTimer());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointer,
      onPointerHover: _onPointer,
      onPointerMove: _onPointer,
      onPointerSignal: _onPointer,
      child: Stack(
        children: [
          widget.child,
          // Platz bleibt immer bestehen (sonst verlieren Elemente darunter ihren Fokus).
          Positioned.fill(
            child: Focus(
              focusNode: _focus,
              // Pfeiltasten/Tab sollen hier nie landen – nur _start() fokussiert ihn.
              skipTraversal: true,
              onKeyEvent: _onOverlayKey,
              child: _active
                  // Klicks nicht an die Seite darunter weitergeben.
                  // Liegt über dem Navigator → eigenes Material für Schrift und Farben.
                  ? const AbsorbPointer(
                      child: Material(type: MaterialType.transparency, child: _ScreensaverView()),
                    )
                  : const IgnorePointer(child: SizedBox.expand()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreensaverView extends ConsumerStatefulWidget {
  const _ScreensaverView();

  @override
  ConsumerState<_ScreensaverView> createState() => _ScreensaverViewState();
}

class _ScreensaverViewState extends ConsumerState<_ScreensaverView> with TickerProviderStateMixin {
  static const _slide = Duration(seconds: 14);

  late final _fadeIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final _kenBurns = AnimationController(vsync: this, duration: _slide);
  final _random = math.Random();
  List<BaseItem> _items = const [];
  int _index = 0;
  Offset _drift = Offset.zero;

  @override
  void initState() {
    super.initState();
    _kenBurns.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _load();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _kenBurns.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(apiProvider).getFeatured(limit: 30);
      if (!mounted) return;
      setState(() => _items = items.where((i) => Images.backdrop(i) != null).toList());
      if (_items.isNotEmpty) {
        _drift = _randomDrift();
        _kenBurns.forward(from: 0);
      }
    } catch (_) {
      // Ohne Server: nur Uhr auf dunklem Verlauf.
    }
  }

  Offset _randomDrift() {
    final angle = _random.nextDouble() * math.pi * 2;
    return Offset(math.cos(angle), math.sin(angle)) * 0.04;
  }

  void _next() {
    if (!mounted || _items.isEmpty) return;
    setState(() {
      _index = (_index + 1) % _items.length;
      _drift = _randomDrift();
    });
    _kenBurns.forward(from: 0);
    _precacheNext();
  }

  void _precacheNext() {
    if (_items.length < 2) return;
    final next = _items[(_index + 1) % _items.length];
    final url = ref.read(apiProvider).imageUrlOrNull(Images.backdrop(next), maxWidth: screenImageWidth(context));
    if (url != null) precacheImage(NetworkImage(url), context).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final item = _items.isEmpty ? null : _items[_index];
    return MouseRegion(
      cursor: SystemMouseCursors.none,
      child: FadeTransition(
        opacity: _fadeIn,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item == null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.6, -0.8),
                      radius: 1.6,
                      colors: [Color(0xFF241A3D), Colors.black],
                    ),
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 2200),
                  child: AnimatedBuilder(
                    key: ValueKey(item.id),
                    animation: _kenBurns,
                    builder: (context, child) {
                      final t = _kenBurns.value;
                      return Transform.scale(
                        scale: 1.05 + 0.12 * t,
                        child: FractionalTranslation(translation: _drift * t, child: child),
                      );
                    },
                    child: JfImage(
                      url: api.imageUrlOrNull(Images.backdrop(item), maxWidth: screenImageWidth(context)),
                      blurHash: Images.backdrop(item)?.blurHash,
                    ),
                  ),
                ),
              // Abdunkeln unten, damit Logo und Uhr lesbar bleiben.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.55, 1],
                    colors: [Color(0x40000000), Color(0x10000000), Color(0xCC000000)],
                  ),
                ),
              ),
              const Positioned(left: 56, top: 44, child: Opacity(opacity: 0.7, child: BrandLogo(size: 24))),
              if (item != null)
                Positioned(
                  left: 56,
                  bottom: 52,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1200),
                    child: _TitleBlock(key: ValueKey(item.id), item: item),
                  ),
                ),
              Positioned(
                right: 56,
                bottom: 48,
                child: _Clock(
                  builder: (now) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatClock(now),
                        style: const TextStyle(
                          fontSize: 92,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                          height: 1,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatWeekdayDate(now),
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFFE0E2EA),
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uhr, die sich nur zur vollen Minute neu zeichnet (statt die ganze Ansicht jede Sekunde).
class _Clock extends StatefulWidget {
  const _Clock({required this.builder});

  final Widget Function(DateTime now) builder;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_now);
}

class _TitleBlock extends ConsumerWidget {
  const _TitleBlock({super.key, required this.item});

  final BaseItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final logo = api.imageUrlOrNull(Images.logo(item), maxWidth: 800);
    final title = Text(
      item.name,
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 120),
            child: Image.network(
              logo,
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
              errorBuilder: (_, _, _) => title,
            ),
          )
        else
          title,
        const SizedBox(height: 10),
        Text(
          [?yearLabel(item), ...item.genres.take(2)].join('  ·  '),
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFFE0E2EA),
            shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}
