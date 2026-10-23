# Jellyflex

A modern, smooth [Jellyfin](https://jellyfin.org) client for Windows – built with Flutter and
[media_kit](https://github.com/media-kit/media-kit) (mpv). Inspired by Wholphin.

> **Made with Claude.** Jellyflex was written with [Claude Code](https://claude.com/claude-code),
> Anthropic's AI coding assistant. The project owner decided what to build, tested every
> version and gave feedback; Claude wrote the code, the tests and this README.

## Quick start

**You need:** Windows 10 or 11 (64-bit) and a Jellyfin server you can sign in to.

1. Open the [latest release](https://github.com/RED0XI/Jellyflex/releases/latest) and download
   **`Jellyflex-Setup-<version>.exe`** (the `.sig` file next to it is only for the app's update check).
2. Run the installer. No admin rights needed.
   If Windows shows *"Windows protected your PC"*, click **More info → Run anyway**
   (the installer isn't signed with a paid Microsoft certificate).
3. Start Jellyflex, enter your server address (for example `https://jellyfin.example.com`)
   and sign in – with your password or **Quick Connect**.

That's it. To get new versions automatically offered, turn on
**Settings → About Jellyflex → Look for updates**.
To uninstall: Windows Settings → Apps → Jellyflex.

---

## In detail

### Features

**Watching**
- **Direct Play** of practically every format through mpv (HEVC, AV1, HDR, DTS/TrueHD, ASS/PGS subtitles)
- Audio/subtitle choice from your Jellyfin settings; the language you pick is **remembered per series**
- **Skip intro/recap** (Media Segments, e.g. from the Intro Skipper plugin), **next episode** countdown
- **Trickplay** previews while seeking, **chapters** with pictures (`C`) and a **Scenes** row on the details page
- Quality limit (the server converts on the fly), playback speed, audio/subtitle delay
- Volume is remembered; progress is reported to the server continuously
- Windows media overlay and media keys, **mini player** (`P`), **sleep timer**, **Ambilight**

**Browsing**
- Home with rotating banner, Continue watching, Next up, New in …, Favorites – rows can be
  reordered and hidden
- Details pages with backdrop slideshow, logo, ratings, seasons & episodes, cast, similar titles
- **People pages**: photo, biography and everything with that person on your server
- **Versions**: if a movie exists twice (e.g. 4K and 1080p), pick the version; badges show 4K, HDR/Dolby Vision, Atmos
- Library grid with sorting and filters, **multi-select**, smart search (titles, episodes, people)
- **Watchlist and your own lists** – stored as private playlists on your server
- New titles show up **automatically** – no reloading

**Downloads (watch offline)**
- Movies, episodes or whole seasons; pause, resume (also after a restart or crash), cancel right on the details page
- **Choose the folder** (asked on the first download), **only on Wi-Fi/LAN** (no downloads over mobile
  data or phone hotspots), **speed limit**, free-space check
- **Original or smaller version** – for smaller versions you choose the audio track and subtitles
- **Smart downloads**: watched episodes are deleted and the next ones downloaded, with a space limit
- Offline progress is remembered and reported to the server later

**Profiles & personalization**
- Several accounts/profiles, optional **profile PIN** and **lock when away**
- 6 **layouts** (Cinema, Couch, Library, Magazine, Minimal, Retro VHS) and 8 color **themes**
- Your own app name and logo
- Languages: English, German, French, Spanish, Turkish
- Extras: "Surprise me" slot machine, movie quiz, screensaver, seasonal touches, year in review, theme music

### Privacy & security

Jellyflex talks **only to your own Jellyfin server** – no telemetry, no ads, no fonts or images from
other services. Highlights (full list in [SECURITY.md](SECURITY.md)):

- Your login token is stored encrypted with Windows DPAPI and removed from logs and error reports.
- HTTPS certificates are checked, also for video streams; plain http only in your home network and with a warning.
- Downloads can't be placed in system folders, and the app only ever deletes its own download folders.
- **Updates:** the update check (off by default) only asks GitHub for the newest version number. When you
  click *Download & install*, the installer's **digital signature (Ed25519)** is checked before it runs –
  a modified or damaged file is never started.

### Keyboard & controller

| Where | Key | Action |
|---|---|---|
| Everywhere | `Ctrl+F` | Search |
| Everywhere | `Alt+←` / mouse back | Back |
| Everywhere | `F11` | Fullscreen on/off (`Esc` leaves) |
| Everywhere | `?` | All shortcuts |
| Everywhere | `Ctrl+,` | Settings |
| Cards | Right-click | Play, mark watched, add to list, download … |
| Player | `Space` / `K` | Play / pause |
| Player | `←` / `→` (`J` / `L`) | 10 s back / forward |
| Player | `↑` / `↓` | Volume |
| Player | `F` / double-click | Fullscreen |
| Player | `M` | Mute |
| Player | `P` | Mini player |
| Player | `C` | Chapters |
| Player | `I` | Playback info (codec, bitrate, buffer …) |
| Player | `S` | Screenshot to Pictures\Jellyflex |
| Player | `Esc` | Leave mini player/fullscreen, otherwise close |

Without a mouse, the arrow keys move the selection like on a TV, Enter opens, and the menu key
(or Shift+F10) opens the context menu.

| Controller (Xbox, PlayStation …) | Outside the player | In the player |
|---|---|---|
| D-pad / left stick | Move selection | ←/→ seek 10 s |
| A | Select | Play / pause |
| B | Back | Close player |
| X | Context menu | Audio & subtitles |
| Y | Search | – |

### Build from source

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) and Visual Studio
2022 Build Tools ("Desktop development with C++").

```bash
flutter run -d windows                 # run in debug mode
flutter build windows --release        # build → build\windows\x64\runner\Release\
```

**Installer** (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)): creates
`dist\Jellyflex-Setup-<version>.exe` and, if a signing key exists, its `.sig` signature:

```bash
powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1
```

### Try it without a real server

A small demo server with made-up movies and series:

```bash
dart run tool/mock_server.dart
```

Enter `http://localhost:8097` in the app, any user name and password. As video for all titles it
uses `%TEMP%\jellyflex_test.mkv` (any video file with two audio and two subtitle tracks, see
`lib/dev/player_harness.dart`).

### Tests

```bash
flutter test                                                   # fast tests
flutter test integration_test/downloads_test.dart -d windows   # one app test (needs the demo server)
powershell -ExecutionPolicy Bypass -File tool/run_all_tests.ps1  # everything, with a summary
```

Run app tests one file at a time – several files in one run fail on Windows.
Screenshots end up in `build/screenshots/`.

### Publishing a release (maintainers)

1. Raise the version in `pubspec.yaml` and `lib/core/version.dart`.
2. Build the installer (see above) – it is signed automatically. The secret key lives only on the
   maintainer's PC (`%APPDATA%\JellyflexRelease`, created once with `dart run tool/sign_update.dart --new-key`)
   and must never be committed.
3. Create a GitHub release with tag `v<version>` and attach **both** `Jellyflex-Setup-<version>.exe`
   and `Jellyflex-Setup-<version>.exe.sig`.

### Project structure

```
lib/
  core/        Server connection, data models, downloads, settings, storage
  features/    Screens: login, home, details, library, search, player, downloads, settings …
  widgets/     Building blocks: cards, rows, buttons, title bar, images, scrolling
  l10n/        All UI texts (English/German in strings.dart, others in strings_fr/es/tr.dart)
windows/       Windows runner (native taskbar, media overlay, network checks)
tool/          Demo server, installer build, update signing
test/          Fast tests · integration_test/  App tests in a real window
```

Images are chosen the same way as in the official Jellyfin web UI (`lib/core/images.dart`).
