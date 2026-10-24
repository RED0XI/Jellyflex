import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';

import '../../core/auto_refresh.dart';
import '../downloads/download_flow.dart';
import '../../core/jellyfin_api.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../../widgets/focusable.dart';
import '../../l10n/strings.dart';
import '../home/home_providers.dart';
import 'library_selection.dart';

enum LibrarySort {
  name('SortName', 'Ascending'),
  added('DateCreated,SortName', 'Descending'),
  released('PremiereDate,ProductionYear,SortName', 'Descending'),
  rating('CommunityRating,SortName', 'Descending'),
  random('Random', 'Ascending');

  const LibrarySort(this.sortBy, this.sortOrder);

  String get label => switch (this) {
    name => tr.sortTitle,
    added => tr.sortAdded,
    released => tr.sortReleased,
    rating => tr.sortRating,
    random => tr.sortRandom,
  };

  final String sortBy;
  final String sortOrder;
}

/// Aktive Filter der Bibliotheksansicht.
class LibraryFilter {
  const LibraryFilter({
    this.sort = LibrarySort.name,
    this.unplayed = false,
    this.favorites = false,
    this.genre,
    this.decade,
    this.letter,
  });

  final LibrarySort sort;
  final bool unplayed;
  final bool favorites;
  final String? genre;

  /// Startjahr des Jahrzehnts, z. B. 1990 für die 90er.
  final int? decade;

  /// Anfangsbuchstabe ("#" = Ziffern/Sonderzeichen).
  final String? letter;

  bool get hasFilters => unplayed || favorites || genre != null || decade != null || letter != null;

  LibraryFilter copyWith({
    LibrarySort? sort,
    bool? unplayed,
    bool? favorites,
    String? Function()? genre,
    int? Function()? decade,
    String? Function()? letter,
  }) => LibraryFilter(
    sort: sort ?? this.sort,
    unplayed: unplayed ?? this.unplayed,
    favorites: favorites ?? this.favorites,
    genre: genre != null ? genre() : this.genre,
    decade: decade != null ? decade() : this.decade,
    letter: letter != null ? letter() : this.letter,
  );
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
  static const _letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final _scroll = ScrollController();
  final _items = <BaseItem>[];
  int? _total;
  bool _loading = false;
  Object? _error;
  LibraryFilter _filter = const LibraryFilter();
  List<String> _genres = const [];
  int _requestId = 0;

  /// Auswahlmodus: `null` = aus, sonst die ausgewählten Kennungen.
  Set<String>? _selection;
  bool _busy = false;

  String get _includeTypes => switch (widget.collectionType) {
    'movies' => 'Movie',
    'tvshows' => 'Series',
    _ => 'Movie,Series',
  };

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _scroll.addListener(_maybeLoadMore);
    contentChanged.addListener(_reloadLoaded);
    _loadMore();
    ref
        .read(apiProvider)
        .getGenres(widget.libraryId, includeItemTypes: _includeTypes)
        .then((g) {
          if (mounted) setState(() => _genres = g);
        })
        .catchError((_) {});
  }

  /// Esc beendet den Auswahlmodus – egal, wo gerade der Fokus liegt.
  bool _onKey(KeyEvent event) {
    if (_selection == null || event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    setState(() => _selection = null);
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    contentChanged.removeListener(_reloadLoaded);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 1200) _loadMore();
  }

  Future<LibraryPage> _fetch(LibraryFilter f, {required int startIndex, required int limit}) => ref
      .read(apiProvider)
      .getLibraryPage(
        parentId: widget.libraryId,
        includeItemTypes: _includeTypes,
        sortBy: f.sort.sortBy,
        sortOrder: f.sort.sortOrder,
        startIndex: startIndex,
        limit: limit,
        filters: [if (f.unplayed) 'IsUnplayed', if (f.favorites) 'IsFavorite'],
        genre: f.genre,
        years: [
          if (f.decade != null)
            for (var y = f.decade!; y < f.decade! + 10; y++) y,
        ],
        nameStartsWith: f.letter == null || f.letter == '#' ? null : f.letter,
        nameLessThan: f.letter == '#' ? 'A' : null,
      );

  /// Neue/geänderte Titel auf dem Server: die schon geladenen Einträge still
  /// ersetzen – ohne Ladekreis und ohne die Scrollposition zu verlieren.
  Future<void> _reloadLoaded() async {
    if (_loading) return;
    // Bisher leer (z. B. Filter ohne Treffer): einfach neu laden.
    if (_items.isEmpty) {
      setState(() => _total = null);
      _loadMore();
      return;
    }
    final id = _requestId;
    final count = _items.length;
    try {
      final page = await _fetch(_filter, startIndex: 0, limit: count.clamp(_pageSize, 2000));
      // Inzwischen gefiltert oder weitergescrollt? Dann verwerfen.
      if (!mounted || id != _requestId || _loading || _items.length != count) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.totalCount;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    } catch (_) {
      // Nicht erreichbar – die alte Liste bleibt stehen.
    }
  }

  Future<void> _loadMore() async {
    if (_loading || (_total != null && _items.length >= _total!)) return;
    final id = _requestId;
    final f = _filter;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch(f, startIndex: _items.length, limit: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.totalCount;
      });
      // Falls die erste Seite den Bildschirm nicht füllt, direkt nachladen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _toggleSelect(BaseItem item) => setState(() {
    final s = _selection!;
    if (!s.remove(item.id)) s.add(item.id);
  });

  List<BaseItem> get _selected => _items.where((i) => _selection?.contains(i.id) ?? false).toList();

  /// Aktion für alle ausgewählten Titel ausführen, danach deren Daten neu laden.
  Future<void> _bulk(Future<void> Function(BaseItem item) action, String done) async {
    final items = _selected;
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    var failed = 0;
    for (final item in items) {
      try {
        await action(item);
      } catch (_) {
        failed++;
      }
      if (!mounted) return;
    }
    try {
      final fresh = await ref.read(apiProvider).getItemsByIds([for (final i in items) i.id]);
      final byId = {for (final f in fresh) f.id: f};
      if (mounted) {
        setState(() {
          for (var i = 0; i < _items.length; i++) {
            _items[i] = byId[_items[i].id] ?? _items[i];
          }
        });
      }
    } catch (_) {}
    ref.invalidate(homeProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selection = {};
    });
    messenger?.showSnackBar(
      SnackBar(content: Text(failed == 0 ? done : tr.didNotWork), behavior: SnackBarBehavior.floating, width: 420),
    );
  }

  /// Ausgewählte Filme herunterladen (mit Ordner- und Qualitätsabfrage).
  Future<void> _downloadSelected() async {
    final movies = _selected.where((i) => i.isMovie).toList();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final added = await startDownloads(context, ref.read, movies);
    if (!mounted || added == 0) return;
    setState(() => _selection = {});
    messenger?.showSnackBar(
      SnackBar(content: Text(tr.selectionDownloading), behavior: SnackBarBehavior.floating, width: 420),
    );
  }

  void _apply(LibraryFilter filter) {
    setState(() {
      _filter = filter;
      _requestId++;
      _items.clear();
      _total = null;
      _loading = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final f = _filter;
    final thisDecade = DateTime.now().year ~/ 10 * 10;

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
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                        Text(
                          _total == null ? ' ' : tr.titlesCount(_total!),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Mischt die ganze Bibliothek (Filme bzw. Folgen) – mit "Ungesehen" und Genre.
                            _ToggleChip(
                              label: tr.shufflePlay,
                              icon: Icons.shuffle_rounded,
                              active: false,
                              onTap: () => playShuffled(
                                context,
                                parentId: widget.libraryId,
                                includeItemTypes: switch (widget.collectionType) {
                                  'movies' => 'Movie',
                                  'tvshows' => 'Episode',
                                  _ => 'Movie,Episode',
                                },
                                unplayedOnly: f.unplayed,
                                genre: f.genre,
                              ),
                            ),
                            _PillMenu<LibrarySort>(
                              icon: Icons.sort_rounded,
                              label: f.sort.label,
                              active: false,
                              options: [for (final s in LibrarySort.values) (s, s.label)],
                              selected: f.sort,
                              onSelected: (s) => _apply(f.copyWith(sort: s)),
                            ),
                            _ToggleChip(
                              label: tr.unwatched,
                              icon: Icons.visibility_off_outlined,
                              active: f.unplayed,
                              onTap: () => _apply(f.copyWith(unplayed: !f.unplayed)),
                            ),
                            _ToggleChip(
                              label: tr.favorites,
                              icon: Icons.favorite_border_rounded,
                              active: f.favorites,
                              onTap: () => _apply(f.copyWith(favorites: !f.favorites)),
                            ),
                            if (_genres.isNotEmpty)
                              _PillMenu<String?>(
                                icon: Icons.theater_comedy_outlined,
                                label: f.genre ?? tr.genre,
                                active: f.genre != null,
                                options: [(null, tr.allGenres), for (final g in _genres) (g, g)],
                                selected: f.genre,
                                onSelected: (g) => _apply(f.copyWith(genre: () => g)),
                              ),
                            _PillMenu<int?>(
                              icon: Icons.calendar_month_outlined,
                              label: f.decade == null ? tr.decade : tr.decadeLabel(f.decade!),
                              active: f.decade != null,
                              options: [
                                (null, tr.allYears),
                                for (var d = thisDecade; d >= 1950; d -= 10) (d, tr.decadeLabel(d)),
                              ],
                              selected: f.decade,
                              onSelected: (d) => _apply(f.copyWith(decade: () => d)),
                            ),
                            _ToggleChip(
                              label: tr.select,
                              icon: Icons.checklist_rounded,
                              active: _selection != null,
                              onTap: () => setState(() => _selection = _selection == null ? {} : null),
                            ),
                            if (f.hasFilters)
                              TextButton.icon(
                                onPressed: () => _apply(LibraryFilter(sort: f.sort)),
                                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                                label: Text(tr.resetFilters),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // A–Z-Leiste: Klick filtert, erneuter Klick hebt auf.
                        Wrap(
                          spacing: 2,
                          children: [
                            for (final l in _letters)
                              _LetterButton(
                                letter: l,
                                active: f.letter == l,
                                onTap: () => _apply(f.copyWith(letter: () => f.letter == l ? null : l)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
                if (_error != null && _items.isEmpty)
                  SliverToBoxAdapter(
                    child: ErrorView(message: tr.libraryCouldNotLoad(_error!), onRetry: _loadMore),
                  )
                else if (!_loading && _total == 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.filter_alt_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(tr.noTitlesMatch, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                          const SizedBox(height: 16),
                          GlassButton(
                            label: tr.resetFilters,
                            icon: Icons.filter_alt_off_outlined,
                            onPressed: () => _apply(LibraryFilter(sort: f.sort)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                    // Spalten aus dem tatsächlich verfügbaren Platz berechnen.
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 22.0;
                        final width = constraints.crossAxisExtent;
                        final columns = ((width + spacing) / (kPosterWidth + spacing)).floor().clamp(2, 12);
                        final cardWidth = (width - spacing * (columns - 1)) / columns;
                        return SliverGrid.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: 26,
                            mainAxisExtent: cardWidth * 1.5 + kCardTextHeight,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final card = PosterCard(item: _items[i], width: cardWidth);
                            final selection = _selection;
                            if (selection == null) return card;
                            // Im Auswahlmodus wählt ein Klick an/ab statt zu öffnen.
                            return Stack(
                              children: [
                                ExcludeFocus(child: card),
                                Positioned.fill(
                                  child: SelectableOverlay(
                                    item: _items[i],
                                    selected: selection.contains(_items[i].id),
                                    onToggle: () => _toggleSelect(_items[i]),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
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
          if (_selection case final selection?)
            Positioned(
              left: 0,
              right: 0,
              // Über Meldungen (Snackbars) und dem Offline-Hinweis.
              bottom: 96,
              child: Center(
                child: SelectionBar(
                  count: selection.length,
                  busy: _busy,
                  onWatched: () => _bulk((i) => ref.read(apiProvider).setPlayed(i.id, true), tr.selectionMarkedWatched),
                  onUnwatched: () =>
                      _bulk((i) => ref.read(apiProvider).setPlayed(i.id, false), tr.selectionMarkedUnwatched),
                  onFavorite: () =>
                      _bulk((i) => ref.read(apiProvider).setFavorite(i.id, true), tr.selectionAddedToFavorites),
                  // Herunterladen geht nur bei Filmen (Serien über die Staffeln).
                  onDownload: _selected.any((i) => i.isMovie) ? _downloadSelected : null,
                  onSelectAll: () => setState(() => selection.addAll(_items.map((i) => i.id))),
                  onClose: () => setState(() => _selection = null),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatefulWidget {
  const _ToggleChip({required this.label, required this.icon, required this.active, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ToggleChip> createState() => _ToggleChipState();
}

class _ToggleChipState extends State<_ToggleChip> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onTap,
      builder: (context, hovered) => _Pill(
        active: widget.active,
        hovered: hovered,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.active ? Icons.check_rounded : widget.icon, size: 18),
            const SizedBox(width: 8),
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PillMenu<T> extends StatelessWidget {
  const _PillMenu({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '',
      offset: const Offset(0, 46),
      constraints: const BoxConstraints(minWidth: 200, maxHeight: 460),
      onSelected: (i) => onSelected(options[i].$1),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem(
            value: i,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: options[i].$1 == selected
                      ? Icon(Icons.check_rounded, size: 18, color: AppColors.accent)
                      : null,
                ),
                Text(options[i].$2),
              ],
            ),
          ),
      ],
      child: _Pill(
        active: active,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.active, required this.child, this.hovered = false});

  final bool active;
  final bool hovered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: hovered ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.accent : Colors.transparent),
      ),
      child: child,
    );
  }
}

class _LetterButton extends StatefulWidget {
  const _LetterButton({required this.letter, required this.active, required this.onTap});

  final String letter;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_LetterButton> createState() => _LetterButtonState();
}

class _LetterButtonState extends State<_LetterButton> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.active ? Colors.white : (hovered ? Colors.white.withValues(alpha: 0.12) : Colors.transparent),
        ),
        child: Text(
          widget.letter,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.active ? AppColors.background : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
