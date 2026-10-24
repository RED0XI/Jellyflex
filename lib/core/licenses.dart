import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lizenzen, die Flutter nicht von selbst kennt, auf der Lizenzseite der App zeigen:
/// libmpv und FFmpeg (LGPL-3.0, ohne GPL-Teile gebaut) – siehe THIRD_PARTY_NOTICES.md.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['libmpv', 'FFmpeg'],
      'Video playback uses libmpv (mpv) with FFmpeg, prebuilt by the media_kit project without GPL '
      'parts (Windows: github.com/media-kit/libmpv-win32-video-build, macOS: '
      'github.com/media-kit/libmpv-darwin-build). They are licensed under the GNU Lesser General '
      'Public License v3.0 and ship as separate libraries next to the program. Source code: '
      'github.com/mpv-player/mpv and ffmpeg.org.',
    );
    yield LicenseEntryWithLineBreaks(['libmpv', 'FFmpeg'], await rootBundle.loadString('LICENSES/LGPL-3.0.txt'));
  });
}
