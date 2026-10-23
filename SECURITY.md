# Security & privacy

Jellyflex talks **only to your own Jellyfin server**. No ads, no telemetry, no fonts or
images from other services.

## What the app protects

- **Encryption:** HTTPS certificates are checked – also for video playback (mpv uses the
  trusted root certificates of Windows). With an invalid certificate the app does not connect
  and never silently falls back to http. Unencrypted http is only allowed in your home network,
  and with a warning.
- **Sign-in data:** The token is stored on disk encrypted with Windows DPAPI and is removed from
  logs and error messages. The live connection sends it in the request header, not in the address.
- **Addresses from the server** (transcoding, subtitles) are only opened if they belong to your own
  server. IDs from the server are validated before they become folder names or in-app addresses.
- **Downloads:** stored separately per account in the download folder (always inside a "Jellyflex"
  subfolder; system folders such as Windows, Program Files and AppData are blocked). The app only
  deletes folders that are named exactly like one of its download folders and sit in a known download
  folder. Tampered entries in `downloads.json` are ignored. Other accounts can't see your downloads.
  Free space is checked before every download (1 GB always stays free).
- **Profile PIN:** stored only as a salted hash in the encrypted store; locked after 5 wrong attempts.
  Optionally the profile locks itself after a period without input – while locked, nothing can be
  started from the taskbar, remote control, media keys or a game controller.
- **Updates:** The app only installs when you click, and only installers with a valid Ed25519
  signature (the public key is built into the app; the secret key exists only on the maintainer's PC
  under `%APPDATA%\JellyflexRelease` and never in the repository). A replaced or damaged installer
  is never started.
- **Custom logo:** size and file type are limited, and images are only decoded downscaled.

## Known, deliberately accepted limits

- **Redirects:** If the server (or a proxy in front of it) redirects a video or API request to a
  different address, mpv/Dio follow the redirect with the sign-in header. Only someone who controls
  the server or proxy can exploit this – and they already have access to the account.
- **Server plugins that change the web interface** (custom JavaScript) deliberately don't run in the
  app: third-party code inside the program would be a security risk. Plugins that work on the server
  side work normally.

## Testing

The protections have their own tests (`test/*security*`, `test/redact_test.dart`,
`test/system_certs_test.dart`, `test/update_verify_test.dart`, `integration_test/tls_probe_test.dart`).
`tool/run_all_tests.ps1` runs all tests.

## Reporting a vulnerability

Please don't post details of a security problem publicly. Open an
[issue](https://github.com/RED0XI/Jellyflex/issues) that only says you found something, and we'll
agree on a private way to share the details.
