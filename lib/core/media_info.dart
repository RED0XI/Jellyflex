import 'downloads.dart' show formatBytes;
import 'format.dart' show languageName;
import 'models.dart';
import '../l10n/strings.dart';

/// Lesbare Beschreibungen für Fassungen und Spuren ("4K", "HDR10", "TrueHD Atmos 7.1" …).

/// Auflösung als Kurzform. Kino-Formate (z. B. 3840×1600) zählen nach der Breite.
String? resolutionLabel(MediaStream? video) {
  final w = video?.width ?? 0;
  final h = video?.height ?? 0;
  if (w == 0 && h == 0) return null;
  if (w >= 7000 || h >= 4000) return '8K';
  if (w >= 3200 || h >= 2000) return '4K';
  if (w >= 1800 || h >= 1000) return '1080p';
  if (w >= 1200 || h >= 700) return '720p';
  return 'SD';
}

/// HDR-Art oder `null` bei SDR.
String? hdrLabel(MediaStream? video) {
  final type = video?.videoRangeType ?? '';
  if (type.startsWith('DOVI')) return 'Dolby Vision';
  return switch (type) {
    'HDR10Plus' => 'HDR10+',
    'HDR10' => 'HDR10',
    'HLG' => 'HLG',
    _ => video?.videoRange == 'HDR' ? 'HDR' : null,
  };
}

String codecLabel(String? codec) => switch (codec?.toLowerCase()) {
  null || '' => '?',
  'hevc' || 'h265' => 'HEVC',
  'h264' || 'avc' => 'H.264',
  'av1' => 'AV1',
  'vp9' => 'VP9',
  'mpeg2video' => 'MPEG-2',
  'vc1' => 'VC-1',
  'truehd' => 'TrueHD',
  'eac3' => 'Dolby Digital Plus',
  'ac3' => 'Dolby Digital',
  'dts' => 'DTS',
  'aac' => 'AAC',
  'flac' => 'FLAC',
  'opus' => 'Opus',
  'mp3' => 'MP3',
  'pcm_s16le' || 'pcm_s24le' => 'PCM',
  'subrip' || 'srt' => 'SRT',
  'ass' || 'ssa' => 'ASS',
  'pgssub' => 'PGS',
  'dvdsub' || 'dvd_subtitle' => 'VobSub',
  'webvtt' => 'WebVTT',
  final c => c.toUpperCase(),
};

String channelsLabel(int channels) => switch (channels) {
  1 => 'Mono',
  2 => 'Stereo',
  6 => '5.1',
  8 => '7.1',
  _ => tr.channels(channels),
};

/// Besonderes Tonformat (Atmos, DTS:X, DTS-HD MA) aus Profil oder Titel.
String? audioFeature(MediaStream audio) {
  final text = '${audio.profile ?? ''} ${audio.title ?? ''} ${audio.displayTitle ?? ''}'.toLowerCase();
  if (text.contains('atmos')) return 'Atmos';
  if (text.contains('dts:x') || text.contains('dts-x')) return 'DTS:X';
  if (text.contains('dts-hd ma')) return 'DTS-HD MA';
  return null;
}

/// Einheitlicher Name einer Ton- oder Untertitelspur für Menüs und Player:
/// "Deutsch · Dolby Digital Plus · 5.1 · Standard", "Englisch · SRT · Erzwungen".
/// Ein eigener Titel der Spur ("Kommentar") kommt dazu, wenn er nicht nur wiederholt.
String trackLabel(MediaStream s) {
  final title = s.title?.trim() ?? '';
  final hasLanguage = (s.language ?? '').isNotEmpty && s.language!.toLowerCase() != 'und';
  final language = hasLanguage ? languageName(s.language) : (title.isNotEmpty ? title : languageName(null));
  final format = s.type == 'Audio' ? audioSummary(s) : codecLabel(s.codec);
  final parts = [language, if (format.isNotEmpty && format != '?') format];
  final known = parts.join(' ').toLowerCase();
  if (hasLanguage && title.isNotEmpty && !_repeats(title.toLowerCase(), known)) parts.add(title);
  if (s.isForced) parts.add(tr.forced);
  if (s.isDefault) parts.add(tr.defaultTrack);
  if (s.isExternal) parts.add(tr.file);
  return parts.join(' · ');
}

/// Titel wie "German", "Deutsch DTS 5.1" oder "Forced" sagen nichts Neues.
bool _repeats(String title, String known) {
  const noise = {'default', 'standard', 'forced', 'erzwungen', 'stereo', 'mono', 'sdh', 'full', 'komplett'};
  final words = title.split(RegExp(r'[^\p{L}\p{N}.:+-]+', unicode: true)).where((w) => w.isNotEmpty);
  return words.every((w) => known.contains(w) || noise.contains(w) || RegExp(r'^\d(\.\d)?$').hasMatch(w));
}

/// z. B. "TrueHD Atmos · 7.1"
String audioSummary(MediaStream audio) {
  final feature = audioFeature(audio);
  final codec = codecLabel(audio.codec);
  return [
    feature == 'DTS-HD MA' ? feature! : [codec, ?feature].join(' '),
    if (audio.channels != null) channelsLabel(audio.channels!),
  ].join(' · ');
}

/// "24,5 Mbit/s" bzw. "640 kbit/s"
String formatBitrate(int bitsPerSecond) {
  if (bitsPerSecond >= 1000000) {
    return '${tr.decimal(bitsPerSecond / 1000000, 1)} Mbit/s';
  }
  return '${(bitsPerSecond / 1000).round()} kbit/s';
}

/// Kurzbeschreibung einer Fassung: "4K · Dolby Vision · HEVC".
String versionLabel(MediaSource source) {
  final video = source.videoStream;
  final parts = [?resolutionLabel(video), ?hdrLabel(video), if (video != null) codecLabel(video.codec)];
  return parts.isEmpty ? (source.name ?? tr.version) : parts.join(' · ');
}

/// Zweite Zeile im Versionsmenü: Name der Fassung, Größe, Bitrate.
String versionDetails(MediaSource source) => [
  if (source.name case final name? when name.isNotEmpty) name,
  if (source.size case final size? when size > 0) formatBytes(size),
  if (source.bitrate case final rate? when rate > 0) formatBitrate(rate),
].join(' · ');

/// Abzeichen für die Detailseite: Auflösung, HDR, besonderes Tonformat.
List<String> qualityBadges(MediaSource source) {
  final video = source.videoStream;
  final features = {for (final a in source.audioStreams) ?audioFeature(a)};
  return [?resolutionLabel(video), ?hdrLabel(video), ...features.where((f) => f != 'DTS-HD MA')];
}
