import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lists.dart';
import '../../core/models.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';

/// Lesezeichen-Knopf auf der Detailseite: auf die Merkliste / herunter.
class WatchlistButton extends ConsumerStatefulWidget {
  const WatchlistButton({super.key, required this.item});

  final BaseItem item;

  @override
  ConsumerState<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends ConsumerState<WatchlistButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(onWatchlistProvider(widget.item.id));
    return CircleIconButton(
      icon: on ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      tooltip: on ? tr.removeFromWatchlist : tr.addToWatchlist,
      active: on,
      onPressed: _busy ? null : () => toggleWatchlist(context, ref, widget.item, onBusy: _setBusy),
    );
  }

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }
}

/// Merkliste umschalten, mit kurzer Rückmeldung.
Future<void> toggleWatchlist(BuildContext context, WidgetRef ref, BaseItem item, {ValueChanged<bool>? onBusy}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  onBusy?.call(true);
  try {
    final now = await ref.read(listsProvider).toggleWatchlist(item);
    messenger?.showSnackBar(_snack(now ? tr.addedToWatchlist(item.name) : tr.removedFromWatchlist(item.name)));
  } catch (_) {
    messenger?.showSnackBar(_snack(tr.didNotWork));
  } finally {
    onBusy?.call(false);
  }
}

/// "Zu Liste hinzufügen …": vorhandene Liste wählen oder eine neue anlegen.
Future<void> showAddToListDialog(BuildContext context, ProviderContainer container, List<BaseItem> items) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final lists = await container.read(playlistsProvider.future).catchError((_) => <BaseItem>[]);
  if (!context.mounted) return;
  final choice = await showDialog<Object>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(tr.addToList),
      children: [
        for (final list in lists)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, list),
            child: Row(
              children: [
                Icon(isWatchlist(list) ? Icons.bookmark_rounded : Icons.playlist_play_rounded, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(isWatchlist(list) ? tr.watchlist : list.name)),
              ],
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'new'),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Text(
                tr.newList,
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final controller = container.read(listsProvider);
  try {
    if (choice is BaseItem) {
      await controller.addTo(choice.id, items);
      messenger?.showSnackBar(_snack(tr.addedToList(isWatchlist(choice) ? tr.watchlist : choice.name)));
    } else {
      final name = await askListName(context);
      if (name == null) return;
      await controller.createList(name, items: items);
      messenger?.showSnackBar(_snack(tr.addedToList(name)));
    }
  } catch (_) {
    messenger?.showSnackBar(_snack(tr.didNotWork));
  }
}

/// Name für eine neue Liste abfragen.
Future<String?> askListName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.pop(context, name.length > 80 ? name.substring(0, 80) : name);
      }

      return AlertDialog(
        title: Text(tr.newList),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(hintText: tr.listNameHint),
            onSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel)),
          FilledButton(onPressed: submit, child: Text(tr.create)),
        ],
      );
    },
  );
}

SnackBar _snack(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  width: 420,
  backgroundColor: AppColors.surfaceHigh,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);
