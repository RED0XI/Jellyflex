import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/downloads.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../../l10n/strings.dart';

/// Alle Downloads: laufende mit Fortschritt, fertige zum Offline-Schauen.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(myDownloadsProvider);
    final manager = ref.read(downloadsProvider.notifier);
    final active = entries.where((e) => !e.isDone).toList();
    final done = entries.where((e) => e.isDone).toList();

    return Scaffold(
      body: Stack(
        children: [
          SmoothScroll(
            controller: _scroll,
            builder: (context, physics) => CustomScrollView(
              controller: _scroll,
              physics: physics,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.downloads,
                              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                            ),
                            Text(
                              entries.isEmpty
                                  ? tr.savedForOffline
                                  : tr.downloadsSummary(done.length, formatBytes(manager.usedBytes)),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GlassButton(
                          label: tr.openFolder,
                          icon: Icons.folder_open_rounded,
                          onPressed: () {
                            manager.root.createSync(recursive: true);
                            Process.run('explorer', [manager.root.path]);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.download_for_offline_outlined, size: 56, color: AppColors.textMuted),
                          SizedBox(height: 14),
                          Text(tr.noDownloadsYet, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(tr.noDownloadsHint, style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                if (active.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: manager.waitingForUnmetered,
                      builder: (context, waiting, _) => waiting ? const _WaitingForWifi() : const SizedBox.shrink(),
                    ),
                  ),
                if (active.isNotEmpty) ...[
                  _SectionTitle(tr.downloading),
                  SliverList.list(children: [for (final e in active) _ActiveRow(entry: e)]),
                ],
                if (done.isNotEmpty) ...[
                  _SectionTitle(tr.readyOffline),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        crossAxisSpacing: 22,
                        mainAxisSpacing: 26,
                        childAspectRatio: 168 / 304,
                      ),
                      itemCount: done.length,
                      itemBuilder: (context, i) => _DoneCard(entry: done[i]),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 72)),
              ],
            ),
          ),
          TopScrim(scroll: _scroll),
        ],
      ),
    );
  }
}

/// Hinweis: Downloads warten, weil die Verbindung getaktet ist (mobile Daten, Hotspot).
class _WaitingForWifi extends ConsumerWidget {
  const _WaitingForWifi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, color: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.waitingForWifi, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(tr.waitingForWifiHint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadsUnmeteredOnly: false));
              ref.read(downloadsProvider.notifier).recheckNetwork();
            },
            child: Text(tr.allowMetered),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 12, kPageGutter, 14),
      child: Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
    ),
  );
}

/// Lokales Poster (aus dem Download-Ordner) mit Platzhalter.
class _LocalPoster extends StatelessWidget {
  const _LocalPoster({required this.entry});

  final DownloadEntry entry;

  @override
  Widget build(BuildContext context) {
    final file = File(entry.posterPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: AppColors.surfaceHigh,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : Center(child: Icon(Icons.movie_outlined, color: AppColors.textMuted)),
      ),
    );
  }
}

/// Fragt nach, bevor ein Download (samt Datei) gelöscht wird.
Future<bool> confirmRemoveDownload(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr.deleteDownloadQuestion),
      content: Text(tr.deleteDownloadText(name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, true), child: Text(tr.delete)),
      ],
    ),
  );
  return ok ?? false;
}

/// Fragt nach, bevor ein laufender Download abgebrochen wird.
Future<bool> confirmCancelDownload(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr.cancelDownloadQuestion),
      content: Text(tr.cancelDownloadText(name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.keepDownloading)),
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, true), child: Text(tr.cancelDownload)),
      ],
    ),
  );
  return ok ?? false;
}

/// Spielt einen fertigen Download ab – an der zuletzt geschauten Stelle.
void playDownload(BuildContext context, DownloadEntry entry) {
  final ticks = entry.loadItem()?.userData.playbackPositionTicks ?? entry.positionTicks;
  context.push('/play/${entry.itemId}${ticks > 0 ? '?start=$ticks' : ''}');
}

String _title(DownloadEntry e) => e.seriesName ?? e.name;
String? _subtitle(DownloadEntry e) => e.seriesName != null ? [?e.episodeLabel, e.name].join(' · ') : null;

class _ActiveRow extends ConsumerWidget {
  const _ActiveRow({required this.entry});

  final DownloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadsProvider.notifier);
    final status = switch (entry.status) {
      DownloadStatus.queued => manager.waitingForUnmetered.value ? tr.waitingForWifi : tr.waiting,
      DownloadStatus.downloading =>
        entry.total > 0 ? tr.receivedOf(formatBytes(entry.received), formatBytes(entry.total)) : tr.starting,
      DownloadStatus.paused => tr.paused(entry.error),
      DownloadStatus.failed => tr.failed(entry.error),
      DownloadStatus.done => tr.done,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          SizedBox(width: 54, height: 80, child: _LocalPoster(entry: entry)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(entry), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (_subtitle(entry) != null) Text(_subtitle(entry)!, style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: entry.status == DownloadStatus.downloading && entry.total > 0 ? entry.progress : null,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    color: entry.status == DownloadStatus.failed ? const Color(0xFFFF6B6B) : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(status, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (entry.status == DownloadStatus.downloading || entry.status == DownloadStatus.queued)
            CircleIconButton(
              icon: Icons.pause_rounded,
              tooltip: tr.pause,
              size: 44,
              onPressed: () => manager.pause(entry.itemId),
            )
          else
            CircleIconButton(
              icon: entry.status == DownloadStatus.failed ? Icons.refresh_rounded : Icons.play_arrow_rounded,
              tooltip: entry.status == DownloadStatus.failed ? tr.retry : tr.resume,
              size: 44,
              onPressed: () => manager.resume(entry.itemId),
            ),
          const SizedBox(width: 8),
          CircleIconButton(
            icon: Icons.close_rounded,
            tooltip: tr.cancelAndDelete,
            size: 44,
            onPressed: () async {
              if (await confirmRemoveDownload(context, _title(entry))) manager.remove(entry.itemId);
            },
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends ConsumerWidget {
  const _DoneCard({required this.entry});

  final DownloadEntry entry;

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 'play',
          child: Row(children: [Icon(Icons.play_arrow_rounded, size: 20), SizedBox(width: 12), Text(tr.play)]),
        ),
        PopupMenuItem(
          value: 'details',
          child: Row(children: [Icon(Icons.info_outline_rounded, size: 20), SizedBox(width: 12), Text(tr.details)]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [Icon(Icons.delete_outline_rounded, size: 20), SizedBox(width: 12), Text(tr.deleteDownload)],
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'play':
        playDownload(context, entry);
      case 'details':
        context.push('/item/${entry.itemId}');
      case 'delete':
        if (await confirmRemoveDownload(context, _title(entry))) {
          ref.read(downloadsProvider.notifier).remove(entry.itemId);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = entry.loadItem();
    final runtime = item?.runTimeTicks ?? 0;
    final position = item?.userData.playbackPositionTicks ?? 0;
    final watched = runtime > 0 && position > 0 ? (position / runtime).clamp(0.0, 1.0) : 0.0;
    final played = item?.userData.played ?? false;
    return Focusable(
      onTap: () => playDownload(context, entry),
      onSecondaryTap: (pos) => _menu(context, ref, pos),
      builder: (context, hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedScale(
              scale: hovered ? 1.05 : 1,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _LocalPoster(entry: entry),
                  AnimatedOpacity(
                    opacity: hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, size: 56),
                    ),
                  ),
                  if (entry.auto)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: Text(tr.smartBadge, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      played ? Icons.check_circle_rounded : Icons.download_done_rounded,
                      size: 20,
                      color: AppColors.accentAlt,
                    ),
                  ),
                  if (watched > 0)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: watched,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _title(entry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            _subtitle(entry) ??
                [formatBytes(entry.total), if (entry.converted) qualityLabel(entry.maxBitrate)].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
