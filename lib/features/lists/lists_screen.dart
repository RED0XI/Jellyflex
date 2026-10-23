import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lists.dart';
import '../../core/models.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/focusable.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import 'list_actions.dart';

/// "Meine Listen": Merkliste und eigene Listen (private Wiedergabelisten auf dem
/// Server) – jede als Reihe, Titel lassen sich entfernen, Listen löschen.
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = await askListName(context);
    if (name == null) return;
    try {
      await ref.read(listsProvider).createList(name);
    } catch (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr.didNotWork)));
    }
  }

  Future<void> _delete(BaseItem list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr.deleteListQuestion(list.name)),
        content: Text(tr.deleteListText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr.delete)),
        ],
      ),
    );
    if (ok == true) await ref.read(listsProvider).deleteList(list.id);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(playlistsProvider);
    return Scaffold(
      body: Stack(
        children: [
          SmoothScroll(
            controller: _scroll,
            builder: (context, physics) => CustomScrollView(
              controller: _scroll,
              physics: physics,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 18),
                    child: Row(
                      children: [
                        Text(
                          tr.myLists,
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tr.newList),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 24),
                    child: Text(tr.listsHint, style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                ...lists.when(
                  loading: () => [const SliverToBoxAdapter(child: RowsSkeleton())],
                  error: (e, _) => [
                    SliverToBoxAdapter(
                      child: ErrorView(message: '$e', onRetry: () => ref.invalidate(playlistsProvider)),
                    ),
                  ],
                  data: (lists) => lists.isEmpty
                      ? [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 60),
                              child: Column(
                                children: [
                                  Icon(Icons.bookmark_border_rounded, size: 52, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(tr.noListsYet, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ]
                      : [
                          SliverList.list(
                            children: [for (final list in lists) _ListRow(list: list, onDelete: () => _delete(list))],
                          ),
                        ],
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 72)),
              ],
            ),
          ),
          TopScrim(scroll: _scroll),
        ],
      ),
    );
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({required this.list, required this.onDelete});

  final BaseItem list;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(playlistItemsProvider(list.id)).value ?? const <BaseItem>[];
    final title = isWatchlist(list) ? tr.watchlist : list.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: MediaRow(
        title: '$title  ·  ${tr.titlesCount(items.length)}',
        itemCount: items.isEmpty ? 1 : items.length,
        height: kPosterWidth * 1.5 + kCardTextHeight,
        trailing: isWatchlist(list)
            ? null
            : IconButton(tooltip: tr.deleteList, onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
        itemBuilder: (context, i) {
          if (items.isEmpty) {
            return SizedBox(
              width: kPosterWidth * 2,
              child: Center(
                child: Text(tr.listEmpty, style: TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          final item = items[i];
          return Stack(
            children: [
              PosterCard(item: item),
              // Aus der Liste entfernen (oben links, damit es Abzeichen nicht verdeckt).
              Positioned(
                left: 6,
                top: 6,
                child: Focusable(
                  onTap: () => ref.read(listsProvider).removeFrom(list.id, item),
                  semanticLabel: tr.removeFromList(item.name),
                  builder: (context, hovered) => Tooltip(
                    message: tr.removeFromList(item.name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hovered ? const Color(0xFFE5484D) : Colors.black54,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
