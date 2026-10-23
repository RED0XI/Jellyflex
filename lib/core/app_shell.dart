import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'jellyfin_api.dart';

/// Anbindung an die Windows-Shell (Gegenstück: windows/runner/app_shell.cpp):
/// Sprungliste der Taskleiste und Aufrufe aus ihr.
///
/// Ein Eintrag startet `jellyflex.exe --resume=<Kennung>`; läuft die App
/// schon, wird der Aufruf an das offene Fenster weitergegeben.
abstract final class AppShell {
  static const _channel = MethodChannel('jellyflex/shell');
  static final _resume = RegExp(r'--resume=([A-Za-z0-9_-]{1,64})(?:\s|$)');

  /// Kennung aus einer Befehlszeile wie `--resume=abc123` (oder `null`).
  /// Nur harmlose Zeichen – alles andere wird ignoriert.
  static String? resumeIdFrom(String commandLine) => _resume.firstMatch(commandLine)?.group(1);

  /// Beim Start übergebener Titel, der fortgesetzt werden soll (einmalig abholen).
  static String? pendingResumeId;

  /// Aufrufe weiterer Instanzen empfangen.
  static void listen(ValueChanged<String> onResume) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'open' || call.arguments is! String) return;
      final id = resumeIdFrom(call.arguments as String);
      if (id != null) onResume(id);
    });
  }

  /// Sprungliste "Weiterschauen" setzen (leer = entfernen, z. B. beim Abmelden).
  static Future<void> setJumpList(String category, List<({String id, String title})> items) async {
    try {
      await _channel.invokeMethod<bool>('setJumpList', {
        'category': category,
        'items': [
          for (final i in items.take(6)) {'title': _clip(i.title), 'arguments': '--resume=${i.id}'},
        ],
      });
    } on MissingPluginException {
      // Ohne Windows-Runner (z. B. in Tests) gibt es keine Sprungliste.
    } catch (e) {
      debugPrint('Sprungliste nicht gesetzt: $e');
    }
  }

  static String _clip(String text) => text.length > 80 ? '${text.substring(0, 79)}…' : text;

  /// "Weiterschauen" vom Server holen und in die Sprungliste schreiben.
  static Future<void> updateJumpList(JellyfinApi api) async {
    try {
      final resume = await api.getResume(limit: 6);
      await setJumpList(tr.continueWatching, [
        for (final i in resume)
          if (_safeId.hasMatch(i.id))
            (
              id: i.id,
              title: i.isEpisode && i.seriesName != null ? '${i.seriesName} · ${i.episodeLabel ?? i.name}' : i.name,
            ),
      ]);
    } catch (_) {}
  }

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
}
