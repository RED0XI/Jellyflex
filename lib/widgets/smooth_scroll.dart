import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Flüssiges Mausrad-Scrollen.
///
/// Flutter springt unter Windows pro Mausrad-Raste hart um ~100 px.
/// Dieses Widget sammelt die Rad-Bewegungen und gleitet animiert zum Ziel.
/// Das Kind muss [physics] verwenden, damit es das Rad nicht selbst verarbeitet.
class SmoothScroll extends StatefulWidget {
  const SmoothScroll({super.key, required this.controller, required this.builder});

  final ScrollController controller;
  final Widget Function(BuildContext context, ScrollPhysics physics) builder;

  /// Physik für das Kind: Mausrad aus (übernehmen wir), sonst normal.
  static const ScrollPhysics physics = NeverScrollableScrollPhysics();

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll> {
  double? _target;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final controller = widget.controller;
      if (!controller.hasClients) return;
      final position = controller.position;
      final delta = (e as PointerScrollEvent).scrollDelta.dy;
      if (delta == 0) return;

      final base = _target ?? position.pixels;
      final target = (base + delta * 1.2).clamp(position.minScrollExtent, position.maxScrollExtent);
      _target = target;
      controller
          .animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic)
          .whenComplete(() {
            if (_target == target) _target = null;
          });
    });
  }

  // Touchpad-Gesten (Präzisions-Touchpad) direkt umsetzen.
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    _target = null;
    final next = position.pixels - event.panDelta.dy;
    controller.jumpTo(math.min(math.max(next, position.minScrollExtent), position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      child: widget.builder(context, SmoothScroll.physics),
    );
  }
}
