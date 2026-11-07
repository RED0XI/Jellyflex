import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/device.dart';
import 'focus_navigation.dart';

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
    this.focusNode,
    this.onFocusChange,
    this.tvRing = true,
  });

  /// Fernseher: weiße Umrandung bei Fokus – für Elemente ohne eigene deutliche Fokus-Darstellung
  /// (aus 3 m Entfernung reicht "etwas heller" nicht). Karten & Co. mit eigener: `false`.
  final bool tvRing;

  /// Meldet, wenn das Element den Fokus bekommt bzw. verliert (z. B. für die Infos oben auf der
  /// Startseite am Fernseher).
  final ValueChanged<bool>? onFocusChange;

  /// Eigener Fokus-Knoten – um das Element gezielt anzuspringen (z. B. Play beim Einblenden).
  final FocusNode? focusNode;

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
    widget.onFocusChange?.call(focused);
    if (!focused) return;
    if (isTv) return revealInScrollables(context, minimal: true);
    Scrollable.ensureVisible(
      context,
      alignment: widget.scrollAlignment,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _withTvRing(Widget child, bool focused) {
    if (!isTv || !widget.tvRing) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: const DecoratedBox(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: Colors.white, width: 2.5)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    // Für Bildschirmleser: ein Knopf (mit Fokus), benannt nach seinem Text.
    return MergeSemantics(
      child: Semantics(button: true, enabled: enabled, label: widget.semanticLabel, child: _detector(enabled)),
    );
  }

  Widget _detector(bool enabled) {
    return FocusableActionDetector(
      // Ohne Aktion nicht per Tastatur/Controller anspringbar.
      enabled: enabled,
      focusNode: widget.focusNode,
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
        child: _withTvRing(widget.builder(context, enabled && (_hovered || _focused)), enabled && _focused),
      ),
    );
  }
}

/// Fernseher: weiße Umrandung, sobald ein Element darin den Fokus hat – für Standard-Elemente
/// (Schalter, Auswahlmenüs), deren eigene Fokus-Anzeige aus 3 m nicht zu sehen ist. Sonst: [child].
class TvFocusRing extends StatefulWidget {
  const TvFocusRing({super.key, required this.child});

  final Widget child;

  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!isTv) return widget.child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _focused ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: Colors.white, width: 2.5)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
