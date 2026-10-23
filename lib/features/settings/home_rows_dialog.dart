import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/home_rows.dart';
import '../../core/settings.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';

/// Startseite anpassen: Reihen per Ziehen (oder Pfeilen) umsortieren und ein-/ausblenden.
/// Jede Änderung gilt sofort.
Future<void> showHomeRowsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _HomeRowsDialog());

class _HomeRowsDialog extends ConsumerWidget {
  const _HomeRowsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = HomeRows.parse(ref.watch(settingsProvider.select((s) => s.homeRows)));
    final ctrl = ref.read(settingsProvider.notifier);
    void save(List<({String id, bool visible})> next) =>
        ctrl.update((s) => s.copyWith(homeRows: HomeRows.encode(next)));

    void move(int from, int to) {
      final next = [...rows];
      final row = next.removeAt(from);
      next.insert(to.clamp(0, next.length), row);
      save(next);
    }

    return AlertDialog(
      title: Text(tr.homeRows),
      content: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.homeRowsHint, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: rows.length,
                onReorderItem: move,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return Material(
                    key: ValueKey(row.id),
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 4, right: 0),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator_rounded)),
                        ),
                      ),
                      title: Text(
                        tr.homeRowName(row.id),
                        style: TextStyle(color: row.visible ? AppColors.textPrimary : AppColors.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Für Tastatur/Controller: hoch/runter statt Ziehen.
                          IconButton(
                            tooltip: tr.moveUp,
                            onPressed: i == 0 ? null : () => move(i, i - 1),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          ),
                          IconButton(
                            tooltip: tr.moveDown,
                            onPressed: i == rows.length - 1 ? null : () => move(i, i + 1),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          Switch(
                            value: row.visible,
                            onChanged: (v) => save([for (final r in rows) r.id == row.id ? (id: r.id, visible: v) : r]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => ctrl.update((s) => s.copyWith(homeRows: HomeRows.all)),
          child: Text(tr.resetToDefault),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr.done)),
      ],
    );
  }
}
