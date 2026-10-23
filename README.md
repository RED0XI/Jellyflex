# Jellyflex

Ein moderner, flüssiger Jellyfin-Client für Windows – gebaut mit Flutter und
[media_kit](https://github.com/media-kit/media-kit) (mpv). Inspiriert von Wholphin.

## Starten

**Fertige App:** `build\windows\x64\runner\Release\jellyflex.exe`
(der ganze Ordner `Release` gehört dazu – zum Weitergeben komplett kopieren).

**Aus dem Quellcode:**

```bash
flutter run -d windows
```

**Installer bauen** (ergibt `dist\Jellyflex-Setup-<Version>.exe`, installiert ohne Admin-Rechte):

```bash
powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1
```

**Neu bauen:**

```bash
flutter build windows --release
```

## Ausprobieren ohne echten Server

Ein kleiner Demo-Server mit fiktiven Filmen und Serien (als Video dient für alle Titel das
Testvideo `%TEMP%\jellyflex_test.mkv`, falls vorhanden):

```bash
dart run tool/mock_server.dart
```

In der App als Adresse `http://localhost:8097` eingeben, beliebiger Benutzername/Passwort.

**Player-Test ohne Server** (braucht ein Testvideo `%TEMP%\jellyflex_test.mkv` mit zwei Ton- und
zwei Untertitelspuren, siehe `lib/dev/player_harness.dart`):

```bash
flutter test integration_test/player_tracks_test.dart -d windows
```

**Downloads-Test** (braucht den laufenden Demo-Server und das Testvideo; prüft Laden, Pause,
Löschen, Offline-Schauen und das Nachmelden des Fortschritts):

```bash
flutter test integration_test/downloads_test.dart -d windows
```

## Funktionen

- Anmeldung mit Passwort oder **Quick Connect**; Login wird mit Windows-DPAPI verschlüsselt gespeichert
- Startseite mit wechselndem Banner, Weiterschauen, Als Nächstes, Neu in …, Favoriten, Bibliotheken
- Detailseiten mit Hintergrund-Diashow, Logo, Bewertungen, Staffeln & Episoden, Besetzung, Ähnliches
- Bibliotheksraster mit Nachladen und Sortierung, Live-Suche
- **Direct Play** aller Formate über mpv (HEVC, AV1, HDR, DTS/TrueHD, ASS/PGS-Untertitel)
- Ton-/Untertitelauswahl nach deinen Jellyfin-Einstellungen, externe Untertiteldateien (.srt/.ass)
- **Intro/Rückblick überspringen** (Media Segments, z. B. vom Intro-Skipper-Plugin)
- **Nächste Folge** mit Countdown, **Trickplay**-Vorschaubilder beim Spulen
- Fortschritt wird laufend an den Server gemeldet
- **Downloads zum Offline-Schauen** (Filme, Folgen, ganze Staffeln) mit Pause/Fortsetzen –
  samt Untertiteldateien; offline Geschautes wird gemerkt und später an den Server gemeldet
- Windows-Medienanzeige (Titel/Bild im Lautstärke-Overlay) und Medientasten
- Einstellungen: bevorzugte Sprachen, Intro automatisch überspringen, Untertitelgröße …

Bilder werden genauso ausgewählt wie in der offiziellen Jellyfin-Weboberfläche
(`poster`/`folder`/`cover` → Primary, `backdrop`/`fanart` → Backdrop, `landscape`/`thumb` → Thumb,
`logo`/`clearlogo` → Logo – inkl. Rückfall auf Staffel- bzw. Serienbilder), siehe `lib/core/images.dart`.

## Tastenkürzel

| Wo | Taste | Aktion |
|---|---|---|
| Überall | `Strg+F` | Suche |
| Überall | `Alt+←` / Maus-Zurück | Zurück |
| Überall | `F11` | Vollbild an/aus (`Esc` beendet) |
| Karten | Rechtsklick | Abspielen, Bereits angeschaut, Vergessen, Favorit … |
| Player | Untertitel-Symbol | Panel „Audio & Untertitel“ |
| Player | `Leertaste` / `K` | Abspielen / Pause |
| Player | `←` / `→` (`J` / `L`) | 10 s zurück / vor |
| Player | `↑` / `↓` | Lautstärke |
| Player | `F` / `F11` / Doppelklick | Vollbild |
| Player | `M` | Stumm |
| Player | `Esc` | Vollbild verlassen bzw. Player schließen |

**Ohne Maus:** Pfeiltasten bewegen die Auswahl (wie bei TV-Apps), Enter öffnet,
Menütaste bzw. Umschalt+F10 öffnet das Kontextmenü.

### Controller (Xbox, PlayStation …)

| Taste | Außerhalb des Players | Im Player |
|---|---|---|
| Steuerkreuz / linker Stick | Auswahl bewegen | ←/→ spulen (10 s) |
| A | Auswählen | Abspielen / Pause |
| B | Zurück | Player schließen |
| X | Kontextmenü | Panel „Audio & Untertitel“ |
| Y | Suche | – |
| Start | – | Abspielen / Pause |

## Projektaufbau

```
lib/
  core/        Server-Anbindung, Datenmodelle, Bildauswahl, Anmeldung, Speicher
  features/    Seiten: login, home, details, library, search, player
  widgets/     Bausteine: Karten, Reihen, Buttons, Titelleiste, Bilder, Scrollen
tool/          Demo-Server
test/          Tests (flutter test)
```
