import 'package:flutter/widgets.dart';

import '../core/power.dart';

/// Baut [child] erst, wenn die Seite fertig aufgegangen ist – beim Energiesparen (immer auf dem
/// Fernseher). Bis dahin Platzhalter in [height]. Für Abschnitte weiter unten (Besetzung, Ähnliches):
/// Man sieht sie ohnehin erst beim Scrollen, und so baut ein schwacher Chip nicht alles samt Bildern
/// in genau den Bildern auf, in denen die Seite einblendet.
class AfterTransition extends StatefulWidget {
  const AfterTransition({super.key, required this.child, this.height = 0});

  final Widget child;
  final double height;

  @override
  State<AfterTransition> createState() => _AfterTransitionState();
}

class _AfterTransitionState extends State<AfterTransition> {
  bool _ready = !Power.energySaving.value;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _ready = true;
      return;
    }
    if (animation != _animation) {
      _animation?.removeStatusListener(_onStatus);
      _animation = animation..addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = null;
    // Noch ein Bild Luft nach dem Übergang.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready ? widget.child : SizedBox(height: widget.height);
}
