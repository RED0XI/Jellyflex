part of 'player_screen.dart';

// Panel "Untertitel anpassen": Stil ändern und im laufenden Bild sehen.

/// Ändert den Untertitel-Stil live – für alle Titel oder nur für die Bibliothek dieses Titels.
class _SubtitleStylePanel extends ConsumerStatefulWidget {
  const _SubtitleStylePanel({super.key, required this.libraryId, required this.maxHeight});

  /// Bibliothek des laufenden Titels (`null` = unbekannt, dann gibt es nur "Überall").
  final String? libraryId;
  final double maxHeight;

  @override
  ConsumerState<_SubtitleStylePanel> createState() => _SubtitleStylePanelState();
}

class _SubtitleStylePanelState extends ConsumerState<_SubtitleStylePanel> {
  /// Ändert gerade die Regeln dieser Bibliothek (sonst die allgemeinen).
  late bool _forLibrary = widget.libraryId != null && ref.read(settingsProvider).hasLibraryStyle(widget.libraryId);

  void _change(SubtitleStyle style) {
    final library = widget.libraryId;
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => _forLibrary && library != null
              ? s.withLibrarySubtitles(library, LibrarySubtitles(style: style, language: s.libraryLanguage(library)))
              : s.copyWith(subtitleStyle: style),
        );
  }

  void _resetLibrary() {
    final library = widget.libraryId;
    if (library == null) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.withLibrarySubtitles(library, LibrarySubtitles(language: s.libraryLanguage(library))));
    setState(() => _forLibrary = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final library = widget.libraryId;
    final style = _forLibrary ? settings.subtitleStyleFor(library) : settings.subtitleStyle;
    final libraryName = ref.watch(libraryViewsProvider).value?.where((l) => l.id == library).firstOrNull?.name;

    return Container(
      width: 460,
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xF2101219),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.subtitleAppearance, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (library != null && libraryName != null) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(tr.subtitleScopeAll)),
                  ButtonSegment(value: true, label: Text(libraryName, overflow: TextOverflow.ellipsis)),
                ],
                selected: {_forLibrary},
                onSelectionChanged: (v) => setState(() => _forLibrary = v.first),
              ),
            ],
            const SizedBox(height: 14),
            SubtitleStyleEditor(style: style, onChanged: _change),
            if (_forLibrary && settings.hasLibraryStyle(library))
              TextButton.icon(
                onPressed: _resetLibrary,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(tr.subtitleUseGeneral),
              ),
          ],
        ),
      ),
    );
  }
}
