import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_store.dart';
import 'session.dart';

/// Letzte Suchbegriffe – je Profil getrennt und verschlüsselt (DPAPI), damit
/// ein anderes Profil (z. B. nach dem Wechsel von einem PIN-geschützten) sie
/// nicht sieht. Höchstens 8, nur auf diesem Gerät.
class SearchHistory extends Notifier<List<String>> {
  static const _max = 8;
  String? _key;

  /// Schon geändert, bevor der gespeicherte Verlauf geladen war?
  bool _changed = false;

  @override
  List<String> build() {
    final session = ref.watch(sessionProvider).value;
    _key = session == null ? null : 'jellyflex.searches.${session.accountKey}';
    _changed = false;
    final key = _key;
    if (key != null) {
      SecureStore.instance.read(key: key).then((raw) {
        if (!ref.mounted || _key != key || raw == null) return;
        try {
          final loaded = [
            for (final s in jsonDecode(raw) as List)
              if (s is String) s,
          ];
          // Neuere Eingaben nicht überschreiben, sondern davor stellen.
          state = _changed
              ? [...state, ...loaded.where((s) => !state.contains(s))].take(_max).toList()
              : loaded.take(_max).toList();
        } catch (_) {}
      });
    }
    return const [];
  }

  void add(String term) {
    final t = term.trim();
    if (t.length < 2) return;
    _set([t, ...state.where((s) => s.toLowerCase() != t.toLowerCase())].take(_max).toList());
  }

  void remove(String term) => _set(state.where((s) => s != term).toList());

  void clear() => _set(const []);

  void _set(List<String> list) {
    _changed = true;
    state = list;
    final key = _key;
    if (key == null) return;
    if (list.isEmpty) {
      SecureStore.instance.delete(key: key);
    } else {
      SecureStore.instance.write(key: key, value: jsonEncode(list));
    }
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistory, List<String>>(SearchHistory.new);
