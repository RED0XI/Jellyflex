part of 'player_screen.dart';

// Panel "Audio & Untertitel" mit den Spurlisten.

typedef _TrackEntry = ({String id, String label});

/// Netflix-artiges Panel mit zwei Spalten: Audio | Untertitel.
/// Aktualisiert sich selbst, sobald mpv neue Spuren oder eine andere Auswahl meldet.
class _TracksPanel extends StatefulWidget {
  const _TracksPanel({
    super.key,
    required this.player,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.audioEntries,
    required this.subtitleEntries,
    required this.onAudio,
    required this.onSubtitle,
    required this.onClose,
  });

  final Player player;
  final List<_TrackEntry> Function() audioEntries;
  final List<_TrackEntry> Function() subtitleEntries;
  final String? Function() selectedAudio;
  final String? Function() selectedSubtitle;
  final ValueChanged<String> onAudio;
  final ValueChanged<String> onSubtitle;
  final VoidCallback onClose;

  @override
  State<_TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<_TracksPanel> {
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(widget.player.stream.tracks.listen((_) => setState(() {})))
      ..add(widget.player.stream.track.listen((_) => setState(() {})));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // So hoch wie die längere Spalte (höchstens 380), der Trennstrich reicht durch.
    return Container(
      width: 640,
      constraints: const BoxConstraints(maxHeight: 380),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xF2101219),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _TrackColumn(
                title: tr.audio,
                entries: widget.audioEntries(),
                selectedId: widget.selectedAudio(),
                emptyText: tr.noAudioTracks,
                onSelect: widget.onAudio,
              ),
            ),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),
            Expanded(
              child: _TrackColumn(
                title: tr.subtitles,
                entries: widget.subtitleEntries(),
                selectedId: widget.selectedSubtitle(),
                emptyText: tr.noSubtitles,
                onSelect: widget.onSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackColumn extends StatelessWidget {
  const _TrackColumn({
    required this.title,
    required this.entries,
    required this.selectedId,
    required this.emptyText,
    required this.onSelect,
  });

  final String title;
  final List<_TrackEntry> entries;
  final String? selectedId;
  final String emptyText;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        // "Aus" und "Untertitel suchen …" zählen nicht als Spur.
        if (!entries.any((e) => e.id != 'no' && e.id != 'search'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(emptyText, style: TextStyle(color: AppColors.textMuted)),
          ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final e in entries)
                  _TrackRow(label: e.label, selected: e.id == selectedId, onTap: () => onSelect(e.id)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatefulWidget {
  const _TrackRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: widget.selected ? Icon(Icons.check_rounded, size: 20, color: AppColors.accent) : null,
            ),
            Expanded(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected || hovered ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
