import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding.dart';
import '../core/gamepad_input.dart';
import '../core/settings.dart';
import '../core/ui_sounds.dart';
import '../theme.dart';
import 'brand_mark.dart';

/// Kurzes Intro beim Start der App (3 s): Das Zeichen zeichnet sich, füllt sich und federt, ein
/// Lichtstreif huscht darüber, die zwei "Sende"-Bögen erscheinen, der Name schreibt sich daneben,
/// dann öffnet sich die App. Klang dazu (assets/sounds/intro.wav) mit eigenem Schalter.
///
/// Liegt über der App, die darunter schon lädt. Jede Taste oder Berührung überspringt es.
/// Nur beim Kaltstart, nicht in Tests, nicht mit "Bewegungen reduzieren" und abschaltbar
/// (Einstellungen → Allgemein → Intro beim Start / Intro-Klang).
class AppIntro extends ConsumerStatefulWidget {
  const AppIntro({super.key, required this.child});

  final Widget child;

  /// Schon gezeigt (einmal je Programmstart).
  static bool _shown = false;

  /// Läuft das Intro gerade? Dann gehören Tasten ihm (siehe WindowFrame: keine Kürzel darunter).
  static bool get showing => _showing;
  static bool _showing = false;

  /// Tests, die das Intro selbst prüfen: auch unter der Test-Bindung zeigen.
  @visibleForTesting
  static bool showInTests = false;

  @visibleForTesting
  static void debugReset() => _shown = false;

  @override
  ConsumerState<AppIntro> createState() => _AppIntroState();
}

class _AppIntroState extends ConsumerState<AppIntro> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3000);

  late final AnimationController _anim = AnimationController(vsync: this, duration: _duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });

  bool _visible = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final inTest = WidgetsBinding.instance is! WidgetsFlutterBinding && !AppIntro.showInTests;
    final settings = ref.read(settingsProvider);
    if (AppIntro._shown || inTest || !settings.intro) return;
    AppIntro._shown = true;
    _visible = true;
    AppIntro._showing = true;
    // Früh abfangen: Die Taste gehört dem Intro und kommt in der App darunter gar nicht erst an
    // (ein HardwareKeyboard-Handler hält sie nicht auf – der Fokus-Baum bekäme sie trotzdem).
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    _keysHooked = true;
    GamepadInput.overlayHandler ??= _onPad;
    // Kurz auf die Klänge warten (Laden dauert wenige Millisekunden) – dann beginnen Bild und Ton
    // zusammen. Spätestens nach 400 ms geht es trotzdem los.
    // Und erst, wenn die App darunter ihre ersten Bilder gezeichnet hat: Beim Kaltstart baut sie
    // gerade die erste Seite – in dieser Zeit stockte sonst der Anfang der Animation.
    Future.wait([UiSounds.ready.timeout(const Duration(milliseconds: 400), onTimeout: () {}), _afterFirstFrames()])
        .whenComplete(_start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Bewegungen reduzieren" (Bedienungshilfen): kein Intro.
    if (_visible && MediaQuery.of(context).disableAnimations) _finish();
  }

  static Future<void> _afterFirstFrames() async {
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  void _start() {
    if (!mounted || !_visible || _started) return;
    _started = true;
    if (ref.read(settingsProvider).introSound) UiSounds.play(UiSound.intro, always: true);
    _anim.forward();
  }

  /// Tasten, die während des Intros gedrückt wurden und noch nicht losgelassen sind – auch ihr
  /// Rest (Wiederholungen, Loslassen) gehört nicht der App.
  final _heldKeys = <PhysicalKeyboardKey>{};
  bool _keysHooked = false;

  KeyEventResult _onKey(KeyEvent event) {
    if (_visible) {
      if (event is KeyDownEvent) {
        _heldKeys.add(event.physicalKey);
        _skip();
      } else if (event is KeyUpEvent) {
        _heldKeys.remove(event.physicalKey);
      }
      return KeyEventResult.handled;
    }
    // Intro ist weg: nur noch die Tasten schlucken, die es übersprungen haben.
    if (!_heldKeys.contains(event.physicalKey)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      _heldKeys.remove(event.physicalKey);
      if (_heldKeys.isEmpty) _unhookKeys();
    }
    return KeyEventResult.handled;
  }

  void _unhookKeys() {
    if (!_keysHooked) return;
    _keysHooked = false;
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
  }

  /// Controller: jede Eingabe überspringt das Intro und gilt nicht der App darunter.
  bool _onPad(PadAction action) {
    if (!_visible) return false;
    _skip();
    return true;
  }

  /// Überspringen: gleich ausblenden.
  void _skip() {
    if (!_visible) return;
    if (!_started) return _finish();
    if (_anim.value < _exitStart) {
      _anim.animateTo(1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      _skipped = true;
    }
  }

  bool _skipped = false;
  static const _exitStart = 0.84;

  void _finish() {
    AppIntro._showing = false;
    if (GamepadInput.overlayHandler == _onPad) GamepadInput.overlayHandler = null;
    if (_heldKeys.isEmpty) _unhookKeys();
    if (mounted && _visible) {
      setState(() => _visible = false);
    } else {
      _visible = false;
    }
  }

  @override
  void dispose() {
    if (_visible) AppIntro._showing = false;
    if (GamepadInput.overlayHandler == _onPad) GamepadInput.overlayHandler = null;
    _unhookKeys();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Immer derselbe Aufbau: Fiele der Stack am Ende weg, entstünde die ganze App darunter neu
    // (Fensterrahmen, Router …) – und der alte Fensterrahmen nähme beim Abbau die Controller-Abfrage mit.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skip,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => _IntroFrame(
                  t: _anim.value,
                  skipped: _skipped,
                  name: appDisplayName(ref.read(settingsProvider)),
                  logo: customLogo(ref.read(settingsProvider)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ein Bild des Intros zum Zeitpunkt [t] (0…1 über 3 s).
class _IntroFrame extends StatelessWidget {
  const _IntroFrame({required this.t, required this.skipped, required this.name, this.logo});

  final double t;
  final bool skipped;

  /// Name der App – der eigene, falls in den Einstellungen einer vergeben ist.
  final String name;

  /// Eigenes Logo aus den Einstellungen – erscheint statt des Zeichens.
  final File? logo;

  /// Fortschritt in einem Abschnitt [from]…[to] von [t], mit [curve].
  double _seg(double from, double to, [Curve curve = Curves.easeInOut]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mark = (size.shortestSide * 0.24).clamp(72.0, 170.0);
    final fontSize = mark * 0.6;
    final gap = mark * 0.26;
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Colors.white,
      height: 1,
    );
    final textWidth = (TextPainter(
      text: TextSpan(text: name, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout()).width;

    // Zeitachse (passend zum Klang: Rauschen bis 0,8 s, Akkord bei 0,8 s, Töne bei 1,1 / 1,3 s).
    final glowBg = _seg(0.0, 0.25);
    final draw = _seg(0.02, 0.18, Curves.easeInOutCubic);
    final fill = _seg(0.15, 0.27);
    final pop = _seg(0.19, 0.33, Curves.easeOutBack);
    final shine = t < 0.27 || t > 0.42 ? -1.0 : _seg(0.27, 0.42, Curves.easeInOut);
    final arc1 = _seg(0.36, 0.45, Curves.easeOutBack);
    final arc2 = _seg(0.43, 0.52, Curves.easeOutBack);
    final slide = _seg(0.44, 0.66, Curves.easeInOutCubic);
    final glow = _seg(0.62, 0.70) * (1 - _seg(0.72, 0.84));
    final exit = _seg(0.84, 1.0, Curves.easeInCubic);

    final letters = name.characters.toList();
    final markScale = 0.82 + 0.18 * pop;
    // Das Zeichen beginnt in der Mitte und rückt nach links, während der Name erscheint.
    final shift = (gap + textWidth) / 2 * (1 - slide);

    // Material: Text außerhalb des Navigators bekäme sonst Flutters gelbe Warn-Unterstreichung.
    return Material(
      type: MaterialType.transparency,
      child: Opacity(
        opacity: 1 - exit,
        child: ColoredBox(
          color: AppColors.background,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Weiches Leuchten hinter dem Zeichen.
              Opacity(
                opacity: glowBg * 0.9,
                child: Container(
                  width: mark * 5,
                  height: mark * 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.accent.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1 + 0.06 * exit,
                // Langer eigener Name: verkleinern statt über den Rand zu laufen.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(shift, 0),
                          child: Transform.scale(
                            scale: markScale,
                            child: SizedBox(
                              width: mark,
                              height: mark,
                              child: logo != null
                                  // Eigenes Logo: blendet auf und federt (statt sich zu zeichnen).
                                  ? Opacity(
                                      opacity: fill,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(mark * 0.2),
                                        child: Image.file(
                                          logo!,
                                          fit: BoxFit.contain,
                                          cacheWidth: (mark * MediaQuery.devicePixelRatioOf(context)).ceil(),
                                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    )
                                  : CustomPaint(
                                      painter: BrandMarkPainter(
                                        colors: brandMarkColors(),
                                        draw: draw,
                                        fill: fill,
                                        shine: shine,
                                        highlight: fill,
                                        arc1: arc1,
                                        arc2: arc2,
                                        glow: glow,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        // Der Name schreibt sich Buchstabe für Buchstabe.
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (i, letter) in letters.indexed)
                                Builder(
                                  builder: (context) {
                                    final start = 0.46 + 0.2 * i / letters.length;
                                    final lt = _seg(start, start + 0.08, Curves.easeOutCubic);
                                    return Opacity(
                                      opacity: lt,
                                      child: Transform.translate(
                                        offset: Offset(0, fontSize * 0.25 * (1 - lt)),
                                        child: Text(letter, style: textStyle),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
