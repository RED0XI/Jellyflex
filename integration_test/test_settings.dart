import 'dart:convert';
import 'dart:io';

import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/l10n/strings.dart';

/// Einstellungen für App-Tests: eine eigene Datei im Temp-Ordner – nie die echte
/// Einstellungsdatei des Benutzers. Standard ist Deutsch (die Tests prüfen deutsche Texte).
///
/// [dir]: Ordner für die Datei (sonst ein neuer Temp-Ordner).
SettingsController testSettings([Directory? dir, AppLanguage language = AppLanguage.de]) {
  final folder = dir ?? Directory.systemTemp.createTempSync('jellyflex_test_settings_');
  final file = File('${folder.path}\\settings.json');
  if (!file.existsSync()) file.writeAsStringSync(jsonEncode({'language': language.name}));
  return SettingsController(file);
}
