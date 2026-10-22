import 'package:flutter/material.dart';

import '../theme.dart';

/// Horizontale Reihe mit Überschrift. Beim Überfahren erscheinen
/// links/rechts Pfeile zum seitenweisen Blättern.
class MediaRow extends StatefulWidget {
  const MediaRow({
    super.key,
    this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.spacing = 18,
    this.trailing,
  });

  final String? title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Höhe der Karten inklusive Beschriftung.
  final double height;
  final double spacing;
  final Widget? trailing;

  @override
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  final _controller = ScrollController();
  bool _hovered = false;
  bool _canBack = false;
  bool _canForward = true;

  /// Platz oben/unten, damit vergrößerte Karten nicht abgeschnitten werden.
  static const _vPad = 14.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final back = p.pixels > 4;
    final forward = p.pixels < p.maxScrollExtent - 4;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _page(int direction) {
    final p = _controller.position;
    final target = (p.pixels + direction * p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 550), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 0),
              child: Row(
                children: [
                  Text(
                    widget.title!,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  ),
                  const Spacer(),
                  ?widget.trailing,
                ],
              ),
            ),
          SizedBox(
            height: widget.height + _vPad * 2,
            child: Stack(
              children: [
                NotificationListener<ScrollMetricsNotification>(
                  onNotification: (_) {
                    _updateArrows();
                    return false;
                  },
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: kPageGutter, vertical: _vPad),
                    itemCount: widget.itemCount,
                    separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
                    itemBuilder: widget.itemBuilder,
                  ),
                ),
                _Arrow(
                  alignment: Alignment.centerLeft,
                  visible: _hovered && _canBack,
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _page(-1),
                  bottomInset: _vPad + 52,
                ),
                _Arrow(
                  alignment: Alignment.centerRight,
                  visible: _hovered && _canForward,
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _page(1),
                  bottomInset: _vPad + 52,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.alignment,
    required this.visible,
    required this.icon,
    required this.onTap,
    required this.bottomInset,
  });

  final Alignment alignment;
  final bool visible;
  final IconData icon;
  final VoidCallback onTap;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 14,
      bottom: bottomInset,
      width: kPageGutter,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                    end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [AppColors.background.withValues(alpha: 0.9), AppColors.background.withValues(alpha: 0)],
                  ),
                ),
                child: Icon(icon, size: 40, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
