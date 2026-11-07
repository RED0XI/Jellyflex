part of 'player_screen.dart';

// Bedienung auf dem Fernseher: wenige große Knöpfe, die das Steuerkreuz erreicht, und eine
// Zeitleiste, auf der links/rechts spult. Die Tasten-Logik steht in _PlayerScreenState._onTvKey.

/// Knopf in der Zeile unter der Zeitleiste: Pille mit Symbol und (optional) Text – mit Fokus weiß
/// hinterlegt, wie in den TV-Apps der großen Anbieter.
class _TvPill extends StatelessWidget {
  const _TvPill({required this.icon, required this.onPressed, this.label, this.tooltip, this.focusNode});

  final IconData icon;
  final String? label;

  /// Name für Bildschirmleser, wenn kein [label] zu sehen ist.
  final String? tooltip;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Focusable(
        tvRing: false,
        onTap: onPressed,
        semanticLabel: label ?? tooltip,
        focusNode: focusNode,
        builder: (context, focused) => AnimatedScale(
          scale: focused ? 1.06 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 18),
            decoration: BoxDecoration(
              color: focused ? Colors.white : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(23),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: focused ? Colors.black : Colors.white),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: focused ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeitleiste für die Fernbedienung: mit Fokus spulen links/rechts (gedrückt halten = weiter).
class _TvSeekBar extends StatefulWidget {
  const _TvSeekBar({required this.player, required this.onSeek, required this.onToggle, this.focusNode});

  final Player player;
  final FocusNode? focusNode;
  final void Function(Duration by) onSeek;

  /// OK auf der Zeitleiste: Pause/Weiter (wie bei Apple TV und Netflix).
  final VoidCallback onToggle;

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  bool _focused = false;

  /// Gedrückt halten: erst 10 s, nach einer Weile 30 s je Schritt.
  int _repeats = 0;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      _repeats = 0;
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      widget.onToggle();
      return KeyEventResult.handled;
    }
    final dir = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
        ? 1
        : 0;
    if (dir == 0) return KeyEventResult.ignored;
    _repeats = event is KeyRepeatEvent ? _repeats + 1 : 0;
    widget.onSeek(Duration(seconds: dir * (_repeats > 8 ? 30 : 10)));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: _onKey,
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, snap) {
          final position = snap.data ?? Duration.zero;
          final duration = player.state.duration;
          final total = duration.inMilliseconds;
          final fraction = total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
          final left = duration - position;
          const time = TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          );
          return Row(
            children: [
              SizedBox(width: 84, child: Text(formatTimecode(position), style: time)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final height = _focused ? 10.0 : 5.0;
                    return SizedBox(
                      height: 28,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: height,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(height),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: height,
                            width: box.maxWidth * fraction,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(height),
                            ),
                          ),
                          // Griff nur mit Fokus – zeigt, dass links/rechts jetzt spult.
                          if (_focused)
                            Positioned(
                              left: (box.maxWidth * fraction - 12).clamp(0.0, box.maxWidth - 24),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  duration > Duration.zero ? '-${formatTimecode(left)}' : '',
                  textAlign: TextAlign.right,
                  style: time,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
