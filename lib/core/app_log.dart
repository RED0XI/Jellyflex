import 'dart:collection';

import 'redact.dart';

/// Die letzten Meldungen der App – nur im Arbeitsspeicher, nie in eine Datei
/// und nie ins Netz. Fließt (bereinigt) in den Fehlerbericht ein, den der
/// Benutzer selbst speichert.
abstract final class AppLog {
  static const _maxLines = 300;
  static const _maxLineLength = 600;
  static final _lines = ListQueue<String>();

  static void add(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 23);
    var text = redactSecrets(message.trim());
    if (text.length > _maxLineLength) text = '${text.substring(0, _maxLineLength)} …';
    _lines.addLast('$time  $text');
    while (_lines.length > _maxLines) {
      _lines.removeFirst();
    }
  }

  static List<String> get lines => List.unmodifiable(_lines);

  static void clear() => _lines.clear();
}
