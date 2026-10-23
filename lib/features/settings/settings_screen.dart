import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/jellyfin_api.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../screensaver/screensaver.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../home/home_providers.dart';
import '../../l10n/strings.dart';
import '../../core/format.dart';
import '../../widgets/theme_picker.dart';
import '../../core/image_cache.dart';
import '../../core/downloads.dart' show formatBytes;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();
  late final _nameController = TextEditingController(text: ref.read(settingsProvider).appName ?? '');
  bool _importingLogo = false;

  @override
  void dispose() {
    _scroll.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: tr.images, extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp']),
      ],
    );
    if (file == null) return;
    setState(() => _importingLogo = true);
    try {
      final path = await importLogo(file.path);
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(logoPath: () => path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(tr.imageUnreadable), behavior: SnackBarBehavior.floating, width: 420));
      }
    } finally {
      if (mounted) setState(() => _importingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final session = ref.watch(sessionProvider).value;
    final userImage = ref.watch(userImageProvider).value;

    String languageLabel(String? code, {required String fallback}) {
      if (code == null) return fallback;
      if (code == subtitlesOff) return tr.off;
      return languageName(code);
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
                        Text(
                          tr.settings,
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 28),

                        _Section(
                          title: tr.language,
                          icon: Icons.translate_rounded,
                          children: [
                            _Row(
                              title: tr.appLanguage,
                              subtitle: tr.appLanguageHint,
                              trailing: _Choice<AppLanguage>(
                                value: s.language,
                                label: s.language.nativeName,
                                options: [for (final l in AppLanguage.values) (l, l.nativeName)],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(language: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: tr.playback,
                          icon: Icons.play_circle_outline_rounded,
                          children: [
                            _Row(
                              title: tr.preferredAudio,
                              subtitle: tr.preferredAudioHint,
                              trailing: _Choice<String?>(
                                value: s.audioLanguage,
                                label: languageLabel(s.audioLanguage, fallback: tr.asInJellyfin),
                                options: [
                                  (null, tr.asInJellyfin),
                                  for (final code in settingsLanguages) (code, languageName(code)),
                                ],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(audioLanguage: () => v)),
                              ),
                            ),
                            _Row(
                              title: tr.preferredSubtitles,
                              subtitle: tr.preferredSubtitlesHint,
                              trailing: _Choice<String?>(
                                value: s.subtitleLanguage,
                                label: languageLabel(s.subtitleLanguage, fallback: tr.asInJellyfin),
                                options: [
                                  (null, tr.asInJellyfin),
                                  (subtitlesOff, tr.off),
                                  for (final code in settingsLanguages) (code, languageName(code)),
                                ],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(subtitleLanguage: () => v)),
                              ),
                            ),
                            _Row(
                              title: tr.quality,
                              subtitle: tr.qualityHint,
                              trailing: _Choice<int?>(
                                value: s.maxBitrate,
                                label: qualityLabel(s.maxBitrate),
                                options: qualityOptions,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(maxBitrate: () => v)),
                              ),
                            ),
                            _Row(
                              title: tr.ambilight,
                              subtitle: tr.ambilightHint,
                              trailing: _Choice<AmbilightMode>(
                                value: s.ambilight,
                                label: switch (s.ambilight) {
                                  AmbilightMode.off => tr.off,
                                  AmbilightMode.window => tr.onlyInWindow,
                                  AmbilightMode.always => tr.always,
                                },
                                options: [
                                  (AmbilightMode.off, tr.off),
                                  (AmbilightMode.window, tr.onlyInWindow),
                                  (AmbilightMode.always, tr.alwaysInclFullscreen),
                                ],
                                onChanged: (v) => ctrl.update((s) => s.copyWith(ambilight: v)),
                              ),
                            ),
                            _Row(
                              title: tr.autoSkipIntro,
                              subtitle: tr.autoSkipIntroHint,
                              trailing: _Toggle(
                                value: s.autoSkipIntro,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(autoSkipIntro: v)),
                              ),
                            ),
                            _Row(
                              title: tr.autoplayNext,
                              subtitle: tr.autoplayNextHint,
                              trailing: _Toggle(
                                value: s.nextEpisodeCountdown,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(nextEpisodeCountdown: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: tr.subtitleAppearance,
                          icon: Icons.subtitles_outlined,
                          children: [
                            _SubtitlePreview(scale: s.subtitleScale, background: s.subtitleBackground),
                            _Row(
                              title: tr.size,
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
                              title: tr.background,
                              subtitle: tr.subtitleBackgroundHint,
                              trailing: _Toggle(
                                value: s.subtitleBackground,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(subtitleBackground: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: tr.home,
                          icon: Icons.home_outlined,
                          children: [
                            _Row(
                              title: tr.bannerTrailers,
                              subtitle: tr.bannerTrailersHint,
                              trailing: _Toggle(
                                value: s.bannerTrailers,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(bannerTrailers: v)),
                              ),
                            ),
                            _Row(
                              title: tr.screensaver,
                              subtitle: tr.screensaverHint,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: tr.showNow,
                                    onPressed: () => screensaverPreview.value++,
                                    icon: const Icon(Icons.play_circle_outline_rounded),
                                  ),
                                  const SizedBox(width: 6),
                                  _Choice<int>(
                                    value: s.screensaverMinutes,
                                    label: s.screensaverMinutes == 0 ? tr.off : tr.afterMinutes(s.screensaverMinutes),
                                    options: [
                                      (0, tr.off),
                                      for (final m in const [2, 5, 10, 15, 30]) (m, tr.afterMinutes(m)),
                                    ],
                                    onChanged: (v) => ctrl.update((s) => s.copyWith(screensaverMinutes: v)),
                                  ),
                                ],
                              ),
                            ),
                            _Row(
                              title: tr.seasonalThemes,
                              subtitle: tr.seasonalThemesHint,
                              trailing: _Toggle(
                                value: s.seasonalThemes,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(seasonalThemes: v)),
                              ),
                            ),
                            _Row(
                              title: tr.episodeImages,
                              subtitle: tr.episodeImagesHint,
                              trailing: _Toggle(
                                value: s.episodeImagesInRows,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(episodeImagesInRows: v)),
                              ),
                            ),
                          ],
                        ),

                        _Section(
                          title: tr.personalize,
                          icon: Icons.auto_awesome_outlined,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr.theme, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(tr.themeHint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 14),
                                  const ThemePicker(),
                                ],
                              ),
                            ),
                            Container(
                              height: 96,
                              margin: const EdgeInsets.all(16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const BrandLogo(size: 34),
                            ),
                            _Row(
                              title: tr.sounds,
                              subtitle: tr.soundsHint,
                              trailing: _Toggle(
                                value: s.soundEffects,
                                onChanged: (v) => ctrl.update((s) => s.copyWith(soundEffects: v)),
                              ),
                            ),
                            _Row(
                              title: tr.appName,
                              subtitle: tr.appNameHint,
                              trailing: SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _nameController,
                                  maxLength: 30,
                                  decoration: const InputDecoration(
                                    hintText: defaultAppName,
                                    counterText: '',
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      ctrl.update((s) => s.copyWith(appName: () => v.trim().isEmpty ? null : v.trim())),
                                ),
                              ),
                            ),
                            _Row(
                              title: tr.logo,
                              subtitle: tr.logoHint,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GlassButton(
                                    label: _importingLogo ? tr.loading : tr.chooseImage,
                                    icon: Icons.image_outlined,
                                    onPressed: _importingLogo ? null : _pickLogo,
                                  ),
                                  if (s.logoPath != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: tr.removeLogo,
                                      onPressed: () => ctrl.update((s) => s.copyWith(logoPath: () => null)),
                                      icon: const Icon(Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (s.appName != null || s.logoPath != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _nameController.clear();
                                      ctrl.update((s) => s.copyWith(appName: () => null, logoPath: () => null));
                                    },
                                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                    label: Text(tr.resetToJellyflex),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        _Section(
                          title: tr.storage,
                          icon: Icons.storage_rounded,
                          children: [
                            _ImageCacheRow(
                              limitMb: s.imageCacheMb,
                              onLimit: (mb) => ctrl.update((s) => s.copyWith(imageCacheMb: mb)),
                            ),
                          ],
                        ),

                        _Section(
                          title: tr.account,
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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.accentGradient,
                                    ),
                                    child: userImage != null
                                        ? Image(
                                            image: CachedNetworkImage(userImage),
                                            fit: BoxFit.cover,
                                            width: 56,
                                            height: 56,
                                          )
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
                                          style: TextStyle(color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GlassButton(
                                    label: tr.signOut,
                                    icon: Icons.logout_rounded,
                                    onPressed: () => ref.read(sessionProvider.notifier).logout(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            appDisplayName(s) == defaultAppName
                                ? 'Jellyflex ${JellyfinApi.clientVersion}'
                                : tr.basedOn(appDisplayName(s), JellyfinApi.clientVersion),
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
                  Text(subtitle!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

/// Bild-Zwischenspeicher: Obergrenze wählen, belegten Platz sehen, leeren.
class _ImageCacheRow extends StatefulWidget {
  const _ImageCacheRow({required this.limitMb, required this.onLimit});

  final int limitMb;
  final ValueChanged<int> onLimit;

  @override
  State<_ImageCacheRow> createState() => _ImageCacheRowState();
}

class _ImageCacheRowState extends State<_ImageCacheRow> {
  late Future<int> _used = ImageDiskCache.instance.sizeBytes();

  @override
  void didUpdateWidget(_ImageCacheRow old) {
    super.didUpdateWidget(old);
    // Nach dem Verkleinern der Grenze räumt der Speicher auf – kurz danach neu zählen.
    if (old.limitMb != widget.limitMb) {
      _used = Future<void>.delayed(const Duration(milliseconds: 500)).then((_) => ImageDiskCache.instance.sizeBytes());
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ImageDiskCache.instance.clear();
    if (!mounted) return;
    setState(() => _used = ImageDiskCache.instance.sizeBytes());
    messenger?.showSnackBar(SnackBar(content: Text(tr.cacheCleared), behavior: SnackBarBehavior.floating, width: 420));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _used,
      builder: (context, snapshot) => _Row(
        title: tr.imageCache,
        subtitle: tr.imageCacheHint(snapshot.hasData ? formatBytes(snapshot.data!) : '…'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(tr.clearCache),
            ),
            const SizedBox(width: 6),
            _Choice<int>(
              value: widget.limitMb,
              label: widget.limitMb == 0 ? tr.off : formatBytes(widget.limitMb * 1024 * 1024),
              options: [
                (0, tr.off),
                for (final mb in const [100, 300, 1000, 3000]) (mb, formatBytes(mb * 1024 * 1024)),
              ],
              onChanged: widget.onLimit,
            ),
          ],
        ),
      ),
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
                  child: options[i].$1 == value ? Icon(Icons.check_rounded, size: 18, color: AppColors.accent) : null,
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
          tr.subtitlePreview,
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
