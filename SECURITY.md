# Sicherheit & Datenschutz

Jellyflex spricht **nur mit deinem eigenen Jellyfin-Server**. Keine Werbung, keine
Statistik, keine Schriften oder Bilder von fremden Diensten.

## Was die App schützt

- **Verschlüsselung:** https-Zertifikate werden geprüft – auch beim Video-Abspielen
  (mpv nutzt die vertrauenswürdigen Stammzertifikate von Windows). Bei einem
  ungültigen Zertifikat wird nicht verbunden und nicht still auf http ausgewichen.
  Unverschlüsseltes http gibt es nur im Heimnetz und mit Warnung.
- **Anmeldedaten:** Das Token liegt mit Windows-DPAPI verschlüsselt auf der Platte
  und wird aus Protokollen und Fehlermeldungen entfernt. Die Live-Verbindung
  schickt es im Kopf der Anfrage, nicht in der Adresse.
- **Adressen vom Server** (Transcoding, Untertitel) werden nur geöffnet, wenn sie
  zum eigenen Server gehören. Kennungen vom Server werden geprüft, bevor sie
  Ordnernamen oder App-Adressen werden.
- **Downloads:** liegen je Konto getrennt im Download-Ordner (immer ein Unterordner
  "Jellyflex"; Systemordner wie Windows, Programme, AppData sind gesperrt).
  Gelöscht wird nur, was genau wie ein Download-Ordner heißt und in einem bekannten
  Download-Ordner liegt. Manipulierte Einträge in `downloads.json` werden ignoriert.
  Andere Konten sehen fremde Downloads nicht. Vor jedem Download wird der freie
  Platz geprüft (1 GB bleibt immer frei).
- **Updates:** Die App installiert nur auf Klick und nur Installer mit gültiger
  Ed25519-Signatur (öffentlicher Schlüssel fest in der App, geheimer Schlüssel nur
  beim Herausgeber unter `%APPDATA%\JellyflexRelease`, nie im Repository). Ein
  ausgetauschter oder beschädigter Installer wird nicht gestartet.
- **Eigenes Logo:** Größe und Dateityp begrenzt, nur verkleinert dekodiert.

## Bekannte, bewusst akzeptierte Grenzen

- **Weiterleitungen:** Leitet der Server (oder ein Proxy davor) eine Video- oder
  API-Anfrage an eine andere Adresse weiter, folgen mpv/Dio der Weiterleitung mit
  dem Anmelde-Kopf. Das kann nur ausnutzen, wer den Server bzw. Proxy kontrolliert –
  und der hat ohnehin Zugriff auf das Konto.
- **Server-Plugins, die die Weboberfläche verändern** (eigenes JavaScript), laufen
  in der App bewusst nicht: fremder Code im Programm wäre ein Sicherheitsrisiko.
  Plugins, die auf dem Server arbeiten, funktionieren normal.

## Prüfung

Die Schutzmaßnahmen haben eigene Tests (`test/*security*`, `test/redact_test.dart`,
`test/system_certs_test.dart`, `integration_test/tls_probe_test.dart`). Alle Tests
startet `tool/run_all_tests.ps1`.
