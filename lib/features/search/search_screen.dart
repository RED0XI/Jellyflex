import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../../l10n/strings.dart';

/// Suche mit Live-Ergebnissen, gruppiert nach Filmen, Serien und Folgen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _term = '';
  bool _loading = false;
  List<BaseItem> _results = const [];
  Object? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value.trim()));
  }

  Future<void> _search(String term) async {
    if (term == _term) return;
    final id = ++_requestId;
    setState(() {
      _term = term;
      _error = null;
      _loading = term.isNotEmpty;
      if (term.isEmpty) _results = const [];
    });
    if (term.isEmpty) return;
    try {
      final results = await ref.read(apiProvider).search(term);
      if (!mounted || id != _requestId) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movies = _results.where((i) => i.isMovie).toList();
    final series = _results.where((i) => i.isSeries).toList();
    final episodes = _results.where((i) => i.isEpisode).toList();
    const posterHeight = kPosterWidth * 1.5 + kCardTextHeight;
    const landscapeHeight = kLandscapeWidth * 9 / 16 + kCardTextHeight;

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
                    padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 28),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: (v) => _search(v.trim()),
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
                if (_error != null)
                  SliverToBoxAdapter(
                    child: _Hint(icon: Icons.cloud_off_rounded, text: tr.searchFailed(_error!)),
                  )
                else if (_term.isEmpty)
                  SliverToBoxAdapter(
                    child: _Hint(icon: Icons.movie_filter_rounded, text: tr.whatDoYouFeelLike),
                  )
                else if (!_loading && _results.isEmpty)
                  SliverToBoxAdapter(
                    child: _Hint(icon: Icons.search_off_rounded, text: tr.nothingFoundFor(_term)),
                  )
                else
                  SliverList.list(
                    children: [
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

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
