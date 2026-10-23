import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kontextmenü für das fokussierte Element öffnen (Menütaste, Umschalt+F10, Controller-X).
class ShowContextMenuIntent extends Intent {
  const ShowContextMenuIntent();
}

/// Macht ein Element per Tastatur und Controller bedienbar:
/// - Pfeiltasten / Steuerkreuz erreichen es (Fokus wird wie Hover angezeigt),
/// - Enter, Leertaste bzw. A-Taste lösen [onTap] aus,
/// - beim Fokussieren scrollt die Ansicht es mittig ins Bild (Reihe und Seite).
class Focusable extends StatefulWidget {
  const Focusable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.cursor = SystemMouseCursors.click,
    this.autofocus = false,
    this.enabled = true,
    this.scrollAlignment = 0.5,
    this.semanticLabel,
  });

  /// Name für Bildschirmleser. Ohne Angabe gilt der sichtbare Text im Inneren
  /// (z. B. Titel und Jahr einer Karte).
  final String? semanticLabel;

  /// [highlighted] = mit der Maus überfahren oder fokussiert.
  final Widget Function(BuildContext context, bool highlighted) builder;
  final VoidCallback? onTap;

  /// Rechtsklick (Bildschirmposition) – z. B. für Kontextmenüs.
  final ValueChanged<Offset>? onSecondaryTap;
  final MouseCursor cursor;
  final bool autofocus;
  final bool enabled;

  /// Wohin beim Fokussieren gescrollt wird (0 = Anfang, 0.5 = Mitte).
  final double scrollAlignment;

  @override
  State<Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<Focusable> {
  bool _hovered = false;
  bool _focused = false;

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      Scrollable.ensureVisible(
        context,
        alignment: widget.scrollAlignment,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    // Für Bildschirmleser: ein Knopf (mit Fokus), benannt nach seinem Text.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        child: _detector(enabled),
      ),
    );
  }

  Widget _detector(bool enabled) {
    return FocusableActionDetector(
      // Ohne Aktion nicht per Tastatur/Controller anspringbar.
      enabled: enabled,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? widget.cursor : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onFocusChange: _onFocusChange,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.contextMenu): ShowContextMenuIntent(),
        SingleActivator(LogicalKeyboardKey.f10, shift: true): ShowContextMenuIntent(),
      },
      actions: {
        ShowContextMenuIntent: CallbackAction<ShowContextMenuIntent>(
          onInvoke: (_) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) widget.onSecondaryTap?.call(box.localToGlobal(box.size.center(Offset.zero)));
            return null;
          },
        ),
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        onSecondaryTapUp: widget.onSecondaryTap == null ? null : (d) => widget.onSecondaryTap!(d.globalPosition),
        child: widget.builder(context, enabled && (_hovered || _focused)),
      ),
    );
  }
}
