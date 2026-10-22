import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/jellyfin_api.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../home/home_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final session = ref.watch(sessionProvider).value;
    final userImage = ref.watch(userImageProvider).value;

    String languageLabel(String? code, {required String fallback}) {
      if (code == null) return fallback;
      if (code == subtitlesOff) return 'Aus';
      return settingsLanguages[code] ?? code;
    }

    return Scaffold(
      body: Stack(
        children: [
          SmoothScroll(
            controller: _scroll,
            builder: (context, physics) => ListView(
              controller: _scroll,
              physics: physics,
              padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 72),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Einstellungen',
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 28),

                        _Section(
                          title: 'Wiedergabe',
                          icon: Icons.play_circle_outline_rounded,
                          children: [
                            _Row(
                              title: 'Bevorzugte Tonspur',
                              subtitle: 'Wird beim Start gewählt, falls vorhanden.',
                              trailing: _Choice<String?>(
                                value: s.audioLanguage,
                                label: languageLabel(s.audioLanguage, fallback: 'Wie in Jellyfin'),
                                options: [
                                  (null, 'Wie in Jellyfin'),
                                  for (final e in settingsLanguages.entries) (e.key, e.value),
                                ],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(audioLanguage: () => v)),
                              ),
                            ),
                            _Row(
                              title: 'Bevorzugte Untertitel',
                              subtitle: 'Vollständige Untertitel werden vor erzwungenen gewählt.',
                              trailing: _Choice<String?>(
                                value: s.subtitleLanguage,
                                label: languageLabel(s.subtitleLanguage, fallback: 'Wie in Jellyfin'),
                                options: [
                                  (null, 'Wie in Jellyfin'),
                                  (subtitlesOff, 'Aus'),
                                  for (final e in settingsLanguages.entries) (e.key, e.value),
                                ],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(subtitleLanguage: () => v)),
                              ),
                            ),
                            _Row(
                              title: 'Qualität',
                              subtitle:
                                  'Original spielt die Datei direkt ab. Niedrigere Stufen lassen den '
                                  'Server umrechnen – gut bei langsamer Verbindung.',
                              trailing: _Choice<int?>(
                                value: s.maxBitrate,
                                label: qualityLabel(s.maxBitrate),
                                options: qualityOptions,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(maxBitrate: () => v)),
                              ),
                            ),
                            _Row(
                              title: 'Intro & Rückblick automatisch überspringen',
                              subtitle: 'Aus: Es erscheint nur der Knopf „Intro überspringen“.',
                              trailing: _Toggle(
                                value: s.autoSkipIntro,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(autoSkipIntro: v)),
                              ),
                            ),
                            _Row(
                              title: 'Nächste Folge automatisch abspielen',
                              subtitle: 'Mit Countdown am Ende einer Folge.',
                              trailing: _Toggle(
                                value: s.nextEpisodeCountdown,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(nextEpisodeCountdown: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: 'Untertitel-Darstellung',
                          icon: Icons.subtitles_outlined,
                          children: [
                            _SubtitlePreview(scale: s.subtitleScale, background: s.subtitleBackground),
                            _Row(
                              title: 'Größe',
                              subtitle: '${(s.subtitleScale * 100).round()} %',
                              trailing: SizedBox(
                                width: 260,
                                child: Slider(
                                  value: s.subtitleScale,
                                  min: 0.6,
                                  max: 1.8,
                                  divisions: 12,
                                  onChanged: (v) => ctrl.update((s) => s.copyWith(subtitleScale: v)),
                                ),
                              ),
                            ),
                            _Row(
                              title: 'Hintergrund',
                              subtitle: 'Halbtransparenter Kasten hinter dem Text.',
                              trailing: _Toggle(
                                value: s.subtitleBackground,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(subtitleBackground: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: 'Startseite',
                          icon: Icons.home_outlined,
                          children: [
                            _Row(
                              title: 'Episodenbilder bei „Weiterschauen“',
                              subtitle: 'Aus: Statt des Standbilds der Folge das Bild der Serie zeigen.',
                              trailing: _Toggle(
                                value: s.episodeImagesInRows,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(episodeImagesInRows: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: 'Konto',
                          icon: Icons.person_outline_rounded,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.accentGradient,
                                    ),
                                    child: userImage != null
                                        ? Image.network(userImage, fit: BoxFit.cover, width: 56, height: 56)
                                        : Text(
                                            (session?.userName.isNotEmpty ?? false)
                                                ? session!.userName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session?.userName ?? '',
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          '${session?.serverName ?? ''} · ${session?.serverUrl ?? ''}',
                                          style: const TextStyle(color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GlassButton(
                                    label: 'Abmelden',
                                    icon: Icons.logout_rounded,
                                    onPressed: () => ref.read(sessionProvider.notifier).logout(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Jellyflex ${JellyfinApi.clientVersion}',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accent),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, required this.trailing});

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          trailing,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.accent,
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({required this.value, required this.label, required this.options, required this.onChanged});

  final T value;
  final String label;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '',
      offset: const Offset(0, 46),
      constraints: const BoxConstraints(minWidth: 220, maxHeight: 420),
      onSelected: (i) => onChanged(options[i].$1),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: options[i].$1 == value
                      ? const Icon(Icons.check_rounded, size: 18, color: AppColors.accent)
                      : null,
                ),
                Text(options[i].$2),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Vorschau, wie Untertitel mit der gewählten Größe aussehen.
class _SubtitlePreview extends StatelessWidget {
  const _SubtitlePreview({required this.scale, required this.background});

  final double scale;
  final bool background;

  @override
  Widget build(BuildContext context) {
    const baseSize = 22.0;
    return Container(
      height: 150,
      margin: const EdgeInsets.all(16),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFF6B4E71), Color(0xFFB0735C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background ? Colors.black.withValues(alpha: 0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'So sehen deine Untertitel aus.',
          style: TextStyle(
            fontSize: baseSize * scale,
            fontWeight: FontWeight.w600,
            shadows: background ? null : const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
          ),
        ),
      ),
    );
  }
}
