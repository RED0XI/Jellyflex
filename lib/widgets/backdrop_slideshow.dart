import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/images.dart';
import '../core/session.dart';
import 'jf_image.dart';
import '../core/image_cache.dart';

/// Zeigt die Hintergrundbilder eines Eintrags. Gibt es mehrere
/// (backdrop, backdrop1, extrafanart/ …), wird langsam durchgeblendet.
class BackdropSlideshow extends ConsumerStatefulWidget {
  const BackdropSlideshow({super.key, required this.images, this.interval = const Duration(seconds: 10)});

  final List<ImageRef> images;
  final Duration interval;

  @override
  ConsumerState<BackdropSlideshow> createState() => _BackdropSlideshowState();
}

class _BackdropSlideshowState extends ConsumerState<BackdropSlideshow> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant BackdropSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _index = 0;
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.images.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() => _index = (_index + 1) % widget.images.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.expand();
    final api = ref.watch(apiProvider);
    final image = widget.images[_index % widget.images.length];
    final width = screenImageWidth(context);

    // Das nächste Bild schon vorladen, damit die Überblendung nicht ruckelt.
    if (widget.images.length > 1) {
      final next = widget.images[(_index + 1) % widget.images.length];
      precacheImage(CachedNetworkImage(api.imageUrl(next, maxWidth: width)), context).ignore();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: JfImage(
        key: ValueKey(image),
        url: api.imageUrl(image, maxWidth: width),
        blurHash: image.blurHash,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
