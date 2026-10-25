import 'models.dart';
import 'settings.dart';

/// Welche Ton- und Untertitelspur beim Start gewählt wird – gemeinsam für den Player
/// und die Detailseite (die anzeigt, was gleich laufen wird).

/// Tonspur: für diese Serie zuletzt gewählt ([remembered]), sonst bevorzugte Sprache
/// aus den Einstellungen ([setting]), sonst wie in Jellyfin.
int? preferredAudioIndex(MediaSource source, {String? remembered, String? setting}) {
  for (final pref in [remembered, setting]) {
    if (pref == null) continue;
    final match = source.embeddedStreams('Audio').where((s) => sameLanguage(s.language, pref)).firstOrNull;
    if (match != null) return match.index;
  }
  return source.defaultAudioStreamIndex;
}

/// Untertitel: für diese Serie zuletzt gewählt, sonst nach Einstellung,
/// sonst wie in Jellyfin (-1 = aus). Beide Werte dürfen [subtitlesOff] sein.
int? preferredSubtitleIndex(MediaSource source, {String? remembered, String? setting}) {
  if (remembered != null) {
    if (remembered == subtitlesOff) return -1;
    final index = subtitleIndexFor(source, remembered);
    if (index != null) return index;
  }
  if (setting == subtitlesOff) return -1;
  if (setting != null) {
    final index = subtitleIndexFor(source, setting);
    if (index != null) return index;
  }
  return source.defaultSubtitleStreamIndex;
}

/// Beste Untertitelspur einer Sprache (oder `null`).
int? subtitleIndexFor(MediaSource source, String language) {
  // Vollständige Untertitel vor erzwungenen, eingebettete vor Dateien.
  final candidates =
      source.mediaStreams.where((s) => s.type == 'Subtitle' && sameLanguage(s.language, language)).toList()
        ..sort((a, b) {
          final forced = (a.isForced ? 1 : 0) - (b.isForced ? 1 : 0);
          if (forced != 0) return forced;
          return (a.isExternal ? 1 : 0) - (b.isExternal ? 1 : 0);
        });
  return candidates.firstOrNull?.index;
}

/// Von außen gewünschte Tonspur (z. B. auf der Detailseite gewählt), wenn es sie in [source] gibt.
int? validAudioIndex(MediaSource source, int? index) =>
    index != null && source.mediaStreams.any((s) => s.type == 'Audio' && s.index == index) ? index : null;

/// Wie [validAudioIndex] für Untertitel; -1 (aus) ist immer gültig.
int? validSubtitleIndex(MediaSource source, int? index) {
  if (index == null) return null;
  if (index < 0) return -1;
  return source.mediaStreams.any((s) => s.type == 'Subtitle' && s.index == index) ? index : null;
}
