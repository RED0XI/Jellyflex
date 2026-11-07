import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/device.dart';

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
    if (isTv) return _revealMinimally();
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

  /// Fernseher: nur so weit scrollen, dass das Element ganz zu sehen ist – der Fokus wandert über
  /// die sichtbaren Karten, die Reihe rückt erst am Rand nach (wie bei Google TV und Apple TV).
  /// Ständiges Mittig-Ziehen ließ das ganze Bild bei jedem Schritt mitlaufen.
  void _revealMinimally() {
    final object = context.findRenderObject();
    if (object == null) return;
    const duration = Duration(milliseconds: 260);
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      // Diese Fläche richtet sich selbst aus (Startseite am Fernseher: Reihe immer oben).
      if (scrollable.widget.controller is TvAnchoredScrollController) break;
      final position = scrollable.position;
      // Hinter dem Ende → ans Ende holen; vor dem Anfang → an den Anfang. Sonst nichts.
      position.ensureVisible(
        object,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      position.ensureVisible(
        object,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
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

/// Fernseher: Scroll-Fläche, die selbst bestimmt, wo das fokussierte Element steht (z. B. die
/// Reihen der Startseite: die gewählte Reihe immer direkt unter den Infos). [Focusable] scrollt sie
/// beim Fokussieren nicht.
class TvAnchoredScrollController extends ScrollController {}
