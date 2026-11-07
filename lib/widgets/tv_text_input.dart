import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/platform/device.dart';

/// Textfelder auf dem Fernseher: Die Bildschirmtastatur geht erst auf OK auf.
///
/// Android TV öffnet sonst die Tastatur, sobald der Fokus ein Textfeld nur streift – und die
/// Tastatur übernimmt dann das Steuerkreuz, man kommt nicht mehr am Feld vorbei. Hier bleibt
/// das Feld schreibgeschützt (`readOnly`), bis OK/Enter gedrückt wird; mit "Fertig" auf der
/// Tastatur ([done]) oder wenn der Fokus weiterzieht, ist es wieder nur ein Ziel unter vielen.
///
/// Mit "Weiter" auf der Tastatur (TextInputAction.next) bleibt die Tastatur offen: das nächste
/// Feld mit [TvTextInput] übernimmt direkt.
///
/// Auf allen anderen Geräten: `readOnly` ist immer `false`, [done] tut nichts.
class TvTextInput extends StatefulWidget {
  const TvTextInput({super.key, required this.builder});

  /// [readOnly] an das TextField weitergeben; [done] in `onSubmitted` aufrufen.
  final Widget Function(BuildContext context, bool readOnly, VoidCallback done) builder;

  /// Das Feld, das zuletzt beim Tippen den Fokus abgegeben hat (z. B. "Weiter").
  static DateTime? _handoff;

  @override
  State<TvTextInput> createState() => _TvTextInputState();
}

class _TvTextInputState extends State<TvTextInput> {
  bool _editing = false;

  static final _openKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  void _setEditing(bool value) {
    if (_editing != value && mounted) setState(() => _editing = value);
  }

  void _done() => _setEditing(false);

  void _onFocusChange(bool focused) {
    if (focused) {
      // Erst nachsehen, wenn auch das alte Feld seinen Fokusverlust gemeldet hat (die Reihenfolge
      // der beiden Meldungen ist nicht festgelegt).
      scheduleMicrotask(() {
        final handoff = TvTextInput._handoff;
        TvTextInput._handoff = null;
        if (handoff != null && DateTime.now().difference(handoff) < const Duration(milliseconds: 600)) {
          _setEditing(true);
        }
      });
    } else if (_editing) {
      TvTextInput._handoff = DateTime.now();
      // Erst nach diesem Frame zurücksetzen – sonst schließt sich die Tastatur kurz und geht
      // beim nächsten Feld gleich wieder auf.
      scheduleMicrotask(() => _setEditing(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isTv) return widget.builder(context, false, _done);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (_editing || event is! KeyDownEvent || !_openKeys.contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        _setEditing(true);
        return KeyEventResult.handled;
      },
      child: widget.builder(context, !_editing, _done),
    );
  }
}
