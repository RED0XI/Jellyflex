import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Bewegt den Fokus in eine Richtung – wie bei TV-Apps:
/// Es gewinnt das nächstgelegene Element in Pfeilrichtung, wobei Elemente in
/// derselben Zeile (links/rechts) bzw. Spalte (hoch/runter) stark bevorzugt
/// werden. Ist noch nichts fokussiert, beginnt es oben links.
///
/// Gibt `false` zurück, wenn es in diese Richtung nichts mehr gibt.
bool moveFocusInDirection(TraversalDirection direction) {
  final current = FocusManager.instance.primaryFocus;
  final scope = (current is FocusScopeNode ? current : current?.nearestScope) ?? FocusManager.instance.rootScope;

  // Nur Elemente der gerade sichtbaren Seite (bzw. des offenen Menüs).
  final candidates = scope.traversalDescendants.where((n) {
    final context = n.context;
    if (!n.canRequestFocus || n.skipTraversal || context == null || n.rect.width <= 0) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }).toList();
  if (candidates.isEmpty) return false;

  final onElement = current != null && current is! FocusScopeNode && candidates.contains(current);
  if (!onElement) {
    // Zeilenweise (Toleranz 32 px), innerhalb der Zeile von links nach rechts.
    candidates.sort((a, b) {
      final rowA = (a.rect.center.dy / 32).floor();
      final rowB = (b.rect.center.dy / 32).floor();
      return rowA != rowB ? rowA.compareTo(rowB) : a.rect.left.compareTo(b.rect.left);
    });
    candidates.first.requestFocus();
    return true;
  }

  final from = current.rect;
  FocusNode? best;
  var bestScore = double.infinity;
  for (final node in candidates) {
    if (node == current) continue;
    final r = node.rect;
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
  best?.requestFocus();
  return best != null;
}

/// Abstand zweier Intervalle (0, wenn sie sich überlappen) – für "gleiche Zeile".
double _overlapGap(double aStart, double aEnd, double bStart, double bEnd) {
  if (bEnd < aStart) return aStart - bEnd;
  if (bStart > aEnd) return bStart - aEnd;
  return 0;
}
