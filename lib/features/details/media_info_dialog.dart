import 'package:flutter/material.dart';

import '../../core/downloads.dart' show formatBytes;
import '../../core/format.dart';
import '../../core/media_info.dart';
import '../../core/models.dart';
import '../../theme.dart';
import '../../l10n/strings.dart';

/// Technische Infos zu einer Fassung: Datei, Video, Tonspuren, Untertitel.
Future<void> showMediaInfoDialog(BuildContext context, BaseItem item, MediaSource source) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MediaInfoDialog(item: item, source: source),
  );
}

class _MediaInfoDialog extends StatelessWidget {
  const _MediaInfoDialog({required this.item, required this.source});

  final BaseItem item;
  final MediaSource source;

  @override
  Widget build(BuildContext context) {
    final video = source.videoStream;
    final audio = source.audioStreams;
    final subtitles = source.subtitleStreams;
    final runtime = source.runTimeTicks ?? item.runTimeTicks;
    final fileName = source.path?.split(RegExp(r'[\\/]')).last;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.mediaInfo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(versionLabel(source), style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr.close,
                    autofocus: true,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: tr.file,
                      icon: Icons.insert_drive_file_outlined,
                      rows: [
                        if (source.name case final name? when name.isNotEmpty) (tr.version, name),
                        (tr.format, (source.container ?? '?').toUpperCase()),
                        if (source.size case final size? when size > 0) (tr.size, formatBytes(size)),
                        if (source.bitrate case final rate? when rate > 0) (tr.totalBitrate, formatBitrate(rate)),
                        if (runtime != null) (tr.runtime, formatRuntime(ticksToDuration(runtime))),
                        if (fileName != null) (tr.fileName, fileName),
                      ],
                    ),
                    if (video != null)
                      _Section(
                        title: tr.video,
                        icon: Icons.movie_outlined,
                        rows: [
                          if (video.width != null && video.height != null)
                            (
                              tr.resolution,
                              [
                                '${video.width} × ${video.height}',
                                if (resolutionLabel(video) case final r?) '($r)',
                              ].join('  '),
                            ),
                          (tr.codec, [codecLabel(video.codec), ?video.profile].join(' · ')),
                          (tr.dynamicRange, hdrLabel(video) ?? 'SDR'),
                          if (video.bitDepth != null) (tr.bitDepth, '${video.bitDepth} Bit'),
                          if (video.frameRate case final fps? when fps > 0)
                            (tr.frameRate, '${tr.decimal(fps, fps % 1 == 0 ? 0 : 3)} fps'),
                          if (video.bitRate case final rate? when rate > 0) (tr.bitrate, formatBitrate(rate)),
                        ],
                      ),
                    if (audio.isNotEmpty)
                      _Section(
                        title: tr.audioCount(audio.length),
                        icon: Icons.graphic_eq_rounded,
                        tracks: [
                          for (final a in audio)
                            (
                              a.displayTitle ?? audioSummary(a),
                              [
                                audioSummary(a),
                                if (a.bitRate case final rate? when rate > 0) formatBitrate(rate),
                                if (a.sampleRate case final hz? when hz > 0)
                                  '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1).replaceAll('.', ',')} kHz',
                                if (a.isDefault) tr.defaultTrack,
                              ].join(' · '),
                            ),
                        ],
                      ),
                    if (subtitles.isNotEmpty)
                      _Section(
                        title: tr.subtitlesCount(subtitles.length),
                        icon: Icons.subtitles_outlined,
                        tracks: [
                          for (final s in subtitles)
                            (
                              s.displayTitle ?? languageName(s.language),
                              [
                                codecLabel(s.codec),
                                if (s.isExternal) tr.file,
                                if (s.isForced) tr.forced,
                                if (s.isDefault) tr.defaultTrack,
                              ].join(' · '),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, this.rows = const [], this.tracks = const []});

  final String title;
  final IconData icon;

  /// Beschriftung → Wert.
  final List<(String, String)> rows;

  /// Spuren: Name und Details darunter.
  final List<(String, String)> tracks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: SelectableText(value)),
                ],
              ),
            ),
          for (final (name, details) in tracks)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (details.isNotEmpty)
                    Text(details, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
