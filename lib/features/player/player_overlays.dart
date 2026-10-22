import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/jf_image.dart';

/// Beschriftung für "… überspringen" je nach Abschnittstyp.
String _skipLabel(String type) => switch (type) {
  'Intro' => 'Intro überspringen',
  'Recap' => 'Rückblick überspringen',
  'Preview' => 'Vorschau überspringen',
  'Commercial' => 'Werbung überspringen',
  _ => 'Überspringen',
};

/// Blendet je nach Position "Intro überspringen" oder die Karte
/// "Nächste Folge" (mit Countdown) unten rechts ein.
class PlayerSkipOverlay extends StatefulWidget {
  const PlayerSkipOverlay({
    super.key,
    required this.player,
    required this.segments,
    required this.nextEpisode,
    required this.nextEpisodeImageUrl,
    required this.onSeek,
    required this.onPlayNext,
    this.controlsVisible = false,
    this.autoSkip = false,
    this.autoPlayNext = true,
  });

  /// Intro/Rückblick automatisch überspringen statt nur den Knopf zu zeigen.
  final bool autoSkip;

  /// Countdown zur nächsten Folge (sonst nur Knopf).
  final bool autoPlayNext;

  final Player player;
  final List<MediaSegment> segments;
  final BaseItem? nextEpisode;
  final String? nextEpisodeImageUrl;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayNext;

  /// Wenn die Bedienleiste sichtbar ist, rutscht das Overlay etwas höher.
  final bool controlsVisible;

  @override
  State<PlayerSkipOverlay> createState() => _PlayerSkipOverlayState();
}

class _PlayerSkipOverlayState extends State<PlayerSkipOverlay> {
  static const _nextUpLeadTime = Duration(seconds: 30);

  late StreamSubscription<Duration> _sub;
  MediaSegment? _activeSkip;
  bool _showNextUp = false;
  bool _nextUpDismissed = false;
  final _autoSkipped = <MediaSegment>{};

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.position.listen(_onPosition);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onPosition(Duration position) {
    final duration = widget.player.state.duration;

    final skip = widget.segments
        .where((s) => s.type != 'Outro' && s.type != 'Unknown' && s.contains(position))
        .firstOrNull;

    var nextUp = false;
    if (widget.nextEpisode != null && duration > Duration.zero) {
      final outro = widget.segments.where((s) => s.type == 'Outro').firstOrNull;
      final threshold = outro?.start ?? duration - _nextUpLeadTime;
      nextUp = position >= threshold && position < duration;
    }
    if (skip != null && widget.autoSkip && _autoSkipped.add(skip)) {
      widget.onSeek(skip.end);
    }

    // Zurückgespult → Karte darf wieder erscheinen.
    if (!nextUp) _nextUpDismissed = false;

    if (skip != _activeSkip || nextUp != _showNextUp) {
      setState(() {
        _activeSkip = skip;
        _showNextUp = nextUp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNext = _showNextUp && !_nextUpDismissed;
    final skip = showNext ? null : _activeSkip;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      right: 40,
      bottom: widget.controlsVisible ? 140 : 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.1, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: showNext
            ? _NextEpisodeCard(
                key: const ValueKey('next'),
                episode: widget.nextEpisode!,
                countdown: widget.autoPlayNext,
                imageUrl: widget.nextEpisodeImageUrl,
                onPlay: widget.onPlayNext,
                onDismiss: () => setState(() => _nextUpDismissed = true),
              )
            : skip != null
            ? _SkipButton(
                key: ValueKey('skip-${skip.type}'),
                label: _skipLabel(skip.type),
                onPressed: () => widget.onSeek(skip.end),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }
}

class _SkipButton extends StatefulWidget {
  const _SkipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next_rounded, color: _hovered ? AppColors.background : Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _hovered ? AppColors.background : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karte mit Vorschaubild der nächsten Folge und ablaufendem Countdown.
class _NextEpisodeCard extends StatefulWidget {
  const _NextEpisodeCard({
    super.key,
    required this.episode,
    required this.imageUrl,
    required this.onPlay,
    required this.onDismiss,
    this.countdown = true,
  });

  final bool countdown;
  final BaseItem episode;
  final String? imageUrl;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  @override
  State<_NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<_NextEpisodeCard> with SingleTickerProviderStateMixin {
  late final _countdown = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onPlay();
    });

  @override
  void initState() {
    super.initState();
    if (widget.countdown) _countdown.forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    return Container(
      width: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onPlay,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    JfImage(url: widget.imageUrl),
                    const ColoredBox(color: Color(0x33000000)),
                    Center(
                      child: AnimatedBuilder(
                        animation: _countdown,
                        builder: (context, _) => SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _countdown.value,
                                strokeWidth: 3,
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                              const Icon(Icons.play_arrow_rounded, size: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NÄCHSTE FOLGE',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [?ep.episodeLabel, ep.name].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _countdown.stop();
                    widget.onDismiss();
                  },
                  child: const Text('Abspann ansehen'),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: widget.onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Jetzt ansehen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vorschaubild aus einer Trickplay-Kachel für eine Position.
class TrickplayPreview extends StatelessWidget {
  const TrickplayPreview({
    super.key,
    required this.info,
    required this.position,
    required this.tileUrl,
    required this.headers,
    this.width = 240,
    this.title,
  });

  /// Kapitelname über der Zeit (optional).
  final String? title;

  final TrickplayInfo info;
  final Duration position;
  final String Function(int tileIndex) tileUrl;
  final Map<String, String> headers;
  final double width;

  @override
  Widget build(BuildContext context) {
    final perTile = info.tileWidth * info.tileHeight;
    final maxIndex = info.thumbnailCount > 0 ? info.thumbnailCount - 1 : 0;
    final n = (position.inMilliseconds ~/ info.interval.inMilliseconds).clamp(0, maxIndex);
    final tile = n ~/ perTile;
    final inTile = n % perTile;
    final col = inTile % info.tileWidth;
    final row = inTile ~/ info.tileWidth;

    final height = width * info.height / info.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(-col * width, -row * height),
              child: Image(
                image: NetworkImage(tileUrl(tile), headers: headers),
                width: width * info.tileWidth,
                height: height * info.tileHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SeekTimeBubble(position: position, title: title),
      ],
    );
  }
}

/// Zeit (und ggf. Kapitelname) über der Spulleiste.
class SeekTimeBubble extends StatelessWidget {
  const SeekTimeBubble({super.key, required this.position, this.title});

  final Duration position;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          Text(
            formatTimecode(position),
            style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// Panel "Wiedergabe": Geschwindigkeit, Qualität und Ton-/Untertitelversatz.
class PlaybackPanel extends StatelessWidget {
  const PlaybackPanel({
    super.key,
    required this.rate,
    required this.onRate,
    required this.maxBitrate,
    required this.onQuality,
    required this.audioDelay,
    required this.subtitleDelay,
    required this.onAudioDelay,
    required this.onSubtitleDelay,
  });

  static const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final double rate;
  final ValueChanged<double> onRate;
  final int? maxBitrate;
  final ValueChanged<int?> onQuality;
  final double audioDelay;
  final double subtitleDelay;
  final ValueChanged<double> onAudioDelay;
  final ValueChanged<double> onSubtitleDelay;

  @override
  Widget build(BuildContext context) {
    // Eigene Ebene: Ändert sich das Panel, muss das Video nicht neu gezeichnet werden.
    return RepaintBoundary(child: _buildPanel(context));
  }

  Widget _buildPanel(BuildContext context) {
    return Container(
      width: 680,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF2101219),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle('Geschwindigkeit'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in rates)
                      _Chip(
                        label: '${r.toString().replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')}×',
                        selected: (r - rate).abs() < 0.01,
                        onTap: () => onRate(r),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const _PanelTitle('Synchronisation'),
                _DelayRow(label: 'Ton', value: audioDelay, onChanged: onAudioDelay),
                const SizedBox(height: 8),
                _DelayRow(label: 'Untertitel', value: subtitleDelay, onChanged: onSubtitleDelay),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle('Qualität'),
                for (final q in qualityOptions)
                  _SelectRow(
                    label: q.$2,
                    hint: q.$1 == null ? 'ohne Umrechnung' : null,
                    selected: q.$1 == maxBitrate,
                    onTap: () => onQuality(q.$1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.background : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectRow extends StatefulWidget {
  const _SelectRow({required this.label, required this.selected, required this.onTap, this.hint});

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SelectRow> createState() => _SelectRowState();
}

class _SelectRowState extends State<_SelectRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: widget.selected ? const Icon(Icons.check_rounded, size: 19, color: AppColors.accent) : null,
              ),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected || _hovered ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (widget.hint != null) ...[
                const SizedBox(width: 8),
                Text(widget.hint!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DelayRow extends StatelessWidget {
  const _DelayRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = '${value > 0 ? '+' : ''}${value.toStringAsFixed(1).replaceAll('.', ',')} s';
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        _RoundButton(icon: Icons.remove_rounded, onTap: () => onChanged(value - 0.1)),
        SizedBox(
          width: 70,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
        _RoundButton(icon: Icons.add_rounded, onTap: () => onChanged(value + 0.1)),
        if (value != 0) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Zurücksetzen',
            child: _RoundButton(icon: Icons.restart_alt_rounded, onTap: () => onChanged(0)),
          ),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
