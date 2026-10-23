import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Übersicht aller Tastenkürzel (Taste ?) – App, Player und Controller.
Future<void> showShortcutSheet(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 620),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.keyboard_rounded),
                const SizedBox(width: 12),
                Text(tr.shortcuts, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: tr.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 40,
                  runSpacing: 22,
                  children: [
                    _Group(tr.shortcutsEverywhere, [
                      ('Ctrl + F', tr.search),
                      ('Ctrl + ,', tr.settings),
                      ('F11', tr.fullscreen.replaceAll(' (F)', '')),
                      ('Esc  ·  Alt + ←', tr.back),
                      ('← ↑ → ↓', tr.shortcutMoveFocus),
                      ('Enter', tr.shortcutOpen),
                      ('?', tr.shortcuts),
                    ]),
                    _Group(tr.shortcutsPlayer, [
                      (tr.keySpace, '${tr.play} / ${tr.pause}'),
                      ('K', '${tr.play} / ${tr.pause}'),
                      ('← / J  ·  → / L', tr.shortcutSeek),
                      ('↑ ↓', tr.shortcutVolume),
                      ('F', tr.fullscreen.replaceAll(' (F)', '')),
                      ('M', tr.mute.replaceAll(' (M)', '')),
                      ('P', tr.miniPlayer.replaceAll(' (P)', '')),
                      ('C', tr.chapters),
                      ('I', tr.statsTitle.replaceAll(' (I)', '')),
                      ('S', tr.shortcutScreenshot),
                      ('Esc', tr.closePlayer),
                    ]),
                    _Group(tr.shortcutsController, [
                      ('A', tr.shortcutOpen),
                      ('B', tr.back),
                      ('Y', tr.search),
                      ('X', tr.shortcutMenu),
                      ('Start', '${tr.play} / ${tr.pause}'),
                      ('D-Pad / Stick', tr.shortcutMoveFocus),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 370,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          for (final (keys, action) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 130),
                    margin: const EdgeInsets.only(right: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          keys,
                          style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(action, style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
