import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/app_shell.dart';
import '../../core/download_folder.dart';
import '../../core/downloads.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';

/// `ref.read` bzw. `container.read` – je nachdem, woher der Download kommt.
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

/// Startet Downloads mit allem, was davor zu klären ist: beim ersten Mal den
/// Ordner bestätigen, ggf. Qualität und Sprachen wählen, Platz prüfen.
/// Liefert die Anzahl neu vorgemerkter Titel (0 = abgebrochen oder schon da).
Future<int> startDownloads(
  BuildContext context,
  ProviderRead read,
  List<BaseItem> items, {
  String? mediaSourceId,
}) async {
  final manager = read(downloadsProvider.notifier);
  final fresh = items.where((i) => manager.entryFor(i.id) == null).toList();
  if (fresh.isEmpty) return 0;
  final messenger = ScaffoldMessenger.maybeOf(context);

  if (!read(settingsProvider).downloadFolderAsked) {
    if (!await showDownloadFolderDialog(context, read) || !context.mounted) return 0;
  }

  // Erster Titel mit allen Spuren (Listen liefern die nicht mit).
  var sample = fresh.first;
  if (sample.mediaSources.isEmpty) {
    try {
      sample = await read(apiProvider).getItem(sample.id);
    } catch (_) {}
  }
  if (!context.mounted) return 0;

  DownloadOptions? options = manager.defaultOptions;
  if (read(settingsProvider).downloadAskOptions) {
    options = await showDownloadOptionsDialog(context, read, sample, count: fresh.length, mediaSourceId: mediaSourceId);
    if (options == null || !context.mounted) return 0;
  }

  // Platz grob prüfen (bei Staffeln: erste Folge × Anzahl).
  final needed = manager.estimateSize(sample, options, mediaSourceId: mediaSourceId) * fresh.length;
  final free = DownloadFolder.freeBytes(manager.root.path);
  if (free != null && needed > 0 && needed > free) {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr.notEnoughSpaceTitle),
        content: Text(tr.notEnoughSpace(formatBytes(needed), formatBytes(free))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr.downloadAnyway)),
        ],
      ),
    );
    if (go != true || !context.mounted) return 0;
  }

  final added = fresh.length == 1
      ? await manager.enqueue(fresh.first, mediaSourceId: mediaSourceId, options: options).then((_) => 1)
      : await manager.enqueueAll(fresh, options: options);

  if (read(settingsProvider).downloadsUnmeteredOnly && await AppShell.isMeteredConnection()) {
    messenger?.showSnackBar(
      SnackBar(content: Text(tr.downloadWaitsForWifi), behavior: SnackBarBehavior.floating, width: 460),
    );
  }
  return added;
}

/// Ordner wählen, prüfen und speichern. Liefert `true`, wenn ein neuer Ordner gilt.
Future<bool> changeDownloadFolder(BuildContext context, ProviderRead read) async {
  final current = read(downloadsProvider.notifier).root.path;
  final picked = await getDirectoryPath(confirmButtonText: tr.chooseFolder, initialDirectory: current);
  if (picked == null || !context.mounted) return false;
  final path = DownloadFolder.fromPicked(picked);
  String? problem;
  if (DownloadFolder.isForbidden(path)) {
    problem = tr.folderNotAllowed;
  } else {
    final error = await DownloadFolder.checkWritable(path);
    if (error != null) problem = tr.folderNotWritable(error);
  }
  if (!context.mounted) return false;
  if (problem != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr.folderProblem),
        content: Text(problem!),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr.ok))],
      ),
    );
    return false;
  }
  final isDefault = path.toLowerCase() == DownloadFolder.defaultPath.toLowerCase();
  read(settingsProvider.notifier)
      .update((s) => s.copyWith(downloadFolder: () => isDefault ? null : path, downloadFolderAsked: true));
  return true;
}

/// Beim ersten Download: Ist der Standardordner recht? Liefert `false` bei "Abbrechen".
Future<bool> showDownloadFolderDialog(BuildContext context, ProviderRead read) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final path = read(downloadsProvider.notifier).root.path;
        final free = DownloadFolder.freeBytes(path);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(tr.downloadFolderQuestion),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.downloadFolderQuestionText),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(path, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (free != null)
                              Text(
                                tr.freeSpace(formatBytes(free)),
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
            TextButton.icon(
              onPressed: () async {
                if (await changeDownloadFolder(context, read)) setState(() {});
              },
              icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
              label: Text(tr.changeFolder),
            ),
            FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, true), child: Text(tr.useThisFolder)),
          ],
        );
      },
    ),
  );
  if (ok != true) return false;
  read(settingsProvider.notifier).update((s) => s.copyWith(downloadFolderAsked: true));
  return true;
}

/// Qualität, Tonspur und Untertitel für einen Download (bzw. eine Staffel) wählen.
/// [count] > 1: gilt für alle Folgen. Liefert `null` bei "Abbrechen".
Future<DownloadOptions?> showDownloadOptionsDialog(
  BuildContext context,
  ProviderRead read,
  BaseItem sample, {
  int count = 1,
  String? mediaSourceId,
}) {
  return showDialog<DownloadOptions>(
    context: context,
    builder: (context) =>
        _DownloadOptionsDialog(read: read, sample: sample, count: count, mediaSourceId: mediaSourceId),
  );
}

class _DownloadOptionsDialog extends StatefulWidget {
  const _DownloadOptionsDialog({required this.read, required this.sample, required this.count, this.mediaSourceId});

  final ProviderRead read;
  final BaseItem sample;
  final int count;

  /// Gewählte Fassung (bei mehreren Versionen) – Sprachen und Größe stammen von ihr.
  final String? mediaSourceId;

  @override
  State<_DownloadOptionsDialog> createState() => _DownloadOptionsDialogState();
}

class _DownloadOptionsDialogState extends State<_DownloadOptionsDialog> {
  late final AppSettings _settings = widget.read(settingsProvider);
  late int? _quality = _settings.downloadQuality;
  late String? _audio = _initialAudio();
  late final Set<String> _subtitles = {..._subtitleLanguages};
  bool _dontAsk = false;

  MediaSource? get _source =>
      widget.sample.mediaSources.where((s) => s.id == widget.mediaSourceId).firstOrNull ??
      widget.sample.mediaSources.firstOrNull;

  /// Sprachen (Schlüssel wie "de"), jeweils mit dem ersten Code, wie der Server ihn liefert.
  static Map<String, String> _languages(Iterable<MediaStream> streams) {
    final result = <String, String>{};
    for (final s in streams) {
      final code = s.language;
      if (code == null || code.isEmpty) continue;
      result.putIfAbsent(languageKey(code) ?? code.toLowerCase(), () => code);
    }
    return result;
  }

  Map<String, String> get _audioLanguages => _languages(_source?.embeddedStreams('Audio') ?? const []);

  static const _textCodecs = {'srt', 'subrip', 'ass', 'ssa', 'vtt', 'webvtt', 'mov_text', 'text'};

  Iterable<String> get _subtitleLanguages => _languages(
    (_source?.mediaStreams ?? const []).where(
      (s) => s.type == 'Subtitle' && _textCodecs.contains(s.codec?.toLowerCase()),
    ),
  ).values;

  String? _initialAudio() {
    final pref = _settings.audioLanguage;
    if (pref == null) return null;
    return _audioLanguages.values.where((c) => sameLanguage(c, pref)).firstOrNull;
  }

  DownloadOptions get _options => DownloadOptions(
    maxBitrate: _quality,
    audioLanguage: _audio,
    subtitleLanguages: _subtitleLanguages.length == _subtitles.length ? null : _subtitles.toList(),
  );

  @override
  Widget build(BuildContext context) {
    final manager = widget.read(downloadsProvider.notifier);
    final size = manager.estimateSize(widget.sample, _options, mediaSourceId: widget.mediaSourceId) * widget.count;
    final original = _quality == null;
    final audioLanguages = _audioLanguages;
    final subtitleLanguages = _subtitleLanguages.toList();

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.count > 1 ? tr.downloadEpisodesTitle(widget.count) : tr.downloadOptionsTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(tr.quality),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (bitrate, name) in qualityOptions)
                    ChoiceChip(
                      label: Text(name),
                      selected: _quality == bitrate,
                      onSelected: (_) => setState(() => _quality = bitrate),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                original ? tr.downloadOriginalHint : tr.downloadConvertedHint,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              if (!original && audioLanguages.length > 1) ...[
                label(tr.audio),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr.standard),
                      selected: _audio == null,
                      onSelected: (_) => setState(() => _audio = null),
                    ),
                    for (final code in audioLanguages.values)
                      ChoiceChip(
                        label: Text(languageName(code)),
                        selected: _audio == code,
                        onSelected: (_) => setState(() => _audio = code),
                      ),
                  ],
                ),
              ],
              if (!original && subtitleLanguages.isNotEmpty) ...[
                label(tr.subtitles),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in subtitleLanguages)
                      FilterChip(
                        label: Text(languageName(code)),
                        selected: _subtitles.contains(code),
                        onSelected: (on) => setState(() => on ? _subtitles.add(code) : _subtitles.remove(code)),
                      ),
                  ],
                ),
              ],
              if (size > 0) ...[
                const SizedBox(height: 16),
                Text(tr.downloadSizeAbout(formatBytes(size)), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _dontAsk,
                onChanged: (v) => setState(() => _dontAsk = v ?? false),
                title: Text(tr.downloadDontAskAgain),
                subtitle: Text(tr.downloadDontAskAgainHint, style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel)),
        FilledButton.icon(
          autofocus: true,
          onPressed: () {
            if (_dontAsk) {
              widget
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(downloadAskOptions: false, downloadQuality: () => _quality));
            }
            Navigator.pop(context, _options);
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(tr.download),
        ),
      ],
    );
  }
}
