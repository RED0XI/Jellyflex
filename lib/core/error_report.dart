import 'dart:io';

import 'app_log.dart';
import 'downloads.dart';
import 'redact.dart';
import 'session.dart';
import 'settings.dart';
import 'version.dart';

/// Fehlerbericht zum Speichern oder Kopieren: Version, Windows, Einstellungen
/// und die letzten Meldungen der App. Er wird nie verschickt – der Benutzer
/// entscheidet selbst, ob und wem er ihn gibt.
///
/// Bereinigt: keine Zugangsdaten, keine Server-Adresse, kein Benutzername,
/// kein Windows-Benutzerordner.
String buildErrorReport({
  required AppSettings settings,
  AuthSession? session,
  List<DownloadEntry> downloads = const [],
  List<String>? log,
  DateTime? now,
}) {
  final created = (now ?? DateTime.now()).toIso8601String().substring(0, 19).replaceFirst('T', ' ');
  final statuses = <String, int>{};
  for (final d in downloads) {
    statuses.update(d.status.name, (n) => n + 1, ifAbsent: () => 1);
  }
  final text = StringBuffer()
    ..writeln('Jellyflex error report')
    ..writeln('Created: $created')
    ..writeln()
    ..writeln('App version: $appVersion')
    ..writeln('${Platform.isMacOS ? 'macOS' : 'Windows'}: ${Platform.operatingSystemVersion}')
    ..writeln('Dart: ${Platform.version.split(' ').first}')
    ..writeln('CPU cores: ${Platform.numberOfProcessors}')
    ..writeln(
      'Server: ${session == null ? 'not signed in' : (session.serverUrl.startsWith('https') ? 'https' : 'http')}',
    )
    ..writeln()
    ..writeln('Settings:')
    ..writeln('  Language: ${settings.language.name}, theme: ${settings.themeId}')
    ..writeln('  Quality: ${settings.maxBitrate ?? 'Original'}, ambilight: ${settings.ambilight.name}')
    ..writeln('  Image cache: ${settings.imageCacheMb} MB, screensaver: ${settings.screensaverMinutes} min')
    ..writeln('  Sounds: ${settings.soundEffects}, seasonal themes: ${settings.seasonalThemes}')
    ..writeln()
    ..writeln('Downloads: ${downloads.length} ${statuses.isEmpty ? '' : statuses}')
    ..writeln()
    ..writeln('Recent messages:');
  final lines = log ?? AppLog.lines;
  if (lines.isEmpty) text.writeln('  (none)');
  for (final line in lines) {
    text.writeln('  $line');
  }
  return scrubReport(text.toString(), session: session);
}

/// Entfernt persönliche Angaben aus einem Bericht.
String scrubReport(String text, {AuthSession? session}) {
  var result = redactSecrets(text);
  if (session != null) {
    final uri = Uri.tryParse(session.serverUrl);
    for (final (value, placeholder) in [
      (session.serverUrl, '<server>'),
      if (uri != null && uri.host.isNotEmpty) (uri.host, '<server>'),
      (session.serverName, '<server-name>'),
      (session.userId, '<user-id>'),
      (session.userName, '<user>'),
      (session.deviceId, '<device>'),
    ]) {
      if (value.length >= 3) result = result.replaceAll(value, placeholder);
    }
  }
  // Benutzerordner (enthält den Benutzernamen) – Windows: %USERPROFILE%, macOS: $HOME.
  final profile = Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
  if (profile != null && profile.length > 3) {
    result = result.replaceAll(
      RegExp(RegExp.escape(profile), caseSensitive: false),
      Platform.isWindows ? '%USERPROFILE%' : '~',
    );
  }
  // Übrige Adressen im Text (z. B. aus Fehlermeldungen) nur ohne Rechnernamen.
  return result.replaceAllMapped(RegExp(r'(https?|wss?)://[^\s/"]+'), (m) => '${m[1]}://<host>');
}
