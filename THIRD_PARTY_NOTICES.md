# Third-party notices

Jellyflex itself is licensed under the GNU General Public License v3.0 (see [LICENSE](LICENSE)).
It ships with the following third-party components.

## libmpv and FFmpeg (video playback)

The player uses **libmpv** ([mpv](https://mpv.io)) with **FFmpeg** and their libraries, as
prebuilt by the media_kit project. Both builds are made **without GPL parts** and are licensed
under the **GNU Lesser General Public License v3.0** – full text in
[LICENSES/LGPL-3.0.txt](LICENSES/LGPL-3.0.txt).

| System | File in Jellyflex | Build and source |
|---|---|---|
| Windows | `libmpv-2.dll` | [media-kit/libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build) (release `2023-09-24`, mpv built with `-Dgpl=false`, FFmpeg with `--disable-gpl --enable-version3`) |
| macOS | `Mpv.framework` and the frameworks next to it | [media-kit/libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) (`video-default` variant, the LGPL build for playback) |

The libraries are separate files next to the program and can be replaced with your own build of
the same version. The source code of mpv and FFmpeg is available from the links above and from
[mpv-player/mpv](https://github.com/mpv-player/mpv) and [ffmpeg.org](https://ffmpeg.org).

## Mozilla CA certificates (iPhone/iPad)

On iPhone and iPad the video player (mpv/FFmpeg with mbedTLS) cannot use the system's trusted
root certificates. Jellyflex therefore ships the root certificates of Mozilla's CA program,
[assets/certs/cacert.pem](assets/certs/cacert.pem), as extracted by the curl project
([curl.se/docs/caextract.html](https://curl.se/docs/caextract.html)) from Mozilla's
`certdata.txt`. Licensed under the **Mozilla Public License 2.0** – full text in
[LICENSES/MPL-2.0.txt](LICENSES/MPL-2.0.txt); source: the
[NSS builtins in the Firefox source tree](https://github.com/mozilla-firefox/firefox/blob/release/security/nss/lib/ckfw/builtins/certdata.txt).
Update by downloading a newer `cacert.pem` from the link above.

## Flutter and Dart packages

Flutter, the Dart packages (e.g. media_kit, dio, riverpod, go_router, window_manager – MIT, BSD
and Apache-2.0 licenses) and their own dependencies are listed with their full license texts
inside the app: **Settings → About Jellyflex → Licenses**. The exact versions are in
[pubspec.lock](pubspec.lock).
