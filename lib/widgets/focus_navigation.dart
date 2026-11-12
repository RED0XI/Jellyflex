import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/platform/device.dart';

/// Bewegt den Fokus in eine Richtung – wie bei TV-Apps:
/// Es gewinnt das nächstgelegene Element in Pfeilrichtung, wobei Elemente in
/// derselben Zeile (links/rechts) bzw. Spalte (hoch/runter) stark bevorzugt
/// werden. Ist noch nichts fokussiert, beginnt es oben links.
///
/// Gibt `false` zurück, wenn es in diese Richtung nichts mehr gibt.
bool moveFocusInDirection(TraversalDirection direction) {
  if (_moveWithinScope(direction)) return true;
  // Am Rand angekommen: z. B. von der Seite in die Seitenleiste wechseln.
  return focusEdgeHandler?.call(direction) ?? false;
}

/// Wird aufgerufen, wenn es in einer Richtung nichts mehr gibt (Seitenleiste).
bool Function(TraversalDirection direction)? focusEdgeHandler;

/// Fokussierbare Elemente unter [root] – nur die der gerade sichtbaren Seite (bzw. des offenen Menüs).
List<FocusNode> _candidatesUnder(FocusNode root) => root.traversalDescendants.where((n) {
  final context = n.context;
  if (!n.canRequestFocus || n.skipTraversal || context == null || n.rect.width <= 0) return false;
  return ModalRoute.of(context)?.isCurrent ?? true;
}).toList();

/// Fokussiert das erste Element unter [root] (oben links, zeilenweise). `false`, wenn es keines gibt.
///
/// Für Sprünge in einen anderen Bereich (Seite ↔ Leiste): [FocusNode.requestFocus] wirkt erst
/// nach dem laufenden Tastendruck – wer danach [moveFocusInDirection] ruft, bewegt noch den
/// alten Fokus (und landet am Rand wieder im selben Rand-Handler).
bool focusFirstUnder(FocusNode root) {
  final candidates = _candidatesUnder(root);
  if (candidates.isEmpty) return false;
  // Zeilenweise (Toleranz 32 px), innerhalb der Zeile von links nach rechts.
  candidates.sort((a, b) {
    final rowA = (a.rect.center.dy / 32).floor();
    final rowB = (b.rect.center.dy / 32).floor();
    return rowA != rowB ? rowA.compareTo(rowB) : a.rect.left.compareTo(b.rect.left);
  });
  candidates.first.requestFocus();
  revealFocused(candidates.first);
  return true;
}

bool _moveWithinScope(TraversalDirection direction) {
  final current = FocusManager.instance.primaryFocus;
  final scope = (current is FocusScopeNode ? current : current?.nearestScope) ?? FocusManager.instance.rootScope;

  final candidates = _candidatesUnder(scope);
  if (candidates.isEmpty) return false;

  final onElement = current != null && current is! FocusScopeNode && candidates.contains(current);
  if (!onElement) return focusFirstUnder(scope);

  final from = current.rect;
  // Links/rechts zuerst innerhalb derselben Zeile (senkrecht überlappend) – sonst sprang der Fokus
  // z. B. am Anfang einer Reihe in eine andere, seitwärts gescrollte Reihe, deren Karten links
  // außerhalb des Bildes liegen, statt in die Seitenleiste. Gibt es dort nichts, zählt jedes
  // sichtbare Element in der Richtung (z. B. von der Bereichsliste zu den Einstellungen).
  final horizontal = direction == TraversalDirection.left || direction == TraversalDirection.right;
  final best =
      _best(candidates, current, from, direction, sameRow: horizontal) ??
      (horizontal ? _best(candidates, current, from, direction, onScreenOnly: true) : null);
  best?.requestFocus();
  if (best != null) revealFocused(best);
  return best != null;
}

FocusNode? _best(
  List<FocusNode> candidates,
  FocusNode current,
  Rect from,
  TraversalDirection direction, {
  bool sameRow = false,
  bool onScreenOnly = false,
}) {
  FocusNode? best;
  var bestScore = double.infinity;
  for (final node in candidates) {
    if (node == current) continue;
    final r = node.rect;
    if (sameRow && _overlapGap(from.top, from.bottom, r.top, r.bottom) > 0) continue;
    if (onScreenOnly && !_visible(node)) continue;
    final double along;
    final double across;
    switch (direction) {
      case TraversalDirection.right:
        if (r.center.dx <= from.center.dx + 1 || r.left < from.right - from.width * 0.5) continue;
        along = r.left - from.right;
        across = _overlapGap(from.top, from.bottom, r.top, r.bottom);
      case TraversalDirection.left:
        if (r.center.dx >= from.center.dx - 1 || r.right > from.left + from.width * 0.5) continue;
        along = from.left - r.right;
        across = _overlapGap(from.top, from.bottom, r.top, r.bottom);
      case TraversalDirection.down:
        if (r.center.dy <= from.center.dy + 1 || r.top < from.bottom - from.height * 0.5) continue;
        along = r.top - from.bottom;
        across = (r.center.dx - from.center.dx).abs();
      case TraversalDirection.up:
        if (r.center.dy >= from.center.dy - 1 || r.bottom > from.top + from.height * 0.5) continue;
        along = from.top - r.bottom;
        across = (r.center.dx - from.center.dx).abs();
    }
    // Abweichung quer zur Richtung zählt deutlich stärker als die Entfernung.
    final score = math.max(0.0, along) + across * 3;
    if (score < bestScore) {
      bestScore = score;
      best = node;
    }
  }
  return best;
}

/// Abstand zweier Intervalle (0, wenn sie sich überlappen) – für "gleiche Zeile".
double _overlapGap(double aStart, double aEnd, double bStart, double bEnd) {
  if (bEnd < aStart) return aStart - bEnd;
  if (bStart > aEnd) return bStart - aEnd;
  return 0;
}

/// Ist das Element wirklich zu sehen – also nicht aus einer Scroll-Fläche herausgescrollt (auch
/// wenn seine Fläche geometrisch noch im Bildschirm liegt, z. B. über einem abgeschnittenen Rand)?
bool _visible(FocusNode node) {
  final context = node.context;
  if (context == null) return false;
  var rect = node.rect;
  var scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    final box = scrollable.context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      rect = rect.intersect(box.localToGlobal(Offset.zero) & box.size);
      if (rect.width <= 1 || rect.height <= 1) return false;
    }
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
  return true;
}

/// Scrollt das fokussierte Element ins Bild – auch Standard-Elemente (Schalter, Auswahlmenüs), die
/// das nicht selbst tun ([Focusable] tut es schon; doppelt schadet nicht, das Ziel ist dasselbe).
/// Fernseher: nur so weit wie nötig; sonst mittig.
void revealFocused(FocusNode node) {
  final context = node.context;
  if (context == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    revealInScrollables(context, minimal: isTv);
  });
}

/// Fernseher-Startseite & Co.: Scroll-Flächen mit diesem Controller richten sich selbst aus.
class TvAnchoredScrollController extends ScrollController {}

/// [context] in allen umgebenden Scroll-Flächen sichtbar machen. [minimal]: nur so weit wie nötig
/// (Fernseher: der Fokus wandert über das Sichtbare, die Fläche rückt erst am Rand nach).
void revealInScrollables(BuildContext context, {required bool minimal, double alignment = 0.5}) {
  final object = context.findRenderObject();
  if (object == null || !object.attached) return;
  const duration = Duration(milliseconds: 260);
  if (!minimal) {
    Scrollable.ensureVisible(context, alignment: alignment, duration: duration, curve: Curves.easeOutCubic);
    return;
  }
  var scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
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
