# Jellyflex

Ein moderner, flüssiger Jellyfin-Client für Windows – gebaut mit Flutter und
[media_kit](https://github.com/media-kit/media-kit) (mpv). Inspiriert von Wholphin.

**Datenschutz zuerst:** Jellyflex spricht nur mit deinem eigenen Jellyfin-Server – keine
Statistik, keine Schriften oder Bilder von fremden Diensten. Details in [SECURITY.md](SECURITY.md).

## Starten

**Fertige App:** `build\windows\x64\runner\Release\jellyflex.exe`
(der ganze Ordner `Release` gehört dazu – zum Weitergeben komplett kopieren).

**Aus dem Quellcode:**

```bash
flutter run -d windows
```

**Installer bauen** (ergibt `dist\Jellyflex-Setup-<Version>.exe`, installiert ohne Admin-Rechte,
Sprachen EN/DE/FR/ES/TR, die Deinstallation fragt, ob auch Einstellungen/Anmeldungen weg sollen –
heruntergeladene Videos bleiben immer):

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

**Weitere App-Tests** (brauchen den laufenden Demo-Server, die meisten auch das Testvideo), z. B.:

```bash
flutter test integration_test/downloads_test.dart -d windows
```

Je Datei ein eigener Aufruf – mehrere Dateien in einem Lauf scheitern unter Windows.

**Alle Tests auf einmal** (startet den Demo-Server bei Bedarf selbst, Zusammenfassung am Ende):

```bash
powershell -ExecutionPolicy Bypass -File tool/run_all_tests.ps1
```
Bildschirmfotos landen in `build/screenshots/`.

## Funktionen

- Anmeldung mit Passwort oder **Quick Connect**; Login wird mit Windows-DPAPI verschlüsselt gespeichert
- Startseite mit wechselndem Banner, Weiterschauen, Als Nächstes, Neu in …, Favoriten, Bibliotheken
- Detailseiten mit Hintergrund-Diashow, Logo, Bewertungen, Staffeln & Episoden, Besetzung, Ähnliches
- **Personenseiten**: Klick auf jemanden aus der Besetzung zeigt Foto, Lebensdaten, Biografie und
  alle Filme, Serien und Gastauftritte dieser Person auf deinem Server
- Bibliotheksraster mit Nachladen und Sortierung, Live-Suche
- **Fassungen**: Gibt es einen Film mehrfach (z. B. 4K und 1080p), wählst du auf der Detailseite
  die Fassung zum Abspielen und Herunterladen; Abzeichen zeigen 4K, HDR/Dolby Vision, Atmos
- **Medieninfo** (ⓘ auf der Detailseite): Auflösung, Codec, HDR, Farbtiefe, Bildrate, Tonspuren,
  Untertitel, Dateigröße und Bitrate
- **Direct Play** aller Formate über mpv (HEVC, AV1, HDR, DTS/TrueHD, ASS/PGS-Untertitel)
- Ton-/Untertitelauswahl nach deinen Jellyfin-Einstellungen, externe Untertiteldateien (.srt/.ass)
- **Intro/Rückblick überspringen** (Media Segments, z. B. vom Intro-Skipper-Plugin)
- **Nächste Folge** mit Countdown, **Trickplay**-Vorschaubilder beim Spulen
- Fortschritt wird laufend an den Server gemeldet
- **Downloads zum Offline-Schauen** (Filme, Folgen, ganze Staffeln) mit Pause/Fortsetzen –
  samt Untertiteldateien; offline Geschautes wird gemerkt und später an den Server gemeldet
- Windows-Medienanzeige (Titel/Bild im Lautstärke-Overlay) und Medientasten
- Einstellungen: bevorzugte Sprachen, Intro automatisch überspringen, Untertitelgröße …
- **Sprache**: Englisch (Standard), Deutsch, Französisch, Spanisch oder Türkisch –
  Einstellungen → Sprache, wirkt sofort. Englisch/Deutsch stehen in `lib/l10n/strings.dart`,
  die anderen in `strings_fr/es/tr.dart` (ein Test prüft, dass nichts fehlt)
- **Schlaue Suche**: Titel, Folgen und **Personen** (nach Schauspielern suchen), Filter
  (Filme/Serien/Folgen/Personen, nur Ungesehenes), letzte Suchen je Profil verschlüsselt gespeichert
- **Merkliste und eigene Listen**: Lesezeichen auf der Detailseite, „Zu Liste hinzufügen …“ im
  Rechtsklick-Menü, „Meine Listen“ – gespeichert als **private** Wiedergabelisten auf deinem Server
- **Startseite anpassen**: Reihen umsortieren und ausblenden (Einstellungen → Startseite)
- **Mehrfachauswahl** in Bibliotheken: mehrere Titel auf einmal als gesehen/ungesehen markieren,
  zu Favoriten, herunterladen
- **Staffel-Werkzeuge**: „x von y gesehen“, ganze Staffel markieren, Staffel herunterladen mit Fortschritt
- **Profil-PIN** (optional, je Profil): schützt ein Profil auf diesem Computer (z. B. vor Kindern);
  nur als gesalzener Hash im verschlüsselten Speicher, Sperre nach 5 Fehlversuchen
- **Taskleiste**: Sprungliste „Weiterschauen“ (Rechtsklick aufs Symbol), Download-Fortschritt am
  Symbol, blinkt, wenn ein Download im Hintergrund fertig wird
- **Offline-Hinweis**: Ist der Server weg, zeigt die App das und führt zu den Downloads
- **Bild-Zwischenspeicher** mit fester Obergrenze (Standard 300 MB, Einstellungen → Speicher)
- **Fehlerbericht** (Einstellungen → Über Jellyflex): lokal, bereinigt, wird nie verschickt
- **Update-Hinweis** (Standard: aus): fragt nur nach der neuesten Versionsnummer

**Extras**

- **Layouts** (Einstellungen → Personalisieren): ganze Oberflächen zur Wahl – Kino, Sofa (große
  Kacheln für TV/Controller), Bibliothek (Seitenleiste), Magazin, Minimal, Retro VHS
- **Themes** (Einstellungen → Personalisieren): Midnight, OLED Black, Cinema Red, Nordic Frost,
  Sunset, Synthwave, Emerald, Noir Gold – Farben der ganzen App, live umschaltbar, frei mit jedem
  Layout kombinierbar
- **Titelmusik** auf Detailseiten (abschaltbar, Standard: aus)
- **Player-Extras**: Kapitel mit Bildern (`C`), Wiedergabe-Infos (`I`), Bildschirmfoto (`S`)
- **Eigener Name und eigenes Logo** (Einstellungen → Personalisieren): erscheinen in der
  Titelleiste, beim Start, bei der Anmeldung, im Fenstertitel und als Taskleisten-Symbol
- **Überrasch mich** (🎲 oben): Poster-Rad wie ein Spielautomat mit Ticken und Melodie,
  mit Filtern (Filme/Serien, nur Ungesehenes, Genre, „fertig bis“ Uhrzeit)
- **Bildschirmschoner**: nach einer Weile ohne Eingabe gleiten Bilder deiner Titel vorbei, mit Uhr
- **Schlaf-Timer** (🌙 im Player): am Ende der Folge oder nach 15–90 Minuten, wird langsam leiser
- **Saisonale Akzente**: Halloween, Weihnachten, Silvester, Valentinstag – Effekte und passende Reihe
- **Ambilight**: die Farben des Bildes leuchten in den schwarzen Balken neben/über dem Video
- **Mini-Player** (`P` im Player): kleines Fenster unten rechts, immer im Vordergrund
- **Film-Quiz** (❓ oben): Welcher Film ist das? Unscharfes Bild wird immer deutlicher, mit Rekord
- **Klänge** bei „Überrasch mich“ und im Quiz – selbst erzeugt (`dart run tool/generate_sounds.dart`),
  zusammen ca. 125 KB, in den Einstellungen abschaltbar
- **Jahresrückblick** (Profilmenü): Stunden, Lieblingsgenre, Serie des Jahres … als Karten, als Bild speicherbar

Bilder werden genauso ausgewählt wie in der offiziellen Jellyfin-Weboberfläche
(`poster`/`folder`/`cover` → Primary, `backdrop`/`fanart` → Backdrop, `landscape`/`thumb` → Thumb,
`logo`/`clearlogo` → Logo – inkl. Rückfall auf Staffel- bzw. Serienbilder), siehe `lib/core/images.dart`.

## Tastenkürzel

| Wo | Taste | Aktion |
|---|---|---|
| Überall | `Strg+F` | Suche |
| Überall | `Alt+←` / Maus-Zurück | Zurück |
| Überall | `F11` | Vollbild an/aus (`Esc` beendet) |
| Überall | `?` | Übersicht aller Tastenkürzel |
| Überall | `Strg+,` | Einstellungen |
| Karten | Rechtsklick | Abspielen, Bereits angeschaut, Vergessen, Favorit … |
| Player | Untertitel-Symbol | Panel „Audio & Untertitel“ |
| Player | `Leertaste` / `K` | Abspielen / Pause |
| Player | `←` / `→` (`J` / `L`) | 10 s zurück / vor |
| Player | `↑` / `↓` | Lautstärke |
| Player | `F` / `F11` / Doppelklick | Vollbild |
| Player | `M` | Stumm |
| Player | `P` | Mini-Player an/aus |
| Player | `C` | Kapitel (mit Bildern) |
| Player | `I` | Wiedergabe-Infos (Codec, Bitrate, Puffer …) |
| Player | `S` | Bildschirmfoto nach Bilder\Jellyflex |
| Bibliothek | `Esc` | Mehrfachauswahl beenden |
| Player | `Esc` | Mini-Player bzw. Vollbild verlassen, sonst Player schließen |
| Quiz | `1`–`4`, `Enter` | Antworten, weiter |
| Jahresrückblick | `←` / `→` | Karte zurück / weiter |

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
