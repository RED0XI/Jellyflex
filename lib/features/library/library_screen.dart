import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../../widgets/states.dart';

enum LibrarySort {
  name('Titel', 'SortName', 'Ascending'),
  added('Zuletzt hinzugefügt', 'DateCreated,SortName', 'Descending'),
  released('Erscheinungsdatum', 'PremiereDate,ProductionYear,SortName', 'Descending'),
  rating('Bewertung', 'CommunityRating,SortName', 'Descending');

  const LibrarySort(this.label, this.sortBy, this.sortOrder);

  final String label;
  final String sortBy;
  final String sortOrder;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.libraryId, required this.name, this.collectionType});

  final String libraryId;
  final String name;
  final String? collectionType;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  static const _pageSize = 120;

  final _scroll = ScrollController();
  final _items = <BaseItem>[];
  int? _total;
  bool _loading = false;
  Object? _error;
  LibrarySort _sort = LibrarySort.name;

  String get _includeTypes => switch (widget.collectionType) {
    'movies' => 'Movie',
    'tvshows' => 'Series',
    _ => 'Movie,Series',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 1200) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_total != null && _items.length >= _total!)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final sort = _sort;
    try {
      final page = await ref
          .read(apiProvider)
          .getLibraryPage(
            parentId: widget.libraryId,
            includeItemTypes: _includeTypes,
            sortBy: sort.sortBy,
            sortOrder: sort.sortOrder,
            startIndex: _items.length,
            limit: _pageSize,
          );
      if (!mounted || sort != _sort) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.totalCount;
      });
      // Falls die erste Seite den Bildschirm nicht füllt, direkt nachladen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeSort(LibrarySort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _items.clear();
      _total = null;
      _loading = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - kPageGutter * 2;
    // So viele Spalten wie passen, Karten füllen die Breite exakt aus.
    const spacing = 22.0;
    final columns = ((width + spacing) / (kPosterWidth + spacing)).floor().clamp(2, 12);
    final cardWidth = (width - spacing * (columns - 1)) / columns;
    final cardHeight = cardWidth * 1.5 + kCardTextHeight;

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
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                            ),
                            if (_total != null)
                              Text('$_total Titel', style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        PopupMenuButton<LibrarySort>(
                          tooltip: 'Sortieren',
                          initialValue: _sort,
                          onSelected: _changeSort,
                          offset: const Offset(0, 46),
                          itemBuilder: (_) => [
                            for (final s in LibrarySort.values) PopupMenuItem(value: s, child: Text(s.label)),
                          ],
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort_rounded, size: 20),
                                const SizedBox(width: 10),
                                Text(_sort.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                const Icon(Icons.expand_more_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null && _items.isEmpty)
                  SliverToBoxAdapter(
                    child: ErrorView(message: 'Bibliothek konnte nicht geladen werden.\n$_error', onRetry: _loadMore),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: 26,
                        mainAxisExtent: cardHeight,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => PosterCard(item: _items[i], width: cardWidth),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: _loading ? const Center(child: CircularProgressIndicator()) : null,
                  ),
                ),
              ],
            ),
          ),
          TopScrim(scroll: _scroll),
        ],
      ),
    );
  }
}
