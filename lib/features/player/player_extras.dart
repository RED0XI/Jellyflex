part of 'player_screen.dart';

// Extras im Player: Kapitel mit Vorschaubildern und technische Infos.

/// Nur für Tests: Bildschirmfotos hierhin statt nach Bilder\Jellyflex.
@visibleForTesting
Directory? debugScreenshotFolder;

/// Kapitel als Bildleiste – Klick (oder Enter) springt zum Kapitel.
class _ChaptersPanel extends StatelessWidget {
  const _ChaptersPanel({
    super.key,
    required this.chapters,
    required this.imageUrl,
    required this.current,
    required this.onSelect,
  });

  final List<Chapter> chapters;

  /// Vorschaubild eines Kapitels (oder `null`).
  final String? Function(int index) imageUrl;

  /// Index des laufenden Kapitels.
  final int current;
  final ValueChanged<Chapter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 760,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xF2101219),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr.chapters, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chapters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final chapter = chapters[i];
                final url = imageUrl(i);
                final active = i == current;
                return Focusable(
                  autofocus: active,
                  onTap: () => onSelect(chapter),
                  semanticLabel: '${chapter.name} ${formatTimecode(chapter.start)}',
                  builder: (context, hovered) => SizedBox(
                    width: 176,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 99,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hovered
                                  ? Colors.white
                                  : active
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.08),
                              width: hovered || active ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (url != null)
                                JfImage(url: url)
                              else
                                Center(
                                  child: Icon(Icons.movie_filter_outlined, color: Colors.white.withValues(alpha: 0.3)),
                                ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    formatTimecode(chapter.start),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          chapter.name.isEmpty ? tr.chapterN(i + 1) : chapter.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Technische Infos zur Wiedergabe (Taste I): Codec, Auflösung, Bitrate,
/// Puffer, ausgelassene Bilder … – aktualisiert sich jede Sekunde.
class _StatsOverlay extends StatefulWidget {
  const _StatsOverlay({required this.player, required this.playMethod});

  final Player player;

  /// "Direct Play" bzw. "Umrechnung …".
  final String playMethod;

  @override
  State<_StatsOverlay> createState() => _StatsOverlayState();
}

class _StatsOverlayState extends State<_StatsOverlay> {
  static const _props = [
    'video-codec',
    'video-params/w',
    'video-params/h',
    'estimated-vf-fps',
    'container-fps',
    'video-params/gamma',
    'video-params/pixelformat',
    'hwdec-current',
    'audio-codec-name',
    'audio-params/channel-count',
    'audio-params/samplerate',
    'video-bitrate',
    'audio-bitrate',
    'demuxer-cache-duration',
    'cache-speed',
    'frame-drop-count',
    'decoder-frame-drop-count',
    'avsync',
  ];

  Timer? _timer;
  Map<String, String> _values = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final native = widget.player.platform;
    if (native is! NativePlayer) return;
    final values = <String, String>{};
    for (final p in _props) {
      try {
        values[p] = await native.getProperty(p);
      } catch (_) {}
    }
    if (mounted) setState(() => _values = values);
  }

  String _v(String key) => (_values[key] ?? '').trim();

  double? _num(String key) => double.tryParse(_v(key));

  static String _rate(double? bitsPerSecond) {
    if (bitsPerSecond == null || bitsPerSecond <= 0) return '–';
    return bitsPerSecond >= 1e6
        ? '${(bitsPerSecond / 1e6).toStringAsFixed(1)} Mbit/s'
        : '${(bitsPerSecond / 1e3).round()} kbit/s';
  }

  @override
  Widget build(BuildContext context) {
    final codec = _v('video-codec').split(' ').first;
    final fps = _num('estimated-vf-fps') ?? _num('container-fps');
    final gamma = _v('video-params/gamma');
    final hdr = gamma == 'pq' ? 'HDR10/PQ' : (gamma == 'hlg' ? 'HLG' : 'SDR');
    final hw = _v('hwdec-current');
    final channels = _v('audio-params/channel-count');
    final rate = _num('audio-params/samplerate');
    final cache = _num('demuxer-cache-duration');
    final speed = _num('cache-speed');
    final lines = <(String, String)>[
      (tr.statsPlayback, widget.playMethod),
      (
        'Video',
        [
          if (codec.isNotEmpty) codec,
          if (_v('video-params/w').isNotEmpty) '${_v('video-params/w')}×${_v('video-params/h')}',
          if (fps != null) '${fps.toStringAsFixed(fps % 1 == 0 ? 0 : 3)} fps',
          hdr,
          if (_v('video-params/pixelformat').isNotEmpty) _v('video-params/pixelformat'),
        ].join(' · '),
      ),
      (tr.statsDecoder, hw.isEmpty || hw == 'no' ? tr.statsSoftware : '${tr.statsHardware} ($hw)'),
      (
        'Audio',
        [
          if (_v('audio-codec-name').isNotEmpty) _v('audio-codec-name'),
          if (channels.isNotEmpty) '$channels ch',
          if (rate != null) '${(rate / 1000).toStringAsFixed(rate % 1000 == 0 ? 0 : 1)} kHz',
        ].join(' · '),
      ),
      ('Bitrate', 'Video ${_rate(_num('video-bitrate'))} · Audio ${_rate(_num('audio-bitrate'))}'),
      (
        tr.statsBuffer,
        [
          if (cache != null) '${cache.toStringAsFixed(1)} s',
          if (speed != null && speed > 0) '${(speed / 1024 / 1024).toStringAsFixed(1)} MB/s',
        ].join(' · '),
      ),
      (
        tr.statsDropped,
        '${_v('frame-drop-count').isEmpty ? '0' : _v('frame-drop-count')}'
            ' (Decoder ${_v('decoder-frame-drop-count').isEmpty ? '0' : _v('decoder-frame-drop-count')})',
      ),
      ('A/V-Sync', _num('avsync') == null ? '–' : '${(_num('avsync')! * 1000).toStringAsFixed(0)} ms'),
    ];
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, height: 1.55, color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.statsTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7FDBFF)),
              ),
              const SizedBox(height: 4),
              for (final (label, value) in lines)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: label.padRight(14),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      TextSpan(text: value.isEmpty ? '–' : value),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dateiname aus einem Titel: nur erlaubte Zeichen, nicht zu lang.
String _safeFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  final short = clean.length > 80 ? clean.substring(0, 80).trim() : clean;
  return short.isEmpty ? 'Jellyflex' : short;
}
