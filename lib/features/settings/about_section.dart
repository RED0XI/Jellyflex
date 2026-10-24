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
import '../../core/platform/app_paths.dart';

void _notice(String text, {required String action, required VoidCallback onAction}) {
  appMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      width: 520,
      duration: const Duration(seconds: 15),
      action: SnackBarAction(label: action, onPressed: onAction),
    ),
  );
}

/// Neue Version gefunden. [automatic]: im Hintergrund laden und prüfen, dann
/// "Jetzt neu starten" anbieten – sonst wird beim Beenden installiert. Ohne
/// [automatic]: Hinweis mit "Aktualisieren" (lädt, prüft, installiert und startet neu).
/// [dialogContext] liefert einen Kontext unterhalb des Navigators.
Future<void> offerUpdate(
  UpdateRelease release,
  BuildContext? Function() dialogContext, {
  required bool automatic,
}) async {
  if (!release.canInstall) {
    // Ohne Installer/Signatur im Release: nur auf die Versionsseite verweisen.
    _notice(tr.updateAvailable(release.version), action: tr.updateReleasePage, onAction: UpdateCheck.openReleasesPage);
    return;
  }
  if (automatic) {
    final file = await UpdateCheck.downloadVerified(release);
    if (file != null) {
      await UpdateCheck.installOnExit(file);
      _notice(tr.updateReady(release.version), action: tr.restartNow, onAction: () => UpdateCheck.runInstaller(file));
      return;
    }
    // Laden/Prüfen klappte nicht – wie ohne Automatik anbieten.
  }
  _notice(
    tr.updateAvailable(release.version),
    action: tr.update,
    onAction: () {
      final context = dialogContext();
      if (context == null) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(release: release),
      );
    },
  );
}

/// Update läuft: laden und prüfen (mit Fortschritt), dann still installieren –
/// Jellyflex startet danach von selbst neu. Klappt etwas nicht: Versionsseite.
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});

  final UpdateRelease release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _failed = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _install();
  }

  Future<void> _install() async {
    final file = await UpdateCheck.downloadVerified(
      widget.release,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (file == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _installing = true);
    // Kurz zeigen, was passiert, dann beendet sich die App für den Installer.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await UpdateCheck.runInstaller(file);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr.updateToVersion(widget.release.version)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_failed)
              Text(tr.updateVerifyFailed, style: const TextStyle(color: Color(0xFFFF6B6B)))
            else ...[
              Text(_installing ? tr.updateInstalling : tr.updateDownloading),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _installing ? null : _progress),
              const SizedBox(height: 12),
              Text(tr.updateVerifiedHint, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        if (_failed) ...[
          TextButton(onPressed: UpdateCheck.openReleasesPage, child: Text(tr.updateReleasePage)),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr.close)),
        ],
      ],
    );
  }
}

/// Update-Prüfung von Hand ("Jetzt prüfen").
Future<void> checkForUpdateNow(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final latest = await UpdateCheck.latestRelease();
  if (latest != null && UpdateCheck.isNewer(latest.version)) {
    await offerUpdate(latest, () => context.mounted ? context : null, automatic: false);
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
              // Im Explorer bzw. Finder zeigen.
              await AppPaths.reveal(file.path);
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
        if (s.updateCheck)
          row(
            title: tr.autoUpdate,
            subtitle: tr.autoUpdateHint,
            trailing: toggle(
              value: s.autoUpdate,
              onChanged: (v) => ctrl.update((s) => s.copyWith(autoUpdate: v)),
            ),
          ),
        row(
          title: tr.licenseTitle,
          subtitle: tr.licenseHint,
          trailing: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Jellyflex',
              applicationVersion: appVersion,
              applicationLegalese: tr.licenseLegalese,
            ),
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text(tr.licenses),
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
