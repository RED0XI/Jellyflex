import 'dart:convert';
import 'dart:io';

import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/secure_store.dart';
import 'package:jellyflex/core/series_tracks.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/l10n/strings.dart';

/// Einstellungen für App-Tests: eine eigene Datei im Temp-Ordner – nie die echte
/// Einstellungsdatei des Benutzers. Standard ist Deutsch (die Tests prüfen deutsche Texte).
///
/// [dir]: Ordner für die Datei (sonst ein neuer Temp-Ordner).
SettingsController testSettings([Directory? dir, AppLanguage language = AppLanguage.de]) {
  final folder = dir ?? Directory.systemTemp.createTempSync('jellyflex_test_settings_');
  // Auch Anmeldedaten (Konten, PIN) nur in einer Temp-Datei – nie im echten Speicher.
  SecureStore.instance = SecureStore.forFile(File('${folder.path}${Platform.pathSeparator}secure.bin'));
  SeriesTracks.instance = SeriesTracks.forFile(File('${folder.path}${Platform.pathSeparator}series_tracks.json'));
  DownloadManager.testDirectory = folder;
  final file = File('${folder.path}${Platform.pathSeparator}settings.json');
  // "Was ist neu" schon gesehen – sonst läge das Fenster in jedem Test über der App.
  if (!file.existsSync()) {
    file.writeAsStringSync(jsonEncode({'language': language.name, 'lastSeenVersion': appVersion}));
  }
  return SettingsController(file);
}
