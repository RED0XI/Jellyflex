part of 'player_screen.dart';

// Bausteine des Players: Knöpfe, Spulleiste, Lautstärke, Ambilight, "Gute Nacht".

/// Leuchten aus den Farben des Bildes: dieselbe Videotextur, stark weichgezeichnet
/// und etwas vergrößert, gedämpft hinter dem eigentlichen Video.
class _Ambilight extends StatelessWidget {
  const _Ambilight({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<int?>(
        valueListenable: controller.id,
        builder: (context, id, _) {
          if (id == null) return const SizedBox.shrink();
          return RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 0.6,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.mirror),
                    child: Transform.scale(
                      scale: 1.15,
                      child: Texture(textureId: id, filterQuality: FilterQuality.low),
                    ),
                  ),
                ),
                // Ränder etwas abdunkeln, damit es nicht blendet.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(radius: 0.95, colors: [Color(0x00000000), Color(0x99000000)]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Gute Nacht": erscheint, wenn der Schlaf-Timer die Wiedergabe angehalten hat.
/// Abgedunkelter Bildschirm mit Frage und "Weiterschauen"/"Beenden" – für den Schlaf-Timer
/// ("Gute Nacht") und "Schaust du noch?".
class _SleepOverlay extends StatefulWidget {
  const _SleepOverlay({
    required this.onContinue,
    required this.onClose,
    required this.title,
    required this.message,
    this.icon = Icons.bedtime_rounded,
  });

  final VoidCallback onContinue;
  final VoidCallback onClose;
  final String title;
  final String message;
  final IconData icon;

  @override
  State<_SleepOverlay> createState() => _SleepOverlayState();
}

class _SleepOverlayState extends State<_SleepOverlay> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Langsam einblenden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 1600),
      child: ColoredBox(
        color: const Color(0xE6000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 64, color: const Color(0xFFFACC15)),
              const SizedBox(height: 18),
              Text(widget.title, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: tr.keepWatching, icon: Icons.play_arrow_rounded, onPressed: widget.onContinue),
                  const SizedBox(width: 12),
                  GlassButton(label: tr.closePlayer, icon: Icons.close_rounded, onPressed: widget.onClose),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({required this.icon, required this.tooltip, required this.onPressed, this.size = 30});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final bool enabled = true;

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered && widget.enabled ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
            ),
            child: AnimatedScale(
              scale: _hovered && widget.enabled ? 1.1 : 1,
              duration: const Duration(milliseconds: 150),
              child: Icon(widget.icon, size: widget.size, color: widget.enabled ? Colors.white : Colors.white38),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player, this.previewBuilder, this.chapters = const []});

  /// Startzeiten der Kapitel – werden als kleine Lücken in der Leiste gezeigt.
  final List<Duration> chapters;

  final Player player;

  /// Baut das Vorschaubild für eine Position (Trickplay), falls verfügbar.
  final Widget Function(Duration position)? previewBuilder;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  final _subs = <StreamSubscription<dynamic>>[];
  late Duration _position = widget.player.state.position;
  late Duration _duration = widget.player.state.duration;
  late Duration _buffer = widget.player.state.buffer;
  double? _dragMs;
  bool _hovered = false;

  /// Mausposition über der Leiste (0..1) für die Vorschau.
  double? _hoverFraction;

  /// Abstand der Spur zum Rand des Sliders (= Radius des Hover-Kreises).
  static const _trackInset = 16.0;

  @override
  void initState() {
    super.initState();
    final s = widget.player.stream;
    _subs
      ..add(s.position.listen((v) => setState(() => _position = v)))
      ..add(s.duration.listen((v) => setState(() => _duration = v)))
      ..add(s.buffer.listen((v) => setState(() => _buffer = v)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Legt die Trickplay-Vorschau über den Slider (beim Überfahren oder Ziehen).
  Widget _withPreview(double width, Duration? duration, Widget slider) {
    const previewWidth = 240.0;
    final builder = widget.previewBuilder;
    final trackWidth = width - _trackInset * 2;
    final fraction = _dragMs != null && duration != null && duration > Duration.zero
        ? (_dragMs! / duration.inMilliseconds).clamp(0.0, 1.0)
        : _hoverFraction;
    final show = builder != null && duration != null && fraction != null && trackWidth > 0;

    return MouseRegion(
      onHover: (e) {
        if (trackWidth <= 0) return;
        setState(() => _hoverFraction = ((e.localPosition.dx - _trackInset) / trackWidth).clamp(0.0, 1.0));
      },
      onExit: (_) => setState(() => _hoverFraction = null),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          slider,
          if (duration != null && widget.chapters.length > 1)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ChapterTicksPainter(
                    fractions: [
                      for (final c in widget.chapters)
                        if (c > Duration.zero && c < duration) c.inMilliseconds / duration.inMilliseconds,
                    ],
                    inset: _trackInset,
                  ),
                ),
              ),
            ),
          if (show)
            Positioned(
              bottom: 40,
              left: (_trackInset + fraction * trackWidth - previewWidth / 2).clamp(-72.0, width - previewWidth + 80),
              child: IgnorePointer(
                child: SizedBox(
                  width: previewWidth,
                  child: Align(alignment: Alignment.bottomCenter, child: builder(duration * fraction)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds.toDouble();
    final hasDuration = total > 0;
    final shown = _dragMs != null ? Duration(milliseconds: _dragMs!.round()) : _position;
    final value = hasDuration ? shown.inMilliseconds.toDouble().clamp(0.0, total) : 0.0;
    final buffered = hasDuration ? _buffer.inMilliseconds.toDouble().clamp(0.0, total) : 0.0;
    const timeStyle = TextStyle(fontSize: 13.5, fontFeatures: [FontFeature.tabularFigures()]);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(formatTimecode(shown), style: timeStyle)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _withPreview(
                constraints.maxWidth,
                hasDuration ? _duration : null,
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: _hovered ? 6 : 4,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                    secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.38),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    trackShape: const RoundedRectSliderTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: _hovered || _dragMs != null ? 8 : 0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value,
                    max: hasDuration ? total : 1,
                    secondaryTrackValue: buffered,
                    onChangeStart: hasDuration ? (v) => setState(() => _dragMs = v) : null,
                    onChanged: hasDuration ? (v) => setState(() => _dragMs = v) : null,
                    onChangeEnd: hasDuration
                        ? (v) {
                            widget.player.seek(Duration(milliseconds: v.round()));
                            setState(() => _dragMs = null);
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              hasDuration ? '-${formatTimecode(_duration - shown)}' : '',
              textAlign: TextAlign.right,
              style: timeStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.player, required this.onToggleMute, required this.onChanged});

  final Player player;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snap) {
        final volume = snap.data ?? 100;
        final icon = volume == 0
            ? Icons.volume_off_rounded
            : volume < 50
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerIconButton(icon: icon, tooltip: tr.mute, onPressed: onToggleMute),
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbColor: Colors.white,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                // Über 100 % (Verstärkung) färbt sich die Leiste in der Akzentfarbe.
                child: Slider(
                  value: volume.clamp(0, PlayerScreen.maxVolume),
                  max: PlayerScreen.maxVolume,
                  activeColor: volume > 100 ? AppColors.accent : Colors.white,
                  label: '${volume.round()} %',
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bildausschnitt des Players.
enum _ZoomMode { fit, fill, custom }

/// Gewählten Bildausschnitt kurz in der Bildmitte zeigen.
class _ZoomOsd extends StatelessWidget {
  const _ZoomOsd({required this.label});

  final ValueListenable<String?> label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<String?>(
        valueListenable: label,
        builder: (context, text, _) => AnimatedOpacity(
          opacity: text == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fit_screen_rounded, size: 28),
                const SizedBox(width: 12),
                Text(text ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lautstärke kurz in der Bildmitte zeigen (Mausrad, Pfeiltasten bei ausgeblendeter Leiste).
class _VolumeOsd extends StatelessWidget {
  const _VolumeOsd({required this.volume});

  final ValueListenable<double?> volume;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<double?>(
        valueListenable: volume,
        builder: (context, v, _) {
          final shown = v ?? 0;
          return AnimatedOpacity(
            opacity: v == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shown == 0
                        ? Icons.volume_off_rounded
                        : shown < 50
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: shown / PlayerScreen.maxVolume,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        color: shown > 100 ? AppColors.accent : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${shown.round()} %',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kleine Lücken in der Spulleiste an den Kapitelgrenzen.
class _ChapterTicksPainter extends CustomPainter {
  _ChapterTicksPainter({required this.fractions, required this.inset});

  final List<double> fractions;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.85);
    final width = size.width - inset * 2;
    final cy = size.height / 2;
    for (final f in fractions) {
      final x = inset + f * width;
      canvas.drawRect(Rect.fromLTWH(x - 1.5, cy - 4, 3, 8), paint);
    }
  }

  @override
  bool shouldRepaint(_ChapterTicksPainter old) => old.fractions.length != fractions.length;
}
