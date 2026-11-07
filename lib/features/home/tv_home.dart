part of 'home_screen.dart';

/// Startseite am Fernseher (wie Google TV / Netflix): oben Bild und Infos des Titels, dessen
/// Karte gerade den Fokus hat – das wechselt beim Wandern durch die Reihen; darunter die Reihen.
/// Kein selbst weiterblätterndes Banner, keine Trailer – ruhig und flüssig auf TV-Chips.
class _TvHome extends ConsumerStatefulWidget {
  const _TvHome({required this.rows});

  final List<Widget> rows;

  @override
  ConsumerState<_TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends ConsumerState<_TvHome> {
  final _scroll = TvAnchoredScrollController();

  /// Titel oben – folgt [tvFocusedItem] mit kurzer Verzögerung, damit beim schnellen Durchwandern
  /// nicht jedes Bild geladen wird.
  BaseItem? _shown;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    _shown = tvFocusedItem.value;
    tvFocusedItem.addListener(_onFocusedItem);
  }

  @override
  void dispose() {
    tvFocusedItem.removeListener(_onFocusedItem);
    _settle?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onFocusedItem() {
    _settle?.cancel();
    final next = tvFocusedItem.value;
    // Der erste Titel sofort, danach erst, wenn der Fokus kurz stehen bleibt.
    if (_shown == null) return setState(() => _shown = next);
    _settle = Timer(const Duration(milliseconds: 220), () {
      if (mounted && next != _shown) setState(() => _shown = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final api = ref.watch(apiProvider);
    final item = _shown;
    final backdrop = item == null ? null : Images.backdrop(item);
    final infoHeight = size.height * 0.46;
    return PopScope(
      // Zurück auf der Startseite: erst in die Menüleiste, von dort verlässt ein zweites Zurück die App.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        tvMenuFocused() ? SystemNavigator.pop() : tvFocusMenu();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Bild des fokussierten Titels oben rechts, weich in den Hintergrund auslaufend.
            Positioned(
              top: 0,
              right: 0,
              width: size.width * 0.74,
              height: size.height * 0.7,
              // Eigene Ebene: Scrollen der Reihen zeichnet das Bild nicht neu. Bild höchstens 1280 px
              // breit (liegt ohnehin unter Verläufen) – große Bilder dekodieren auf TV-Chips spürbar.
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: KeyedSubtree(
                    key: ValueKey(backdrop),
                    child: backdrop == null
                        ? const SizedBox.expand()
                        : JfImage(
                            url: api.imageUrlOrNull(backdrop, maxWidth: 1280),
                            // Kein Blurhash: der würde bei jedem Fokuswechsel neu berechnet.
                            placeholderColor: Colors.transparent,
                            alignment: Alignment.topCenter,
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              width: size.width * 0.74,
              height: size.height * 0.7,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
                      stops: const [0, 0.45],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
                        stops: const [0, 0.5],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: infoHeight,
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(48, 44, size.width * 0.42, 12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
                      child: item == null ? const SizedBox.shrink() : _TvInfo(key: ValueKey(item.id), item: item),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    // Platz unten, damit auch die letzte Reihe in die Mitte rücken kann.
                    padding: EdgeInsets.only(bottom: size.height * 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final row in widget.rows)
                          _TvRowAnchor(
                            scroll: _scroll,
                            child: Padding(padding: const EdgeInsets.only(bottom: 18), child: row),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hält die Reihe mit dem Fokus direkt unter den Infos – so steht die gerade gewählte Reihe immer
/// an derselben Stelle, statt dass die Seite bei jedem Schritt anders mitläuft.
class _TvRowAnchor extends StatelessWidget {
  const _TvRowAnchor({required this.scroll, required this.child});

  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) return;
        // Nach dem Scrollen der Karte selbst (Focusable) – sonst überschreibt es dieses hier.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final object = context.findRenderObject();
          if (object == null || !scroll.hasClients) return;
          scroll.position.ensureVisible(
            object,
            alignment: 0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        });
      },
      child: child,
    );
  }
}

/// Infos zum fokussierten Titel: Logo bzw. Name, Eckdaten, Genres, Inhalt.
class _TvInfo extends ConsumerWidget {
  const _TvInfo({super.key, required this.item});

  final BaseItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    // Folgen: Logo und Name der Serie, darunter Staffel/Folge und Titel der Folge.
    final episode = item.isEpisode;
    final logo = api.imageUrlOrNull(Images.logo(item), maxWidth: 700);
    const shadow = [Shadow(color: Colors.black87, blurRadius: 14)];
    final meta = <String>[
      if (episode) ?item.episodeLabel,
      ?yearLabel(item),
      if (item.runtime != null && !item.isSeries) formatRuntime(item.runtime!),
      if (item.isSeries && item.childCount != null) tr.seasonsCount(item.childCount!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TitleLogo(
          logoUrl: logo,
          title: episode ? (item.seriesName ?? item.name) : item.name,
          maxHeight: 92,
          fontSize: 40,
        ),
        if (episode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, shadows: shadow),
            ),
          ),
        const SizedBox(height: 12),
        DefaultTextStyle.merge(
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, shadows: shadow),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.communityRating != null) RatingBadges(item: item, critics: false),
              for (final m in meta) Text(m),
              if (item.officialRating != null) RatingBadge(item.officialRating!),
              if (item.genres.isNotEmpty)
                Text(item.genres.take(3).join(' · '), style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (item.overview case final overview? when overview.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            overview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFDADCE5), shadows: shadow),
          ),
        ],
      ],
    );
  }
}
