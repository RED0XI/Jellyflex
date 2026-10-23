import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/focusable.dart';

/// Überlagert eine Karte im Auswahlmodus: Klick wählt an/ab, Haken oben links.
class SelectableOverlay extends StatelessWidget {
  const SelectableOverlay({super.key, required this.item, required this.selected, required this.onToggle});

  final BaseItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onToggle,
      semanticLabel: '${item.name}, ${selected ? tr.selected : tr.notSelected}',
      builder: (context, hovered) => Stack(
        children: [
          // Nur der Bildbereich (2:3) wird abgedunkelt bzw. umrahmt.
          LayoutBuilder(
            builder: (context, box) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: box.maxWidth * 1.5,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.accent : (hovered ? Colors.white70 : Colors.transparent),
                  width: selected ? 3 : 2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.black54,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Schwebende Leiste mit den Aktionen für alle ausgewählten Titel.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.busy,
    required this.onWatched,
    required this.onUnwatched,
    required this.onFavorite,
    required this.onDownload,
    required this.onSelectAll,
    required this.onClose,
  });

  final int count;
  final bool busy;
  final VoidCallback onWatched;
  final VoidCallback onUnwatched;
  final VoidCallback onFavorite;

  /// `null`, wenn nichts Herunterladbares ausgewählt ist.
  final VoidCallback? onDownload;
  final VoidCallback onSelectAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0 && !busy;
    Widget action(IconData icon, String label, VoidCallback? onTap) =>
        TextButton.icon(onPressed: enabled ? onTap : null, icon: Icon(icon, size: 19), label: Text(label));
    return Material(
      color: AppColors.surfaceHigh,
      elevation: 10,
      shadowColor: Colors.black54,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: busy ? const CircularProgressIndicator(strokeWidth: 2.2) : const Icon(Icons.checklist_rounded),
            ),
            const SizedBox(width: 10),
            Text(tr.selectedCount(count), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 14),
            action(Icons.check_rounded, tr.watched, onWatched),
            action(Icons.remove_done_rounded, tr.unwatched, onUnwatched),
            action(Icons.favorite_border_rounded, tr.favorite, onFavorite),
            action(Icons.download_rounded, tr.download, onDownload),
            const SizedBox(width: 6),
            TextButton(onPressed: busy ? null : onSelectAll, child: Text(tr.selectAll)),
            IconButton(tooltip: tr.endSelection, onPressed: onClose, icon: const Icon(Icons.close_rounded)),
          ],
        ),
      ),
    );
  }
}
