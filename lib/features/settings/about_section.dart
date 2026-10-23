import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads.dart';
import '../../core/error_report.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../core/update_check.dart';
import '../../core/version.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../live_handler.dart';

/// Neue Version gefunden? Kurze Meldung mit "Ansehen" (öffnet die Versionsseite).
void showUpdateNotice(String version) {
  appMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(tr.updateAvailable(version)),
      behavior: SnackBarBehavior.floating,
      width: 480,
      duration: const Duration(seconds: 10),
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(label: tr.show, onPressed: UpdateCheck.openReleasesPage),
    ),
  );
}

/// Update-Prüfung von Hand ("Jetzt prüfen").
Future<void> checkForUpdateNow(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final latest = await UpdateCheck.latestVersion();
  if (latest != null && UpdateCheck.isNewer(latest)) {
    showUpdateNotice(latest);
    return;
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text(latest == null ? tr.updateCheckFailed : tr.upToDate),
      behavior: SnackBarBehavior.floating,
      width: 420,
    ),
  );
}

/// Fehlerbericht zeigen: der Benutzer sieht genau, was drinsteht, und kann
/// ihn kopieren oder als Datei speichern. Verschickt wird nichts.
Future<void> showErrorReport(BuildContext context, WidgetRef ref) {
  final report = buildErrorReport(
    settings: ref.read(settingsProvider),
    session: ref.read(sessionProvider).value,
    downloads: ref.read(myDownloadsProvider),
  );
  return showDialog<void>(
    context: context,
    builder: (context) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      return AlertDialog(
        title: Text(tr.errorReport),
        content: SizedBox(
          width: 720,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.errorReportPrivacy, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    // Volle Breite, auch wenn die Zeilen kurz sind.
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        report,
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.close)),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              messenger?.showSnackBar(
                SnackBar(content: Text(tr.copied), behavior: SnackBarBehavior.floating, width: 420),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr.copy),
          ),
          FilledButton.icon(
            onPressed: () async {
              final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(RegExp('[-:T]'), '');
              final location = await getSaveLocation(
                suggestedName: 'jellyflex-bericht-$stamp.txt',
                acceptedTypeGroups: const [
                  XTypeGroup(label: 'Text', extensions: ['txt']),
                ],
              );
              if (location == null) return;
              final file = File(location.path);
              await file.writeAsString(report);
              if (context.mounted) Navigator.pop(context);
              // Im Explorer zeigen.
              await Process.run('explorer.exe', ['/select,${file.path}']);
            },
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(tr.saveAs),
          ),
        ],
      );
    },
  );
}

/// Zeile "Über Jellyflex": Version, Update-Prüfung (freiwillig), Fehlerbericht.
class AboutRows extends ConsumerWidget {
  const AboutRows({super.key, required this.row, required this.toggle});

  /// Zeilen-Bausteine der Einstellungsseite (damit alles gleich aussieht).
  final Widget Function({required String title, String? subtitle, required Widget trailing}) row;
  final Widget Function({required bool value, required ValueChanged<bool> onChanged}) toggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        row(
          title: tr.appVersionLabel,
          trailing: Text(
            appVersion,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        row(
          title: tr.updateCheck,
          subtitle: tr.updateCheckHint,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => checkForUpdateNow(context), child: Text(tr.checkNow)),
              const SizedBox(width: 6),
              toggle(
                value: s.updateCheck,
                onChanged: (v) => ctrl.update((s) => s.copyWith(updateCheck: v)),
              ),
            ],
          ),
        ),
        row(
          title: tr.errorReport,
          subtitle: tr.errorReportHint,
          trailing: TextButton.icon(
            onPressed: () => showErrorReport(context, ref),
            icon: const Icon(Icons.bug_report_outlined, size: 18),
            label: Text(tr.create),
          ),
        ),
      ],
    );
  }
}
