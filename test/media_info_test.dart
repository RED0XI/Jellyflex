import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/media_info.dart';
import 'package:jellyflex/core/models.dart';

MediaStream _video(Map<String, Object> extra) => MediaStream({'Type': 'Video', ...extra});

void main() {
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
}
