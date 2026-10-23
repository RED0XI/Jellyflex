/// Reihen der Startseite – Reihenfolge und Sichtbarkeit sind einstellbar.
/// Gespeichert als Liste von Kennungen; ausgeblendete beginnen mit "!".
abstract final class HomeRows {
  /// Alle Reihen in der Standard-Reihenfolge.
  static const all = [
    'resume',
    'nextUp',
    'watchlist',
    'seasonal',
    'latest',
    'favorites',
    'recommendations',
    'collections',
    'genres',
    'libraries',
  ];

  /// Gespeicherte Liste lesen: unbekannte Einträge ignorieren, neue Reihen
  /// (aus späteren Versionen) hinten sichtbar anhängen.
  static List<({String id, bool visible})> parse(List<String> stored) {
    final result = <({String id, bool visible})>[];
    for (final raw in stored) {
      final hidden = raw.startsWith('!');
      final id = hidden ? raw.substring(1) : raw;
      if (all.contains(id) && !result.any((r) => r.id == id)) result.add((id: id, visible: !hidden));
    }
    for (final id in all) {
      if (!result.any((r) => r.id == id)) result.add((id: id, visible: true));
    }
    return result;
  }

  static List<String> encode(List<({String id, bool visible})> rows) => [
    for (final r in rows) r.visible ? r.id : '!${r.id}',
  ];
}
