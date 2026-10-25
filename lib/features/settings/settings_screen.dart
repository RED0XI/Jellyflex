import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/jellyfin_api.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../screensaver/screensaver.dart';
import '../../theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/states.dart';
import '../../widgets/smooth_scroll.dart';
import '../../widgets/top_scrim.dart';
import '../home/home_providers.dart';
import '../../l10n/strings.dart';
import '../../core/format.dart';
import '../../widgets/theme_picker.dart';
import '../../widgets/layout_picker.dart';
import '../../core/image_cache.dart';
import 'about_section.dart';
import 'home_rows_dialog.dart';
import '../../core/profile_pin.dart';
import '../../widgets/pin_dialog.dart';
import '../../core/download_folder.dart';
import '../../core/downloads.dart';
import '../downloads/download_flow.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialSection});

  /// Bereich beim Öffnen (z. B. aus /settings?section=about); sonst der zuletzt gewählte.
  final SettingsSection? initialSection;

  /// Zuletzt gewählter Bereich (für diese Sitzung).
  static SettingsSection lastSection = SettingsSection.general;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();
  late final _nameController = TextEditingController(text: ref.read(settingsProvider).appName ?? '');
  final _searchController = TextEditingController();
  bool _importingLogo = false;
  late SettingsSection _section = widget.initialSection ?? SettingsScreen.lastSection;
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    _nameController.dispose();
    _searchController.dispose();
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

    final groups = <SettingsSection, List<_Section>>{
      SettingsSection.general: [
        _Section(
          title: tr.general,
          icon: Icons.tune_rounded,
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
            _Row(
              title: tr.sounds,
              subtitle: tr.soundsHint,
              trailing: _Toggle(
                value: s.soundEffects,
                onChanged: (v) => ctrl.update((s) => s.copyWith(soundEffects: v)),
              ),
            ),
          ],
        ),
        _Section(
          title: tr.account,
          icon: Icons.person_outline_rounded,
          children: [
            _Keywords(
              text: '${tr.account} ${tr.signOut} ${session?.userName ?? ''} ${session?.serverName ?? ''}',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
                      child: userImage != null
                          ? Image(image: CachedNetworkImage(userImage), fit: BoxFit.cover, width: 56, height: 56)
                          : Text(
                              (session?.userName.isNotEmpty ?? false) ? session!.userName[0].toUpperCase() : '?',
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
            ),
            _Keywords(text: '${tr.profilePin} PIN', child: const _PinRow()),
            if (session?.hasPin ?? false)
              _Row(
                title: tr.pinLock,
                subtitle: tr.pinLockHint,
                trailing: _Choice<int>(
                  value: s.pinLockMinutes,
                  label: s.pinLockMinutes == 0 ? tr.off : tr.afterMinutes(s.pinLockMinutes),
                  options: [
                    (0, tr.off),
                    for (final m in const [5, 15, 30, 60]) (m, tr.afterMinutes(m)),
                  ],
                  onChanged: (v) => ctrl.update((s) => s.copyWith(pinLockMinutes: v)),
                ),
              ),
          ],
        ),
      ],
      SettingsSection.playback: [
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
                options: [(null, tr.asInJellyfin), for (final code in settingsLanguages) (code, languageName(code))],
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
          ],
        ),
        _Section(
          title: tr.subtitleAppearance,
          icon: Icons.subtitles_outlined,
          children: [
            _Keywords(
              text: tr.subtitleAppearance,
              child: _SubtitlePreview(scale: s.subtitleScale, background: s.subtitleBackground),
            ),
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
      ],
      SettingsSection.appearance: [
        _Section(
          title: tr.personalize,
          icon: Icons.auto_awesome_outlined,
          children: [
            _Keywords(
              text: '${tr.layout} ${tr.layoutHint} ${tr.theme} ${tr.themeHint}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.layout, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(tr.layoutHint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    const LayoutPicker(),
                    const SizedBox(height: 28),
                    Text(tr.theme, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(tr.themeHint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    const ThemePicker(),
                  ],
                ),
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
              title: tr.themeMusic,
              subtitle: tr.themeMusicHint,
              trailing: _Toggle(
                value: s.themeMusic,
                onChanged: (v) => ctrl.update((s) => s.copyWith(themeMusic: v)),
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
          ],
        ),
        _Section(
          title: tr.home,
          icon: Icons.home_outlined,
          children: [
            _Row(
              title: tr.homeRows,
              subtitle: tr.homeRowsSettingsHint,
              trailing: TextButton.icon(
                onPressed: () => showHomeRowsDialog(context),
                icon: const Icon(Icons.view_agenda_outlined, size: 18),
                label: Text(tr.customize),
              ),
            ),
            _Row(
              title: tr.bannerTrailers,
              subtitle: tr.bannerTrailersHint,
              trailing: _Toggle(
                value: s.bannerTrailers,
                onChanged: (v) => ctrl.update((s) => s.copyWith(bannerTrailers: v)),
              ),
            ),
            _Row(
              title: tr.hoverPreview,
              subtitle: tr.hoverPreviewHint,
              trailing: _Toggle(
                value: s.hoverPreview,
                onChanged: (v) => ctrl.update((s) => s.copyWith(hoverPreview: v)),
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
      ],
      SettingsSection.downloads: [
        _Section(
          title: tr.downloads,
          icon: Icons.download_for_offline_outlined,
          children: [
            _Row(
              title: tr.downloadFolder,
              subtitle: tr.downloadFolderHint(ref.read(downloadsProvider.notifier).root.path),
              trailing: TextButton.icon(
                onPressed: () => changeDownloadFolder(context, ref.read),
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
                label: Text(tr.changeFolder),
              ),
            ),
            _Row(
              title: tr.unmeteredOnly,
              subtitle: tr.unmeteredOnlyHint,
              trailing: _Toggle(
                value: s.downloadsUnmeteredOnly,
                onChanged: (v) {
                  ctrl.update((s) => s.copyWith(downloadsUnmeteredOnly: v));
                  ref.read(downloadsProvider.notifier).recheckNetwork();
                },
              ),
            ),
            _Row(
              title: tr.speedLimit,
              subtitle: tr.speedLimitHint,
              trailing: _Choice<int>(
                value: s.downloadSpeedLimit,
                label: _speedLabel(s.downloadSpeedLimit),
                options: [for (final v in _speedLimits) (v, _speedLabel(v))],
                onChanged: (v) => ctrl.update((s) => s.copyWith(downloadSpeedLimit: v)),
              ),
            ),
            _Row(
              title: tr.downloadQuality,
              subtitle: tr.downloadQualityHint,
              trailing: _Choice<int?>(
                value: s.downloadQuality,
                label: qualityLabel(s.downloadQuality),
                options: qualityOptions,
                onChanged: (v) => ctrl.update((s) => s.copyWith(downloadQuality: () => v)),
              ),
            ),
            _Row(
              title: tr.askBeforeDownload,
              subtitle: tr.askBeforeDownloadHint,
              trailing: _Toggle(
                value: s.downloadAskOptions,
                onChanged: (v) => ctrl.update((s) => s.copyWith(downloadAskOptions: v)),
              ),
            ),
            _Row(
              title: tr.smartDownloads,
              subtitle: tr.smartDownloadsHint,
              trailing: _Toggle(
                value: s.smartDownloads,
                onChanged: (v) => ctrl.update((s) => s.copyWith(smartDownloads: v)),
              ),
            ),
            if (s.smartDownloads) ...[
              _Row(
                title: tr.smartEpisodes,
                subtitle: tr.smartEpisodesHint,
                trailing: _Choice<int>(
                  value: s.smartEpisodes,
                  label: '${s.smartEpisodes}',
                  options: [
                    for (final n in const [1, 2, 3, 5]) (n, '$n'),
                  ],
                  onChanged: (v) => ctrl.update((s) => s.copyWith(smartEpisodes: v)),
                ),
              ),
              _Row(
                title: tr.smartMaxSpace,
                subtitle: tr.smartMaxSpaceHint,
                trailing: _Choice<int>(
                  value: s.smartMaxGb,
                  label: s.smartMaxGb == 0 ? tr.noLimit : '${s.smartMaxGb} GB',
                  options: [
                    (0, tr.noLimit),
                    for (final gb in const [5, 10, 20, 50, 100]) (gb, '$gb GB'),
                  ],
                  onChanged: (v) => ctrl.update((s) => s.copyWith(smartMaxGb: v)),
                ),
              ),
            ],
            _Keywords(text: '${tr.downloadStorage} ${tr.deleteWatchedDownloads}', child: const _DownloadStorageRow()),
          ],
        ),
      ],
      SettingsSection.advanced: [
        _Section(
          title: tr.nameAndLogo,
          icon: Icons.badge_outlined,
          children: [
            _Keywords(
              text: '${tr.appName} ${tr.logo}',
              child: Container(
                height: 96,
                margin: const EdgeInsets.all(16),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const BrandLogo(size: 34),
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
                  decoration: const InputDecoration(hintText: defaultAppName, counterText: '', isDense: true),
                  onChanged: (v) => ctrl.update((s) => s.copyWith(appName: () => v.trim().isEmpty ? null : v.trim())),
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
              _Keywords(
                text: tr.resetToJellyflex,
                child: Padding(
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
              ),
          ],
        ),
        _Section(
          title: tr.storage,
          icon: Icons.storage_rounded,
          children: [
            _Keywords(
              text: tr.imageCache,
              child: _ImageCacheRow(
                limitMb: s.imageCacheMb,
                onLimit: (mb) => ctrl.update((s) => s.copyWith(imageCacheMb: mb)),
              ),
            ),
          ],
        ),
      ],
      SettingsSection.about: [
        _Section(
          title: tr.about,
          icon: Icons.info_outline_rounded,
          children: [
            _Keywords(
              text:
                  '${tr.appVersionLabel} ${tr.updateCheck} ${tr.autoUpdate} ${tr.licenseTitle} '
                  '${tr.perfTest} ${tr.errorReport}',
              child: AboutRows(
                row: ({required title, subtitle, required trailing}) =>
                    _Row(title: title, subtitle: subtitle, trailing: trailing),
                toggle: ({required value, required onChanged}) => _Toggle(value: value, onChanged: onChanged),
              ),
            ),
          ],
        ),
      ],
    };

    // Suche: passende Einträge aus allen Bereichen, sonst der gewählte Bereich.
    final query = _query.trim().toLowerCase();
    final List<_Section> visible;
    if (query.isEmpty) {
      visible = groups[_section]!;
    } else {
      visible = [
        for (final MapEntry(key: section, value: list) in groups.entries)
          for (final group in list)
            if (group.children.where((c) => _searchText(c).toLowerCase().contains(query)).toList() case final hits
                when hits.isNotEmpty)
              _Section(title: '${section.label} · ${group.title}', icon: group.icon, children: hits),
      ];
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visible.isEmpty)
          EmptyState(icon: Icons.search_off_rounded, title: tr.noSettingFound(_query.trim()))
        else
          ...visible,
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
    );

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
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Breites Fenster: Bereiche links als Liste; schmal: oben als Reiter.
                        final wide = box.maxWidth >= 900;
                        final nav = _SectionNav(
                          selected: query.isEmpty ? _section : null,
                          vertical: wide,
                          onSelect: _select,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PageHeader(
                              title: tr.settings,
                              padding: EdgeInsets.zero,
                              actions: [SizedBox(width: wide ? 300 : 220, child: _searchField())],
                            ),
                            const SizedBox(height: 28),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 210, child: nav),
                                  const SizedBox(width: 32),
                                  Expanded(child: content),
                                ],
                              )
                            else ...[
                              nav,
                              const SizedBox(height: 24),
                              content,
                            ],
                          ],
                        );
                      },
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

  void _select(SettingsSection section) {
    _searchController.clear();
    setState(() {
      _query = '';
      _section = section;
      SettingsScreen.lastSection = section;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: (v) => setState(() => _query = v),
    style: const TextStyle(fontSize: 15),
    decoration: InputDecoration(
      hintText: tr.searchSettings,
      isDense: true,
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: tr.clear,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );

  /// Wonach ein Eintrag gefunden wird: Titel und Erklärung der Zeile bzw. eigene Stichworte.
  static String _searchText(Widget w) => switch (w) {
    _Row(:final title, :final subtitle) => '$title ${subtitle ?? ''}',
    _Keywords(:final text) => text,
    _ => '',
  };
}

/// Bereiche der Einstellungen (auch als Adresse: /settings?section=appearance).
enum SettingsSection {
  general(Icons.tune_rounded),
  playback(Icons.play_circle_outline_rounded),
  appearance(Icons.palette_outlined),
  downloads(Icons.download_for_offline_outlined),
  advanced(Icons.build_outlined),
  about(Icons.info_outline_rounded);

  const SettingsSection(this.icon);

  final IconData icon;

  String get label => switch (this) {
    general => tr.general,
    playback => tr.playback,
    appearance => tr.appearance,
    downloads => tr.downloads,
    advanced => tr.advanced,
    about => tr.about,
  };
}

/// Auswahl der Bereiche: links als Liste oder oben als Reiter.
class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.selected, required this.vertical, required this.onSelect});

  final SettingsSection? selected;
  final bool vertical;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final section in SettingsSection.values)
        Focusable(
          onTap: () => onSelect(section),
          semanticLabel: section.label,
          builder: (context, hovered) {
            final active = section == selected;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : (hovered ? Colors.white.withValues(alpha: 0.07) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(section.icon, size: 20, color: active ? AppColors.accent : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active || hovered ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    ];
    return vertical
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: items)
        : Wrap(spacing: 6, runSpacing: 6, children: items);
  }
}

/// Eintrag ohne eigene Zeile (Vorschau, Auswahlbilder …) mit Stichworten für die Suche.
class _Keywords extends StatelessWidget {
  const _Keywords({required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
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
    return Switch(value: value, onChanged: onChanged);
  }
}

/// Geschwindigkeitsgrenzen für Downloads (Bytes/s); 0 = unbegrenzt.
const _speedLimits = [0, 6250000, 2500000, 1250000, 625000, 250000];

String _speedLabel(int bytesPerSecond) => bytesPerSecond == 0
    ? tr.unlimited
    : '${tr.decimal(bytesPerSecond * 8 / 1000000, bytesPerSecond * 8 % 1000000 == 0 ? 0 : 1)} Mbit/s';

/// Belegter Platz der Downloads, freier Platz auf dem Laufwerk, gesehene löschen.
class _DownloadStorageRow extends ConsumerWidget {
  const _DownloadStorageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(myDownloadsProvider);
    final manager = ref.read(downloadsProvider.notifier);
    final free = DownloadFolder.freeBytes(manager.root.path);
    final messenger = ScaffoldMessenger.maybeOf(context);
    void snack(String text) =>
        messenger?.showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, width: 420));

    Future<void> deleteWatched() async {
      final count = manager.watchedDownloads().where((e) => !e.needsSync).length;
      if (count == 0) {
        snack(tr.noWatchedDownloads);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(tr.deleteWatchedQuestion(count)),
          content: Text(tr.deleteWatchedText),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr.delete)),
          ],
        ),
      );
      if (ok != true) return;
      snack(tr.watchedDownloadsDeleted(await manager.removeWatched()));
    }

    return _Row(
      title: tr.downloadStorage,
      subtitle: tr.downloadStorageHint(formatBytes(manager.usedBytes), free == null ? '?' : formatBytes(free)),
      trailing: TextButton.icon(
        onPressed: deleteWatched,
        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
        label: Text(tr.deleteWatchedDownloads),
      ),
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

/// Profil-PIN festlegen, ändern oder entfernen (Ändern/Entfernen nur mit der alten PIN).
class _PinRow extends ConsumerWidget {
  const _PinRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final ctrl = ref.read(sessionProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    void snack(String text) =>
        messenger?.showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, width: 420));

    Future<bool> confirmOld() async {
      final hash = session.pinHash;
      if (hash == null) return true;
      final pin = await showPinDialog(
        context,
        title: tr.pinCurrent,
        accountKey: session.accountKey,
        check: (pin) => ProfilePin.verify(pin, hash),
      );
      return pin != null;
    }

    Future<void> change() async {
      if (!await confirmOld() || !context.mounted) return;
      final pin = await askNewPin(context);
      if (pin == null) return;
      await ctrl.setPin(await ProfilePin.hash(pin));
      snack(tr.pinSaved);
    }

    Future<void> remove() async {
      if (!await confirmOld()) return;
      await ctrl.setPin(null);
      snack(tr.pinRemoved);
    }

    return _Row(
      title: tr.profilePin,
      subtitle: session.hasPin ? tr.profilePinOnHint : tr.profilePinHint,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.hasPin) TextButton(onPressed: remove, child: Text(tr.pinRemove)),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: change,
            icon: Icon(session.hasPin ? Icons.password_rounded : Icons.lock_outline_rounded, size: 18),
            label: Text(session.hasPin ? tr.pinChange : tr.pinSet),
          ),
        ],
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
