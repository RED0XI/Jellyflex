import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/search_history.dart';
import '../../theme.dart';
import '../../widgets/focusable.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/people_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/states.dart';
import '../../widgets/top_scrim.dart';
import '../genre/genre_screen.dart';
import '../../l10n/strings.dart';

/// Was die Suche zeigt.
enum _Filter { all, movies, shows, episodes, people }

/// Suche mit Live-Ergebnissen: Filme, Serien, Folgen und Personen (z. B. nach
/// Schauspielern suchen), mit Filtern und den letzten Suchen (nur auf diesem Gerät).
/// Ohne Suchbegriff lässt sich nach Genre stöbern.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Timer? _remember;
  String _term = '';
  bool _loading = false;
  List<BaseItem> _results = const [];
  List<Person> _people = const [];
  Object? _error;
  int _requestId = 0;
  _Filter _filter = _Filter.all;
  bool _onlyUnwatched = false;

  /// Alle Genres der Bibliotheken (Kacheln zum Stöbern ohne Suchbegriff).
  List<String> _genres = const [];

  @override
  void initState() {
    super.initState();
    ref.read(apiProvider).getGenres(null).then((g) {
      if (mounted) setState(() => _genres = g);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _remember?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value.trim()));
  }

  void _rememberTerm(String term) => ref.read(searchHistoryProvider.notifier).add(term);

  void _forget(String term) => ref.read(searchHistoryProvider.notifier).remove(term);

  void _useRecent(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _search(term);
  }

  Future<void> _search(String term) async {
    if (term == _term) return;
    final id = ++_requestId;
    _remember?.cancel();
    setState(() {
      _term = term;
      _error = null;
      _loading = term.isNotEmpty;
      if (term.isEmpty) {
        _results = const [];
        _people = const [];
      }
    });
    if (term.isEmpty) return;
    final api = ref.read(apiProvider);
    try {
      final (results, people) = await (
        api.search(term),
        // Personen sind ein Zusatz – ohne sie geht die Suche trotzdem.
        api.searchPeople(term).catchError((_) => const <Person>[]),
      ).wait;
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _people = people;
      });
      // Erst merken, wenn der Begriff eine Weile stehen bleibt (nicht jeden Tippschritt).
      if (results.isNotEmpty || people.isNotEmpty) {
        _remember = Timer(const Duration(seconds: 2), () => _rememberTerm(term));
      }
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool show(_Filter f) => _filter == _Filter.all || _filter == f;
    final visible = _onlyUnwatched ? _results.where((i) => !i.userData.played).toList() : _results;
    final movies = show(_Filter.movies) ? visible.where((i) => i.isMovie).toList() : const <BaseItem>[];
    final series = show(_Filter.shows) ? visible.where((i) => i.isSeries).toList() : const <BaseItem>[];
    final episodes = show(_Filter.episodes) ? visible.where((i) => i.isEpisode).toList() : const <BaseItem>[];
    final people = show(_Filter.people) ? _people : const <Person>[];
    final nothing = movies.isEmpty && series.isEmpty && episodes.isEmpty && people.isEmpty;
    final posterHeight = kPosterWidth * 1.5 + kCardTextHeight;
    final landscapeHeight = kLandscapeWidth * 9 / 16 + kCardTextHeight;
    final recent = ref.watch(searchHistoryProvider);

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
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 16),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: (v) {
                        _search(v.trim());
                        _rememberTerm(v.trim());
                      },
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: tr.searchHint,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 18, right: 10),
                          child: Icon(Icons.search_rounded, size: 30),
                        ),
                        suffixIcon: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              )
                            : _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: tr.clear,
                                onPressed: () {
                                  _controller.clear();
                                  _search('');
                                },
                              ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 22),
                      ),
                    ),
                  ),
                ),
                if (_term.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final (f, label) in [
                            (_Filter.all, tr.filterAll),
                            (_Filter.movies, tr.movies),
                            (_Filter.shows, tr.shows),
                            (_Filter.episodes, tr.episodes),
                            (_Filter.people, tr.people),
                          ])
                            _Chip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                          const SizedBox(width: 12),
                          _Chip(
                            label: tr.onlyUnwatched,
                            icon: _onlyUnwatched ? Icons.check_rounded : Icons.visibility_off_outlined,
                            selected: _onlyUnwatched,
                            onTap: () => setState(() => _onlyUnwatched = !_onlyUnwatched),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: EmptyState(icon: Icons.cloud_off_rounded, title: tr.searchFailed(_error!)),
                  )
                else if (_term.isEmpty)
                  SliverToBoxAdapter(
                    child: recent.isEmpty && _genres.isEmpty
                        ? EmptyState(
                            icon: Icons.movie_filter_rounded,
                            title: tr.whatDoYouFeelLike,
                            hint: tr.searchEmptyHint,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recent.isNotEmpty)
                                _RecentSearches(terms: recent, onUse: _useRecent, onRemove: _forget),
                              if (_genres.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(kPageGutter, recent.isEmpty ? 16 : 34, kPageGutter, 48),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr.browseByGenre,
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(tr.browseByGenreHint, style: TextStyle(color: AppColors.textSecondary)),
                                      const SizedBox(height: 18),
                                      GenreTiles(genres: _genres),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  )
                else if (!_loading && nothing)
                  SliverToBoxAdapter(
                    child: EmptyState(icon: Icons.search_off_rounded, title: tr.nothingFoundFor(_term)),
                  )
                else
                  SliverList.list(
                    children: [
                      if (people.isNotEmpty) PeopleRow(title: tr.people, people: people),
                      if (movies.isNotEmpty)
                        MediaRow(
                          title: tr.movies,
                          itemCount: movies.length,
                          height: posterHeight,
                          itemBuilder: (context, i) => PosterCard(item: movies[i]),
                        ),
                      if (series.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        MediaRow(
                          title: tr.shows,
                          itemCount: series.length,
                          height: posterHeight,
                          itemBuilder: (context, i) => PosterCard(item: series[i]),
                        ),
                      ],
                      if (episodes.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        MediaRow(
                          title: tr.episodes,
                          itemCount: episodes.length,
                          height: landscapeHeight,
                          itemBuilder: (context, i) => LandscapeCard(item: episodes[i]),
                        ),
                      ],
                      const SizedBox(height: 72),
                    ],
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

/// Letzte Suchen als Chips – Klick sucht erneut, × entfernt; "Verlauf löschen".
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.terms, required this.onUse, required this.onRemove});

  final List<String> terms;
  final ValueChanged<String> onUse;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 12, kPageGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(tr.recentSearches, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                child: Text(tr.clearHistory),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in terms)
                _Chip(
                  label: term,
                  selected: false,
                  onTap: () => onUse(term),
                  trailing: IconButton(
                    tooltip: tr.removeSearch(term),
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: () => onRemove(term),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.white.withValues(alpha: hovered ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: hovered && !selected ? AppColors.accent : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? AppColors.background : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.background : AppColors.textPrimary,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
