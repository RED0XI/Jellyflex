import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/track_choice.dart';

MediaSource _source({int? defaultAudio, int? defaultSubtitle}) => MediaSource({
  'Id': 'src',
  'DefaultAudioStreamIndex': ?defaultAudio,
  'DefaultSubtitleStreamIndex': ?defaultSubtitle,
  'MediaStreams': [
    {'Type': 'Video', 'Index': 0},
    {'Type': 'Audio', 'Index': 1, 'Language': 'ger'},
    {'Type': 'Audio', 'Index': 2, 'Language': 'jpn'},
    {'Type': 'Subtitle', 'Index': 3, 'Language': 'eng', 'IsForced': true},
    {'Type': 'Subtitle', 'Index': 4, 'Language': 'eng'},
    {'Type': 'Subtitle', 'Index': 5, 'Language': 'ger', 'IsExternal': true},
    {'Type': 'Subtitle', 'Index': 6, 'Language': 'ger'},
  ],
});

void main() {
  test('Tonspur: gemerkt vor Einstellung vor Jellyfin', () {
    final source = _source(defaultAudio: 1);
    expect(preferredAudioIndex(source), 1);
    expect(preferredAudioIndex(source, setting: 'ja'), 2, reason: 'Sprachcode-Varianten zählen gleich');
    expect(preferredAudioIndex(source, remembered: 'deu', setting: 'jpn'), 1);
    expect(
      preferredAudioIndex(source, remembered: 'fre', setting: 'jpn'),
      2,
      reason: 'Gemerkte gibt es nicht',
    );
  });

  test('Untertitel: vollständig vor erzwungen, eingebettet vor Datei, aus', () {
    final source = _source();
    expect(preferredSubtitleIndex(source), isNull);
    expect(preferredSubtitleIndex(source, setting: 'eng'), 4);
    expect(preferredSubtitleIndex(source, setting: 'ger'), 6);
    expect(preferredSubtitleIndex(source, setting: subtitlesOff), -1);
    expect(preferredSubtitleIndex(source, remembered: subtitlesOff, setting: 'eng'), -1);
    expect(preferredSubtitleIndex(source, remembered: 'eng', setting: subtitlesOff), 4);
  });

  test('Auf der Detailseite gewählte Spuren nur, wenn es sie gibt', () {
    final source = _source();
    expect(validAudioIndex(source, 2), 2);
    expect(validAudioIndex(source, 3), isNull, reason: 'Index 3 ist ein Untertitel');
    expect(validAudioIndex(source, null), isNull);
    expect(validSubtitleIndex(source, -1), -1);
    expect(validSubtitleIndex(source, 5), 5);
    expect(validSubtitleIndex(source, 1), isNull, reason: 'Index 1 ist eine Tonspur');
  });
}
