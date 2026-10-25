import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/jellyfin_api.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/states.dart';
import '../../l10n/strings.dart';

/// Untertitel über den Server suchen und laden (Jellyfin fragt dafür seine
/// Untertitel-Plugins, z. B. OpenSubtitles – die App selbst spricht mit niemand anderem).
/// Ergebnis: `true`, wenn ein Untertitel geladen wurde.
Future<bool> showSubtitleSearchDialog(BuildContext context, BaseItem item) async {
  final loaded = await showDialog<bool>(
    context: context,
    builder: (context) => _SubtitleSearchDialog(item: item),
  );
  return loaded ?? false;
}

/// Merkmale der Untertitel einer Fassung – zum Erkennen eines neu dazugekommenen
/// (unabhängig davon, wie der Server die Spuren danach nummeriert).
Set<String> subtitleKeys(MediaSource source) => {for (final s in source.subtitleStreams) _subtitleKey(s)};

String _subtitleKey(MediaStream s) => [
  s.isExternal,
  s.raw['Path'] ?? '',
  s.language ?? '',
  s.codec ?? '',
  s.title ?? '',
  if (!s.isExternal) s.index,
].join('|');

/// Wartet, bis der Server einen geladenen Untertitel eingebunden hat. Jellyfin speichert die
/// Datei sofort, nimmt sie aber erst über seine Aktualisierungs-Warteschlange in den Titel auf –
/// auf einem vollen Server dauert das. Ergebnis: Fassung und neue Spur, oder `null` nach [timeout].
Future<(MediaSource, MediaStream)?> waitForNewSubtitle(
  JellyfinApi api,
  String itemId,
  String sourceId,
  Set<String> before, {
  Duration timeout = const Duration(seconds: 120),
  bool Function()? cancelled,
}) async {
  final end = DateTime.now().add(timeout);
  var delay = const Duration(seconds: 1);
  while (DateTime.now().isBefore(end) && !(cancelled?.call() ?? false)) {
    await Future<void>.delayed(delay);
    if (delay < const Duration(seconds: 4)) delay *= 2;
    if (cancelled?.call() ?? false) return null;
    try {
      final item = await api.getItem(itemId);
      final source = item.mediaSources.where((s) => s.id == sourceId).firstOrNull ?? item.mediaSources.firstOrNull;
      final added = source?.subtitleStreams.where((s) => !before.contains(_subtitleKey(s))).firstOrNull;
      if (source != null && added != null) return (source, added);
    } catch (_) {
      // Kurz nicht erreichbar – weiter versuchen.
    }
  }
  return null;
}

/// Sprache, mit der die Suche beginnt: bevorzugte Untertitel, sonst die Sprache der App.
String initialSubtitleSearchLanguage(AppSettings settings) {
  final pref = settings.subtitleLanguage;
  if (pref != null && pref != subtitlesOff && settingsLanguages.contains(pref)) return pref;
  return switch (settings.language) {
    AppLanguage.de => 'ger',
    AppLanguage.fr => 'fre',
    AppLanguage.es => 'spa',
    AppLanguage.tr => 'tur',
    AppLanguage.en => 'eng',
  };
}

class _SubtitleSearchDialog extends ConsumerStatefulWidget {
  const _SubtitleSearchDialog({required this.item});

  final BaseItem item;

  @override
  ConsumerState<_SubtitleSearchDialog> createState() => _SubtitleSearchDialogState();
}

class _SubtitleSearchDialogState extends ConsumerState<_SubtitleSearchDialog> {
  late String _language = initialSubtitleSearchLanguage(ref.read(settingsProvider));
  late Future<List<RemoteSubtitle>> _results = _search();
  String? _loadingId;
  String? _error;

  Future<List<RemoteSubtitle>> _search() async {
    final results = await ref.read(apiProvider).searchRemoteSubtitles(widget.item.id, _language);
    // Genau passende (Hash) zuerst, dann nach Beliebtheit.
    return results..sort((a, b) {
      final hash = (b.hashMatch ? 1 : 0) - (a.hashMatch ? 1 : 0);
      if (hash != 0) return hash;
      return (b.downloads ?? 0).compareTo(a.downloads ?? 0);
    });
  }

  void _setLanguage(String language) => setState(() {
    _language = language;
    _error = null;
    _results = _search();
  });

  Future<void> _download(RemoteSubtitle subtitle) async {
    setState(() {
      _loadingId = subtitle.id;
      _error = null;
    });
    try {
      await ref.read(apiProvider).downloadRemoteSubtitle(widget.item.id, subtitle.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingId = null;
          _error = _message(e);
        });
      }
    }
  }

  static String _message(Object e) => switch (e) {
    DioException(response: Response(statusCode: 401 || 403)) => tr.subtitleSearchNotAllowed,
    _ => tr.didNotWork,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.subtitleSearchTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.isEpisode
                              ? '${widget.item.seriesName ?? ''} · ${widget.item.episodeLabel ?? ''} · ${widget.item.name}'
                              : widget.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr.close,
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
              child: Row(
                children: [
                  Text(tr.language, style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 14),
                  DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: AppColors.surfaceHigh,
                    items: [
                      for (final code in settingsLanguages)
                        DropdownMenuItem(value: code, child: Text(languageName(code))),
                    ],
                    onChanged: _loadingId == null ? (v) => v == null ? null : _setLanguage(v) : null,
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      tr.searchSubtitlesHint,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ),
            Flexible(
              child: FutureBuilder<List<RemoteSubtitle>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: EmptyState(icon: Icons.cloud_off_rounded, title: _message(snapshot.error!)),
                    );
                  }
                  final results = snapshot.data!;
                  if (results.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: EmptyState(
                        icon: Icons.subtitles_off_outlined,
                        title: tr.noSubtitlesFound,
                        hint: tr.noSubtitlesFoundHint,
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return _ResultRow(
                        result: r,
                        loading: _loadingId == r.id,
                        enabled: _loadingId == null,
                        onDownload: () => _download(r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.loading, required this.enabled, required this.onDownload});

  final RemoteSubtitle result;
  final bool loading;
  final bool enabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final meta = [
      ?r.provider,
      if (r.format case final f? when f.isNotEmpty) f.toUpperCase(),
      if (r.downloads case final d? when d > 0) tr.downloadsCount(d),
      if (r.rating case final rating? when rating > 0) '★ ${tr.decimal(rating, 1)}',
    ].join('  ·  ');
    final tags = [
      if (r.hashMatch) tr.exactMatch,
      if (r.forced) tr.forced,
      if (r.hearingImpaired) tr.hearingImpaired,
      if (r.machineTranslated) tr.machineTranslated,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name.isEmpty ? '?' : r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t == tr.exactMatch
                                ? AppColors.accent.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
              : TextButton.icon(
                  onPressed: enabled ? onDownload : null,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(tr.loadSubtitle),
                ),
        ],
      ),
    );
  }
}
