import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/downloads.dart';
import '../core/lists.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../theme.dart';
import 'details/details_screen.dart';
import 'downloads/downloads_screen.dart';
import 'lists/list_actions.dart';
import '../l10n/strings.dart';

import 'package:flutter/scheduler.dart';

enum _ItemAction {
  play,
  playFromStart,
  details,
  series,
  markPlayed,
  markUnplayed,
  favorite,
  unfavorite,
  watchlist,
  addToList,
  forget,
  download,
  removeDownload,
}

/// Kontextmenü (Rechtsklick) für Karten: Abspielen, als gesehen markieren,
/// aus "Weiterschauen" entfernen, Favoriten …
Future<void> showItemContextMenu(BuildContext context, BaseItem item, Offset globalPosition) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final data = item.userData;
  final canPlay = !item.isSeries && !item.isSeason && !item.isCollection;
  final downloaded = container.read(downloadsProvider.notifier).entryFor(item.id);
  // Stand der Merkliste, soweit schon geladen (der Schalter meldet danach das Ergebnis).
  final onWatchlist = container.read(onWatchlistProvider(item.id));

  PopupMenuItem<_ItemAction> entry(_ItemAction value, IconData icon, String label) => PopupMenuItem(
    value: value,
    height: 42,
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 14),
        Text(label),
      ],
    ),
  );

  // Nach dem Menü soll der Fokus (Tastatur/Controller) wieder auf der Karte liegen.
  final previousFocus = FocusManager.instance.primaryFocus;
  final action = await showMenu<_ItemAction>(
    context: context,
    position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 240),
    items: [
      PopupMenuItem(
        enabled: false,
        height: 34,
        child: Text(
          item.isEpisode ? '${item.seriesName ?? ''} · ${item.episodeLabel ?? ''}' : item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      if (canPlay) entry(_ItemAction.play, Icons.play_arrow_rounded, data.hasResumePosition ? tr.resume : tr.play),
      if (canPlay && data.hasResumePosition) entry(_ItemAction.playFromStart, Icons.replay_rounded, tr.playFromStart),
      entry(_ItemAction.details, Icons.info_outline_rounded, tr.details),
      if (item.isEpisode && item.seriesId != null) entry(_ItemAction.series, Icons.tv_rounded, tr.goToSeries),
      const PopupMenuDivider(),
      if (data.played)
        entry(_ItemAction.markUnplayed, Icons.remove_done_rounded, tr.markUnplayed)
      else
        entry(_ItemAction.markPlayed, Icons.check_rounded, tr.alreadyWatched),
      if (data.isFavorite)
        entry(_ItemAction.unfavorite, Icons.heart_broken_rounded, tr.removeFavorite)
      else
        entry(_ItemAction.favorite, Icons.favorite_border_rounded, tr.addFavorite),
      if (!item.isCollection)
        entry(
          _ItemAction.watchlist,
          onWatchlist ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
          onWatchlist ? tr.removeFromWatchlist : tr.addToWatchlist,
        ),
      if (!item.isCollection) entry(_ItemAction.addToList, Icons.playlist_add_rounded, tr.addToListMenu),
      if (data.hasResumePosition) entry(_ItemAction.forget, Icons.history_toggle_off_rounded, tr.forget),
      if (canPlay) const PopupMenuDivider(),
      if (canPlay && downloaded == null) entry(_ItemAction.download, Icons.download_rounded, tr.download),
      if (canPlay && downloaded != null)
        entry(_ItemAction.removeDownload, Icons.delete_outline_rounded, tr.deleteDownload),
    ],
  );
  restoreFocusAfterMenu(previousFocus);
  if (action == null) return;

  final api = container.read(apiProvider);
  final ticks = data.playbackPositionTicks;

  Future<void> run(Future<void> Function() call, String done) async {
    try {
      await call();
      refreshItemDataIn(container, item);
      messenger?.showSnackBar(_snack(done));
    } catch (_) {
      messenger?.showSnackBar(_snack(tr.didNotWork));
    }
  }

  switch (action) {
    case _ItemAction.play:
      router.push('/play/${item.id}${ticks > 0 ? '?start=$ticks' : ''}');
    case _ItemAction.playFromStart:
      router.push('/play/${item.id}');
    case _ItemAction.details:
      router.push('/item/${item.id}');
    case _ItemAction.series:
      router.push('/item/${item.seriesId}');
    case _ItemAction.markPlayed:
      await run(() => api.setPlayed(item.id, true), tr.markedWatched(item.name));
    case _ItemAction.markUnplayed:
      await run(() => api.setPlayed(item.id, false), tr.markedUnwatched(item.name));
    case _ItemAction.favorite:
      await run(() => api.setFavorite(item.id, true), tr.addedToFavorites);
    case _ItemAction.unfavorite:
      await run(() => api.setFavorite(item.id, false), tr.removedFromFavorites);
    case _ItemAction.download:
      await container.read(downloadsProvider.notifier).enqueue(item);
      messenger?.showSnackBar(_snack(tr.downloadStarted(item.name)));
    case _ItemAction.removeDownload:
      if (!context.mounted || !await confirmRemoveDownload(context, item.name)) return;
      await container.read(downloadsProvider.notifier).remove(item.id);
      messenger?.showSnackBar(_snack(tr.downloadDeleted));
    case _ItemAction.watchlist:
      try {
        final now = await container.read(listsProvider).toggleWatchlist(item);
        messenger?.showSnackBar(_snack(now ? tr.addedToWatchlist(item.name) : tr.removedFromWatchlist(item.name)));
      } catch (_) {
        messenger?.showSnackBar(_snack(tr.didNotWork));
      }
    case _ItemAction.addToList:
      if (context.mounted) await showAddToListDialog(context, container, [item]);
    case _ItemAction.forget:
      await run(() => api.clearResumePosition(item.id), tr.removedFromContinue);
  }
}

SnackBar _snack(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  width: 420,
  backgroundColor: AppColors.surfaceHigh,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  duration: const Duration(seconds: 3),
);

/// Flutter gibt den Fokus nach dem Schließen eines Menüs an die Seite zurück,
/// nicht an das vorher fokussierte Element. Sobald das passiert, leiten wir
/// ihn an [node] weiter – so geht es per Tastatur/Controller nahtlos weiter.
void restoreFocusAfterMenu(FocusNode? node) {
  if (node == null) return;
  late void Function() listener;
  listener = () {
    final context = node.context;
    final primary = FocusManager.instance.primaryFocus;
    // Karte weg oder jemand hat bewusst ein anderes Element fokussiert → fertig.
    if (context == null || !context.mounted || (primary != null && primary is! FocusScopeNode && primary != node)) {
      FocusManager.instance.removeListener(listener);
      return;
    }
    // Die Seite kann den Fokus während der Schließ-Animation mehrmals an sich ziehen –
    // aber nur zurückholen, solange die Karte auf der sichtbaren Seite liegt.
    if (primary is FocusScopeNode && (ModalRoute.of(context)?.isCurrent ?? true)) node.requestFocus();
  };
  FocusManager.instance.addListener(listener);
  listener();
  // Nach dem Schließen des Menüs nicht mehr gebraucht: nach ~60 gezeichneten
  // Bildern (die Schließ-Animation ist dann längst vorbei) wieder abmelden.
  var frames = 0;
  void countFrame(Duration _) {
    if (++frames >= 60) {
      FocusManager.instance.removeListener(listener);
    } else {
      // Keine zusätzlichen Bilder erzwingen – nur ohnehin gezeichnete zählen.
      SchedulerBinding.instance.addPostFrameCallback(countFrame);
    }
  }

  SchedulerBinding.instance.addPostFrameCallback(countFrame);
}
