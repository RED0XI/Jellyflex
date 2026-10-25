import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

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

class _SmoothScrollState extends State<SmoothScroll> with SingleTickerProviderStateMixin {
  double? _target;

  // Touchpad-Schwung: Nach dem Loslassen rollt die Seite aus wie im System.
  late final Ticker _flingTicker = createTicker(_onFlingTick);
  Simulation? _fling;
  VelocityTracker? _panVelocity;

  @override
  void dispose() {
    _flingTicker.dispose();
    super.dispose();
  }

  void _stopFling() {
    _fling = null;
    if (_flingTicker.isActive) _flingTicker.stop();
  }

  void _onFlingTick(Duration elapsed) {
    final fling = _fling;
    final controller = widget.controller;
    if (fling == null || !controller.hasClients) return _stopFling();
    final position = controller.position;
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final next = fling.x(t).clamp(position.minScrollExtent, position.maxScrollExtent);
    controller.jumpTo(next);
    if (fling.isDone(t) || next == position.minScrollExtent || next == position.maxScrollExtent) _stopFling();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _stopFling();
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

  // Touchpad-Gesten (Präzisions-Touchpad, Mac-Trackpad) direkt umsetzen.
  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _stopFling();
    _panVelocity = VelocityTracker.withKind(PointerDeviceKind.trackpad);
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _panVelocity?.addPosition(event.timeStamp, event.pan);
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    _target = null;
    final next = position.pixels - event.panDelta.dy;
    controller.jumpTo(math.min(math.max(next, position.minScrollExtent), position.maxScrollExtent));
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    final tracker = _panVelocity;
    _panVelocity = null;
    final controller = widget.controller;
    if (tracker == null || !controller.hasClients) return;
    // Finger nach unten = Inhalt nach oben, daher das Vorzeichen.
    final velocity = -tracker.getVelocity().pixelsPerSecond.dy;
    if (velocity.abs() < kMinFlingVelocity) return;
    // Gleiche Reibung wie das Ausrollen unter macOS/iOS (BouncingScrollSimulation).
    _fling = FrictionSimulation(0.135, controller.position.pixels, velocity.clamp(-kMaxFlingVelocity, kMaxFlingVelocity));
    _flingTicker.start();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      child: widget.builder(context, SmoothScroll.physics),
    );
  }
}
