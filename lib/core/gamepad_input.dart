import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

/// Was eine Controller-Eingabe in der App bedeutet.
enum PadAction { up, down, left, right, select, back, playPause, search, menu }

/// Übersetzt Controller-Eingaben (Xbox, PlayStation …) in App-Aktionen.
///
/// - Steuerkreuz / linker Stick: Fokus bewegen (gedrückt halten wiederholt)
/// - A: auswählen, B: zurück, Start: Abspielen/Pause, Y: Suche, X: Kontextmenü
///
/// Ist der Player offen, bekommt er die Eingaben zuerst ([playerHandler]).
abstract final class GamepadInput {
  static StreamSubscription<NormalizedGamepadEvent>? _subscription;
  static void Function(PadAction action)? _onAction;

  /// Vom Player gesetzt; `true` = Eingabe verarbeitet.
  static bool Function(PadAction action)? playerHandler;

  static final _pressed = <GamepadButton>{};
  static PadAction? _stickDirection;
  static Timer? _repeat;

  static const _stickThreshold = 0.6;

  static void start(void Function(PadAction action) onAction) {
    _onAction = onAction;
    _subscription?.cancel();
    try {
      _subscription = Gamepads.normalizedEvents.listen(_onEvent, onError: (_) {});
    } catch (_) {
      // Kein Controller-Support auf diesem System.
    }
  }

  /// Für Tests: eine Controller-Aktion so auslösen, als käme sie vom Gerät.
  static void simulate(PadAction action) => _dispatch(action);

  static void stop() {
    _subscription?.cancel();
    _repeat?.cancel();
  }

  static void _onEvent(NormalizedGamepadEvent event) {
    final button = event.button;
    if (button != null) {
      final down = event.value > 0.5;
      if (down && _pressed.add(button)) {
        final action = _buttonAction(button);
        if (action != null) _press(action, repeat: _isDirection(action));
      } else if (!down && _pressed.remove(button)) {
        _repeat?.cancel();
      }
      return;
    }

    final axis = event.axis;
    if (axis != GamepadAxis.leftStickX && axis != GamepadAxis.leftStickY) return;
    PadAction? direction;
    if (event.value.abs() > _stickThreshold) {
      direction = switch (axis) {
        GamepadAxis.leftStickX => event.value > 0 ? PadAction.right : PadAction.left,
        _ => event.value > 0 ? PadAction.up : PadAction.down,
      };
    }
    if (direction == _stickDirection) return;
    // Stick in Ruhelage der jeweils anderen Achse ignorieren.
    if (direction == null && _stickDirection != null) {
      final sameAxis = axis == GamepadAxis.leftStickX
          ? (_stickDirection == PadAction.left || _stickDirection == PadAction.right)
          : (_stickDirection == PadAction.up || _stickDirection == PadAction.down);
      if (!sameAxis) return;
    }
    _stickDirection = direction;
    _repeat?.cancel();
    if (direction != null) _press(direction, repeat: true);
  }

  /// Aktion auslösen; Richtungen wiederholen sich beim Halten (erst langsam, dann schneller).
  static void _press(PadAction action, {required bool repeat}) {
    _dispatch(action);
    _repeat?.cancel();
    if (!repeat) return;
    _repeat = Timer(const Duration(milliseconds: 420), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 110), (_) => _dispatch(action));
    });
  }

  static void _dispatch(PadAction action) {
    // Im UI-Thread nach dem aktuellen Frame ausführen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (playerHandler?.call(action) ?? false) return;
      _onAction?.call(action);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  static bool _isDirection(PadAction a) =>
      a == PadAction.up || a == PadAction.down || a == PadAction.left || a == PadAction.right;

  static PadAction? _buttonAction(GamepadButton button) => switch (button) {
    GamepadButton.dpadUp => PadAction.up,
    GamepadButton.dpadDown => PadAction.down,
    GamepadButton.dpadLeft => PadAction.left,
    GamepadButton.dpadRight => PadAction.right,
    GamepadButton.a => PadAction.select,
    GamepadButton.b || GamepadButton.back => PadAction.back,
    GamepadButton.start => PadAction.playPause,
    GamepadButton.y => PadAction.search,
    GamepadButton.x => PadAction.menu,
    _ => null,
  };
}
