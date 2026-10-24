import 'package:flutter/material.dart';

import '../core/update_check.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// "Was ist neu" nach einem Update: die Neuigkeiten seit der zuletzt gesehenen Version.
Future<void> showWhatsNew(BuildContext context, List<({String version, List<String> items})> changes) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(tr.whatsNewTitle(changes.first.version))),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, change) in changes.indexed) ...[
                // Bei mehreren übersprungenen Versionen: je Version eine Überschrift.
                if (changes.length > 1)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 14, bottom: 6),
                    child: Text(
                      tr.versionLabelShort(change.version),
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                for (final item in change.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 10),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          ),
                        ),
                        Expanded(child: Text(item, style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: UpdateCheck.openReleasesPage, child: Text(tr.allReleaseNotes)),
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(context), child: Text(tr.gotIt)),
      ],
    ),
  );
}
