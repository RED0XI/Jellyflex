/// Warteschlange für "Zufällig abspielen": Titel in fester, gemischter Reihenfolge.
/// Der Player nimmt als Nächstes den Titel nach dem aktuellen – statt der nächsten Folge.
abstract final class PlayQueue {
  static List<String> _ids = const [];

  static void start(List<String> ids) => _ids = List.unmodifiable(ids);

  static void clear() => _ids = const [];

  static bool contains(String id) => _ids.contains(id);

  /// Titel nach [id] (oder `null` am Ende bzw. wenn [id] nicht dazugehört).
  static String? after(String id) {
    final i = _ids.indexOf(id);
    return i >= 0 && i + 1 < _ids.length ? _ids[i + 1] : null;
  }
}
