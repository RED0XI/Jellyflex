import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session.dart';

/// Merkliste und eigene Listen – als private Wiedergabelisten auf dem eigenen
/// Jellyfin-Server. So sind sie auf jedem Gerät da, und nichts liegt woanders.

/// Name der Merkliste auf dem Server (in jeder Sprache gleich, damit auch
/// andere Jellyfin-Apps sie finden).
const watchlistName = 'Watchlist';

/// Alle Wiedergabelisten des Benutzers (Merkliste zuerst).
final playlistsProvider = FutureProvider.autoDispose<List<BaseItem>>((ref) async {
  final lists = await ref.watch(apiProvider).getPlaylists();
  return [...lists]..sort((a, b) {
    if (isWatchlist(a) != isWatchlist(b)) return isWatchlist(a) ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
});

bool isWatchlist(BaseItem list) => list.name.toLowerCase() == watchlistName.toLowerCase();

/// Inhalt einer Liste (mit Eintrags-IDs zum Entfernen).
final playlistItemsProvider = FutureProvider.autoDispose.family<List<BaseItem>, String>((ref, id) {
  return ref.watch(apiProvider).getPlaylistItems(id);
});

/// Inhalt der Merkliste (leer, wenn es noch keine gibt).
final watchlistProvider = FutureProvider.autoDispose<List<BaseItem>>((ref) async {
  final lists = await ref.watch(playlistsProvider.future);
  final watchlist = lists.where(isWatchlist).firstOrNull;
  if (watchlist == null) return const [];
  return ref.watch(playlistItemsProvider(watchlist.id).future);
});

/// Steht der Titel auf der Merkliste?
final onWatchlistProvider = Provider.autoDispose.family<bool, String>((ref, itemId) {
  return ref.watch(watchlistProvider).value?.any((i) => i.id == itemId) ?? false;
});

/// Ändert Listen und lädt danach die betroffenen Anzeigen neu.
class ListsController {
  ListsController(this.ref);

  final Ref ref;

  // Direkt beim Server nachsehen (nicht über die Anzeige-Provider – die können
  // zwischendurch freigegeben werden).
  Future<BaseItem?> _watchlist() async => (await ref.read(apiProvider).getPlaylists()).where(isWatchlist).firstOrNull;

  /// Auf die Merkliste bzw. wieder herunter. Ergebnis: jetzt auf der Liste?
  Future<bool> toggleWatchlist(BaseItem item) async {
    final api = ref.read(apiProvider);
    final list = await _watchlist();
    if (list == null) {
      await api.createPlaylist(watchlistName, ids: [item.id]);
      _refresh();
      return true;
    }
    final entries = await api.getPlaylistItems(list.id);
    final entry = entries.where((i) => i.id == item.id).firstOrNull;
    if (entry == null) {
      await api.addToPlaylist(list.id, [item.id]);
      _refresh(list.id);
      return true;
    }
    await api.removeFromPlaylist(list.id, [?entry.playlistItemId]);
    _refresh(list.id);
    return false;
  }

  Future<void> addTo(String listId, List<BaseItem> items) async {
    await ref.read(apiProvider).addToPlaylist(listId, [for (final i in items) i.id]);
    _refresh(listId);
  }

  Future<void> createList(String name, {List<BaseItem> items = const []}) async {
    await ref.read(apiProvider).createPlaylist(name.trim(), ids: [for (final i in items) i.id]);
    _refresh();
  }

  Future<void> removeFrom(String listId, BaseItem entry) async {
    final entryId = entry.playlistItemId;
    if (entryId == null) return;
    await ref.read(apiProvider).removeFromPlaylist(listId, [entryId]);
    _refresh(listId);
  }

  Future<void> deleteList(String listId) async {
    await ref.read(apiProvider).deletePlaylist(listId);
    _refresh();
  }

  void _refresh([String? listId]) {
    ref.invalidate(playlistsProvider);
    if (listId != null) ref.invalidate(playlistItemsProvider(listId));
  }
}

/// Bleibt bestehen (auch während laufender Aktionen aus einem Kontextmenü).
final listsProvider = Provider((ref) => ListsController(ref));
