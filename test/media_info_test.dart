import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/media_info.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/l10n/strings.dart';

MediaStream _video(Map<String, Object> extra) => MediaStream({'Type': 'Video', ...extra});

void main() {
  // Diese Tests prüfen die deutschen Texte.
  setUp(() => appLanguage = AppLanguage.de);

  test('Auflösung: auch Kino-Formate richtig einordnen', () {
    expect(resolutionLabel(_video({'Width': 3840, 'Height': 2160})), '4K');
    expect(resolutionLabel(_video({'Width': 3840, 'Height': 1600})), '4K');
    expect(resolutionLabel(_video({'Width': 1920, 'Height': 800})), '1080p');
    expect(resolutionLabel(_video({'Width': 1280, 'Height': 720})), '720p');
    expect(resolutionLabel(_video({'Width': 720, 'Height': 576})), 'SD');
    expect(resolutionLabel(_video({})), isNull);
  });

  test('HDR-Arten', () {
    expect(hdrLabel(_video({'VideoRange': 'HDR', 'VideoRangeType': 'DOVIWithHDR10'})), 'Dolby Vision');
    expect(hdrLabel(_video({'VideoRange': 'HDR', 'VideoRangeType': 'HDR10Plus'})), 'HDR10+');
    expect(hdrLabel(_video({'VideoRange': 'HDR', 'VideoRangeType': 'HDR10'})), 'HDR10');
    expect(hdrLabel(_video({'VideoRange': 'HDR'})), 'HDR');
    expect(hdrLabel(_video({'VideoRange': 'SDR', 'VideoRangeType': 'SDR'})), isNull);
  });

  test('Ton: Codec, Atmos, Kanäle', () {
    final atmos = MediaStream({
      'Type': 'Audio',
      'Codec': 'truehd',
      'Profile': 'Dolby TrueHD + Dolby Atmos',
      'Channels': 8,
    });
    expect(audioSummary(atmos), 'TrueHD Atmos · 7.1');
    expect(audioSummary(MediaStream({'Type': 'Audio', 'Codec': 'aac', 'Channels': 2})), 'AAC · Stereo');
    expect(
      audioSummary(MediaStream({'Type': 'Audio', 'Codec': 'dts', 'Profile': 'DTS-HD MA', 'Channels': 6})),
      'DTS-HD MA · 5.1',
    );
  });

  test('Fassung: Beschreibung und Abzeichen', () {
    final source = MediaSource({
      'Id': 'a',
      'Name': '4K Remux',
      'Size': 61400000000,
      'Bitrate': 62000000,
      'MediaStreams': [
        {'Type': 'Video', 'Codec': 'hevc', 'Width': 3840, 'Height': 2160, 'VideoRangeType': 'HDR10'},
        {'Type': 'Audio', 'Codec': 'truehd', 'Profile': 'Dolby Atmos', 'Channels': 8},
      ],
    });
    expect(versionLabel(source), '4K · HDR10 · HEVC');
    expect(versionDetails(source), '4K Remux · 57,2 GB · 62,0 Mbit/s');
    expect(qualityBadges(source), ['4K', 'HDR10', 'Atmos']);
  });

  test('Spurnamen: einheitlich, ohne doppelte Angaben', () {
    MediaStream track(Map<String, Object> raw) => MediaStream(raw);
    expect(
      trackLabel(track({'Type': 'Audio', 'Language': 'ger', 'Codec': 'eac3', 'Channels': 6, 'IsDefault': true})),
      'Deutsch · Dolby Digital Plus · 5.1 · Standard',
    );
    expect(
      trackLabel(track({'Type': 'Audio', 'Language': 'eng', 'Codec': 'ac3', 'Channels': 2, 'Title': 'Kommentar'})),
      'Englisch · Dolby Digital · Stereo · Kommentar',
    );
    // Titel, der nur wiederholt, was schon dasteht.
    expect(
      trackLabel(track({'Type': 'Audio', 'Language': 'eng', 'Codec': 'aac', 'Channels': 2, 'Title': 'English Stereo'})),
      'Englisch · AAC · Stereo · English Stereo',
      reason: '"English" ist nicht "Englisch" – der Titel bleibt',
    );
    expect(
      trackLabel(
        track({'Type': 'Subtitle', 'Language': 'ger', 'Codec': 'subrip', 'Title': 'Deutsch', 'IsForced': true}),
      ),
      'Deutsch · SRT · Erzwungen',
    );
    expect(
      trackLabel(track({'Type': 'Subtitle', 'Language': 'ger', 'Codec': 'srt', 'IsExternal': true})),
      'Deutsch · SRT · Datei',
    );
    expect(trackLabel(track({'Type': 'Subtitle', 'Codec': 'pgssub', 'Title': 'Signs & Songs'})), 'Signs & Songs · PGS');
    // Zwei sonst gleiche Spuren bleiben unterscheidbar.
    expect(
      trackLabel(track({'Type': 'Subtitle', 'Language': 'eng', 'Codec': 'subrip', 'Title': 'English SDH'})),
      'Englisch · SRT · English SDH',
    );
    expect(
      trackLabel(track({'Type': 'Subtitle', 'Language': 'eng', 'Codec': 'subrip', 'IsHearingImpaired': true})),
      'Englisch · SRT · Für Hörgeschädigte',
    );
  });
}
