import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart' show DragToMoveArea;

import '../../core/downloads.dart';
import '../../core/format.dart';
import '../../core/gamepad_input.dart';
import '../../core/images.dart';
import '../../core/jellyfin_api.dart';
import '../../core/live_connection.dart';
import '../../core/media_session.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../core/sleep_timer.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/window_frame.dart';
import '../details/details_screen.dart';
import 'player_overlays.dart';
import '../../widgets/focusable.dart';
import '../../l10n/strings.dart';

part 'player_tracks_panel.dart';
part 'player_widgets.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.itemId, this.startTicks, this.restoreFullscreen, this.mediaSourceId});

  final String itemId;
  final int? startTicks;

  /// Gewählte Fassung bei mehreren Versionen; `null` = Standard (erste).
  final String? mediaSourceId;

  /// Vollbild-Zustand, der beim Schließen wiederhergestellt wird (bei "Nächste Folge"
  /// vom vorherigen Player übernommen). `null` = aktuellen Zustand nehmen.
  final bool? restoreFullscreen;

  /// Nur für den Test-Player (lib/dev): mpv vor dem Öffnen konfigurieren.
  static Future<void> Function(Player player)? debugBeforeOpen;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _seekStep = Duration(seconds: 10);
  static const _hideDelay = Duration(seconds: 3);

  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Jellyflex',
      bufferSize: 128 * 1024 * 1024,
      // Untertitel (ASS, PGS …) werden von mpv/libass originalgetreu gerendert.
      libass: true,
    ),
  );
  late final VideoController _video = VideoController(_player);
  late final JellyfinApi _api = ref.read(apiProvider);
  late final DownloadManager _downloads = ref.read(downloadsProvider.notifier);
  final _focus = FocusNode();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  BaseItem? _item;
  MediaSource? _source;
  String? _playSessionId;
  String? _error;
  List<MediaSegment> _segments = const [];

  /// Heruntergeladene Datei (statt Stream vom Server), falls vorhanden.
  String? _localFile;
  BaseItem? _nextEpisode;

  /// Höchste Bitrate; `null` = Original (Direct Play), sonst rechnet der Server um.
  int? _maxBitrate;
  bool get _transcoding => _maxBitrate != null;

  /// Gewählte Spuren als Jellyfin-Streamindex (-1 = Untertitel aus).
  int? _audioIndex;
  int? _subtitleIndex;

  List<Chapter> _chapters = const [];
  double _audioDelay = 0;
  double _subtitleDelay = 0;

  bool _controlsVisible = true;
  bool _hoveringControls = false;
  bool _trackPanelOpen = false;
  bool _playbackPanelOpen = false;
  bool get _anyPanelOpen => _trackPanelOpen || _playbackPanelOpen;
  bool _switchingToNext = false;
  bool _closing = false;
  bool _reportedStart = false;
  bool _tracksApplied = false;
  double _volumeBeforeMute = 100;
  Timer? _hideTimer;
  Timer? _progressTimer;

  /// Schlaf-Timer: Restzeit für die Anzeige, Lautstärke vor dem Ausblenden,
  /// "Gute Nacht"-Bildschirm nach dem Anhalten.
  Timer? _sleepTick;
  final _sleepLeft = ValueNotifier<Duration?>(null);
  double? _sleepVolumeBase;
  bool _sleeping = false;

  /// Vollbild ist ein gemeinsamer Zustand des Fensters (auch F11 außerhalb des Players).
  bool get _fullscreen => windowFullscreen.value;

  /// Mini-Player: kleines Fenster immer im Vordergrund (gilt auch für die nächste Folge).
  bool get _mini => windowMiniPlayer.value;

  /// Vollbild-Zustand, der beim Schließen wiederhergestellt wird.
  late final bool _restoreFullscreen = widget.restoreFullscreen ?? windowFullscreen.value;

  @override
  void initState() {
    super.initState();
    _start();
    _scheduleHide();
    _restoreFullscreen; // Zustand beim Öffnen merken.
    windowFullscreen.addListener(_onFullscreenChanged);
    windowMiniPlayer.addListener(_onFullscreenChanged);
    MediaSession.onButton = _onMediaButton;
    RemoteControl.onPlaystate = _onRemotePlaystate;
    RemoteControl.onGeneral = _onRemoteGeneral;
    GamepadInput.playerHandler = _onPad;
    SleepTimer.instance.addListener(_onSleepTimerChanged);
    _sleepTick = Timer.periodic(const Duration(seconds: 1), (_) => _checkSleepTimer());
    _checkSleepTimer();
  }

  // --- Schlaf-Timer ------------------------------------------------------------

  void _onSleepTimerChanged() {
    // Während des Ausblendens abgebrochen → Lautstärke zurück.
    if (!SleepTimer.instance.active && _sleepVolumeBase != null) {
      _player.setVolume(_sleepVolumeBase!);
      _sleepVolumeBase = null;
    }
    _sleepLeft.value = SleepTimer.instance.remaining;
    if (mounted) setState(() {});
  }

  void _checkSleepTimer() {
    final left = SleepTimer.instance.remaining;
    _sleepLeft.value = left;
    if (left == null || _closing || _sleeping || _item == null) return;
    if (left <= Duration.zero) {
      _sleepNow();
      return;
    }
    // In der letzten Minute langsam leiser werden.
    if (left <= SleepTimer.fadeOut && _player.state.playing) {
      _sleepVolumeBase ??= _player.state.volume;
      _player.setVolume(_sleepVolumeBase! * left.inMilliseconds / SleepTimer.fadeOut.inMilliseconds);
    }
  }

  /// Anhalten, Lautstärke wiederherstellen und "Gute Nacht" zeigen.
  Future<void> _sleepNow() async {
    if (_sleeping || _closing) return;
    _sleeping = true;
    await _player.pause();
    final base = _sleepVolumeBase;
    _sleepVolumeBase = null;
    if (base != null) await _player.setVolume(base);
    SleepTimer.instance.cancel();
    _reportProgress();
    if (mounted) setState(() {});
  }

  void _wakeUp() {
    setState(() => _sleeping = false);
    _player.play();
    _focus.requestFocus();
  }

  Future<void> _showSleepMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final timer = SleepTimer.instance;
    final isEpisode = _item?.isEpisode ?? false;
    _hideTimer?.cancel();
    final choice = await showMenu<int>(
      context: buttonContext,
      // Über dem Knopf öffnen (unten ist kein Platz).
      position: RelativeRect.fromLTRB(topLeft.dx - 180, topLeft.dy - 330, overlay.size.width - topLeft.dx - 40, 0),
      constraints: const BoxConstraints(minWidth: 240),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 34,
          child: Text(tr.sleepTimer, style: TextStyle(color: AppColors.textSecondary)),
        ),
        if (timer.active) PopupMenuItem(value: 0, child: Text(tr.off)),
        PopupMenuItem(
          value: -1,
          child: Row(
            children: [
              Expanded(child: Text(isEpisode ? tr.endOfThisEpisode : tr.endOfThisMovie)),
              if (timer.mode == SleepMode.endOfItem) Icon(Icons.check_rounded, size: 18, color: AppColors.accent),
            ],
          ),
        ),
        for (final m in const [15, 30, 45, 60, 90]) PopupMenuItem(value: m, child: Text(tr.inMinutes(m))),
      ],
    );
    _focus.requestFocus();
    if (_player.state.playing) _scheduleHide();
    switch (choice) {
      case null:
        return;
      case 0:
        timer.cancel();
      case -1:
        timer.setEndOfItem();
      default:
        timer.setMinutes(choice);
    }
  }

  /// Controller im Player: ←/→ spulen, A/Start Pause, B zurück, X Spuren-Panel.
  /// In offenen Panels steuert das Steuerkreuz die Auswahl.
  bool _onPad(PadAction action) {
    if (_anyPanelOpen) {
      if (action == PadAction.back || action == PadAction.menu) {
        _closePanels();
        return true;
      }
      if (action != PadAction.playPause) return false;
      _player.playOrPause();
      return true;
    }
    switch (action) {
      case PadAction.left:
        _seekBy(-_seekStep);
      case PadAction.right:
        _seekBy(_seekStep);
      case PadAction.select || PadAction.playPause:
        _player.playOrPause();
      case PadAction.back:
        _close();
      case PadAction.menu:
        _setTrackPanel(true);
        // Erste Zeile im Panel fokussieren.
        WidgetsBinding.instance.addPostFrameCallback((_) => _focus.nextFocus());
      case PadAction.up || PadAction.down || PadAction.search:
        break;
    }
    _showControls(autoHide: _player.state.playing);
    return true;
  }

  /// Fernsteuerung (z. B. vom Handy über Jellyfin).
  void _onRemotePlaystate(String command, Json data) {
    switch (command) {
      case 'Stop':
        _close();
      case 'Pause':
        _player.pause();
      case 'Unpause':
        _player.play();
      case 'PlayPause':
        _player.playOrPause();
      case 'NextTrack':
        _playNext();
      case 'Rewind':
        _seekBy(-_seekStep);
      case 'FastForward':
        _seekBy(_seekStep);
      case 'Seek':
        final ticks = (data['SeekPositionTicks'] as num?)?.toInt();
        if (ticks != null) _player.seek(ticksToDuration(ticks));
    }
    _showControls(autoHide: _player.state.playing);
  }

  bool _onRemoteGeneral(String name, Map<String, dynamic> args) {
    final volume = _player.state.volume;
    switch (name) {
      case 'SetVolume':
        _setVolume(double.tryParse('${args['Volume']}') ?? volume);
      case 'VolumeUp':
        _setVolume(volume + 5);
      case 'VolumeDown':
        _setVolume(volume - 5);
      case 'Mute':
        if (volume > 0) _toggleMute();
      case 'Unmute':
        if (volume == 0) _toggleMute();
      case 'ToggleMute':
        _toggleMute();
      case 'SetAudioStreamIndex':
        final index = int.tryParse('${args['Index']}');
        if (index == null) return true;
        _selectAudio(_transcoding ? 'jf:$index' : (_mpvIdFor(_source!, 'Audio', index) ?? ''));
      case 'SetSubtitleStreamIndex':
        final index = int.tryParse('${args['Index']}');
        if (index == null) return true;
        if (index < 0) {
          _selectSubtitle('no');
        } else if (_transcoding) {
          _selectSubtitle('jf:$index');
        } else {
          final external = _externalSubtitles.where((s) => s.index == index).firstOrNull;
          _selectSubtitle(external != null ? _subtitleUri(external) : (_mpvIdFor(_source!, 'Subtitle', index) ?? ''));
        }
      default:
        return false;
    }
    _reportProgress();
    return true;
  }

  /// Medientasten der Tastatur bzw. Windows-Medienanzeige.
  void _onMediaButton(String button) {
    switch (button) {
      case 'play':
        _player.play();
      case 'pause':
        _player.pause();
      case 'stop':
        _close();
      case 'next':
        _playNext();
    }
  }

  void _updateMediaSession() {
    final item = _item;
    if (item == null || _closing) return;
    MediaSession.update(
      title: item.isEpisode ? (item.seriesName ?? item.name) : item.name,
      subtitle: item.isEpisode ? [?item.episodeLabel, item.name].join(' · ') : yearLabel(item),
      artUrl: _api.imageUrlOrNull(Images.landscape(item), fillWidth: 480, fillHeight: 270),
      playing: _player.state.playing,
      canNext: _nextEpisode != null,
    );
  }

  void _onFullscreenChanged() {
    if (!mounted) return;
    setState(() {});
    _syncWindowChrome();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    if (!_closing && _reportedStart) {
      _api.reportPlaybackStopped(_progressBody()).ignore();
    }
    if (!_closing) _saveLocalPlayback(synced: false);
    windowFullscreen.removeListener(_onFullscreenChanged);
    windowMiniPlayer.removeListener(_onFullscreenChanged);
    // Player weg (nicht nur nächste Folge) → normales Fenster zurück.
    if (_mini && !_switchingToNext) setWindowMiniPlayer(false);
    if (RemoteControl.onPlaystate == _onRemotePlaystate) RemoteControl.onPlaystate = null;
    if (RemoteControl.onGeneral == _onRemoteGeneral) RemoteControl.onGeneral = null;
    if (GamepadInput.playerHandler == _onPad) GamepadInput.playerHandler = null;
    SleepTimer.instance.removeListener(_onSleepTimerChanged);
    _sleepTick?.cancel();
    _sleepLeft.dispose();
    if (MediaSession.onButton == _onMediaButton) {
      MediaSession.onButton = null;
      // Bei "Nächste Folge" übernimmt gleich der neue Player die Anzeige.
      if (!_switchingToNext) MediaSession.clear();
    }
    if (!_closing && windowFullscreen.value != _restoreFullscreen) setWindowFullscreen(_restoreFullscreen);
    _player.dispose();
    _focus.dispose();
    // Nicht während des Abbaus des Widget-Baums ändern.
    scheduleMicrotask(() => windowChromeVisible.value = true);
    super.dispose();
  }

  // --- Wiedergabe starten & melden -------------------------------------------

  Future<void> _start() async {
    try {
      // Heruntergeladen? Dann die lokale Datei nehmen – offline auch ohne Server.
      final download = _downloads.entryFor(widget.itemId);
      // Lokal nur, wenn nicht ausdrücklich eine andere Fassung gewählt wurde.
      final sameVersion =
          widget.mediaSourceId == null ||
          download?.mediaSourceId == null ||
          widget.mediaSourceId == download!.mediaSourceId;
      if (download != null && download.isDone && sameVersion && File(download.mediaFile!).existsSync()) {
        _localFile = download.mediaFile;
      }
      BaseItem item;
      PlaybackInfo info;
      try {
        (item, info) = await (_api.getItem(widget.itemId), _api.getPlaybackInfo(widget.itemId)).wait;
      } catch (_) {
        final local = _localFile == null ? null : download!.loadItem();
        if (local == null) rethrow;
        item = local;
        info = PlaybackInfo(const {});
      }
      final sources = info.mediaSources.isNotEmpty ? info.mediaSources : item.mediaSources;
      if (sources.isEmpty) throw Exception(tr.noPlayableFile);
      final wanted = widget.mediaSourceId ?? (_localFile != null ? download?.mediaSourceId : null);
      final source = sources.where((s) => s.id == wanted).firstOrNull ?? sources.first;
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      var maxBitrate = settings.maxBitrate;
      // Ist die Datei ohnehin kleiner als die Grenze, lohnt Umrechnen nicht.
      if (maxBitrate != null && (source.bitrate ?? 0) > 0 && source.bitrate! <= maxBitrate) maxBitrate = null;
      if (_localFile != null) maxBitrate = null; // lokal nie umrechnen
      setState(() {
        _item = item;
        _source = source;
        _playSessionId = info.playSessionId;
        _maxBitrate = maxBitrate;
        _audioIndex = _preferredAudioIndex(source);
        _subtitleIndex = _preferredSubtitleIndex(source);
        _chapters = item.chapters;
      });

      // Intro/Abspann und nächste Folge im Hintergrund nachladen.
      _api.getMediaSegments(item.id).then((s) {
        if (mounted) setState(() => _segments = s);
      });
      if (item.isEpisode) {
        _api.getNextEpisode(item).then((next) {
          // Ohne Server: nächste heruntergeladene Folge.
          next ??= _downloads.nextDownloadedEpisode(item);
          if (mounted) setState(() => _nextEpisode = next);
          _updateMediaSession();
        });
      }

      _subscriptions
        ..add(_player.stream.tracks.listen((_) => _applyDefaultTracks()))
        ..add(_player.stream.playing.listen(_onPlayingChanged))
        ..add(
          _player.stream.completed.listen((done) {
            if (!done) return;
            if (SleepTimer.instance.mode == SleepMode.endOfItem) {
              _sleepNow();
              return;
            }
            if (_nextEpisode != null && ref.read(settingsProvider).nextEpisodeCountdown) {
              _playNext();
            } else {
              _close();
            }
          }),
        )
        ..add(_player.stream.error.listen(_onPlayerError));

      final start = widget.startTicks != null ? ticksToDuration(widget.startTicks!) : null;
      await PlayerScreen.debugBeforeOpen?.call(_player);
      await _openStream(start);

      await _applySubtitleStyle();
      _updateMediaSession();

      try {
        await _api.reportPlaybackStart(_progressBody(position: start));
        _reportedStart = true;
      } catch (e) {
        debugPrint('Wiedergabestart konnte nicht gemeldet werden: $e');
      }
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _reportProgress();
        _saveLocalPlayback(synced: _reportedStart);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  /// Öffnet die Originaldatei (Direct Play) oder – mit Bitrate-Grenze – eine
  /// vom Server umgerechnete HLS-Fassung mit den gewählten Spuren.
  Future<void> _openStream(Duration? start) async {
    final item = _item!;
    final source = _source!;
    final headers = {'Authorization': _api.authorizationHeader};

    if (_localFile != null) {
      await _player.open(Media(_localFile!, start: start));
      return;
    }
    if (!_transcoding) {
      await _player.open(
        Media(
          _api.streamUrl(item.id, mediaSourceId: source.id, playSessionId: _playSessionId),
          httpHeaders: headers,
          start: start,
        ),
      );
      return;
    }

    final subIndex = (_subtitleIndex ?? -1) >= 0 ? _subtitleIndex : null;
    final info = await _api.getTranscodeInfo(
      item.id,
      mediaSourceId: source.id,
      maxBitrate: _maxBitrate!,
      audioIndex: _audioIndex,
      subtitleIndex: subIndex,
    );
    final media = info.mediaSources.firstOrNull;
    final url = media?.transcodingUrl;
    if (media == null || url == null) throw Exception(tr.noTranscodeFromServer);
    _playSessionId = info.playSessionId ?? _playSessionId;
    await _player.open(Media('${_api.baseUrl}$url', httpHeaders: headers, start: start));

    // Text-Untertitel kommen als eigene Datei, Bild-Untertitel sind eingebrannt.
    final sub = media.mediaStreams
        .where((s) => s.index == subIndex && s.deliveryMethod == 'External' && s.deliveryUrl != null)
        .firstOrNull;
    await _player.setSubtitleTrack(
      sub == null
          ? SubtitleTrack.no()
          : SubtitleTrack.uri('${_api.baseUrl}${sub.deliveryUrl}', title: sub.displayTitle, language: sub.language),
    );
  }

  /// Wechselt den Stream (Qualität oder Spur bei Umrechnung) an derselben Stelle.
  Future<void> _switchStream(VoidCallback change) async {
    final position = _player.state.position;
    final wasPlaying = _player.state.playing;
    if (_reportedStart) {
      try {
        await _api.reportPlaybackStopped(_progressBody()).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    setState(change);
    // Bei Direct Play wählt _applyDefaultTracks die Spuren neu aus _audioIndex/_subtitleIndex.
    _tracksApplied = _transcoding;
    try {
      await _openStream(position);
      if (!wasPlaying) await _player.pause();
      await _applySubtitleStyle();
      await _api.reportPlaybackStart(_progressBody(position: position));
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  /// mpv meldet auch harmlose Fehler (z. B. eine defekte Untertitelspur).
  /// Nur wenn das Video selbst nicht startet, zeigen wir eine Fehlermeldung.
  void _onPlayerError(String message) {
    debugPrint('mpv: $message');
    final lower = message.toLowerCase();
    final isSubtitle = lower.contains('sub') || lower.contains('.srt') || lower.contains('.ass');
    if (!mounted || _error != null || isSubtitle || _player.state.duration > Duration.zero) return;
    setState(() => _error = tr.fileCouldNotLoad(message));
    _showControls(autoHide: false);
  }

  /// Untertitelgröße und Hintergrund aus den Einstellungen an mpv übergeben.
  Future<void> _applySubtitleStyle() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    final s = ref.read(settingsProvider);
    final props = {
      'sub-scale': s.subtitleScale.toStringAsFixed(2),
      'sub-border-style': s.subtitleBackground ? 'background-box' : 'outline-and-shadow',
      'sub-back-color': '#B3000000',
    };
    for (final e in props.entries) {
      try {
        await native.setProperty(e.key, e.value);
      } catch (err) {
        debugPrint('mpv-Eigenschaft ${e.key} nicht gesetzt: $err');
      }
    }
  }

  Json _progressBody({Duration? position}) => {
    'ItemId': widget.itemId,
    'MediaSourceId': ?_source?.id,
    'PlaySessionId': ?_playSessionId,
    'PositionTicks': durationToTicks(position ?? _player.state.position),
    'IsPaused': !_player.state.playing,
    'IsMuted': _player.state.volume == 0,
    'VolumeLevel': _player.state.volume.round(),
    'PlayMethod': _transcoding ? 'Transcode' : 'DirectPlay',
    if (_audioIndex != null) 'AudioStreamIndex': _audioIndex,
    if (_subtitleIndex != null) 'SubtitleStreamIndex': _subtitleIndex,
    'CanSeek': true,
  };

  void _reportProgress() {
    if (!_reportedStart || _closing) return;
    _api.reportPlaybackProgress(_progressBody()).ignore();
  }

  /// Heruntergeladene Titel: Stelle auch lokal merken – für offline und zum
  /// späteren Nachmelden, falls der Server gerade nicht erreichbar ist.
  void _saveLocalPlayback({required bool synced}) {
    final item = _item;
    if (_localFile == null || item == null) return;
    final duration = _player.state.duration;
    _downloads.savePlayback(
      widget.itemId,
      positionTicks: durationToTicks(_player.state.position),
      runtimeTicks: duration > Duration.zero ? durationToTicks(duration) : item.runTimeTicks,
      synced: synced,
    );
  }

  void _onPlayingChanged(bool playing) {
    // Per Medientaste o. Ä. weitergespielt → "Gute Nacht" ausblenden.
    if (playing && _sleeping && mounted) setState(() => _sleeping = false);
    _reportProgress();
    MediaSession.setPlaying(playing);
    if (playing) {
      _scheduleHide();
    } else {
      _showControls(autoHide: false);
    }
  }

  /// Tonspur nach App-Einstellung (bevorzugte Sprache), sonst wie in Jellyfin.
  int? _preferredAudioIndex(MediaSource source) {
    final pref = ref.read(settingsProvider).audioLanguage;
    if (pref != null) {
      final match = source.embeddedStreams('Audio').where((s) => sameLanguage(s.language, pref)).firstOrNull;
      if (match != null) return match.index;
    }
    return source.defaultAudioStreamIndex;
  }

  /// Untertitel nach App-Einstellung, sonst wie in Jellyfin (-1 = aus).
  int? _preferredSubtitleIndex(MediaSource source) {
    final pref = ref.read(settingsProvider).subtitleLanguage;
    if (pref == subtitlesOff) return -1;
    if (pref != null) {
      // Vollständige Untertitel vor erzwungenen, eingebettete vor Dateien.
      final candidates =
          source.mediaStreams.where((s) => s.type == 'Subtitle' && sameLanguage(s.language, pref)).toList()
            ..sort((a, b) {
              final forced = (a.isForced ? 1 : 0) - (b.isForced ? 1 : 0);
              if (forced != 0) return forced;
              return (a.isExternal ? 1 : 0) - (b.isExternal ? 1 : 0);
            });
      if (candidates.isNotEmpty) return candidates.first.index;
    }
    return source.defaultSubtitleStreamIndex;
  }

  /// Bei Direct Play: die gewählten Spuren ([_audioIndex], [_subtitleIndex])
  /// in mpv einstellen, sobald mpv die Spuren der Datei kennt.
  void _applyDefaultTracks() {
    final source = _source;
    if (_tracksApplied || source == null || _transcoding) return;
    final tracks = _player.state.tracks;
    final audio = tracks.audio.where(_isRealTrack).toList();
    if (audio.isEmpty) return;
    _tracksApplied = true;

    final audioId = _mpvIdFor(source, 'Audio', _audioIndex);
    final audioTrack = audio.where((t) => t.id == audioId).firstOrNull;
    if (audioTrack != null) _player.setAudioTrack(audioTrack);

    final subIndex = _subtitleIndex;
    final external = _externalSubtitles.where((s) => s.index == subIndex).firstOrNull;
    if (subIndex == null || subIndex < 0) {
      _player.setSubtitleTrack(SubtitleTrack.no());
    } else if (external != null) {
      _player.setSubtitleTrack(_externalTrack(external));
    } else {
      final subId = _mpvIdFor(source, 'Subtitle', subIndex);
      final subTrack = tracks.subtitle.where((t) => t.id == subId).firstOrNull;
      if (subTrack != null) _player.setSubtitleTrack(subTrack);
    }
  }

  static bool _isRealTrack(dynamic t) => t.id != 'auto' && t.id != 'no';

  /// Untertiteldateien neben dem Video (z. B. "Film.de.srt"), die Jellyfin kennt.
  List<MediaStream> get _externalSubtitles =>
      _source?.mediaStreams.where((s) => s.type == 'Subtitle' && s.isExternal).toList() ?? const [];

  /// Externe Untertitel: bei Downloads die mitgeladene Datei, sonst vom Server.
  String _subtitleUri(MediaStream stream) {
    if (_localFile != null) {
      final file = _downloads.entryFor(widget.itemId)?.subtitleFile(stream.index);
      if (file != null) return file;
    }
    return _api.subtitleUrl(widget.itemId, _source!.id, stream);
  }

  SubtitleTrack _externalTrack(MediaStream stream) => SubtitleTrack.uri(
    _subtitleUri(stream),
    title: stream.displayTitle ?? languageName(stream.language),
    language: stream.language,
  );

  /// Jellyfin-Streamindex → mpv-Spur-ID (eingebettete Spuren, 1-basiert).
  String? _mpvIdFor(MediaSource source, String type, int? jellyfinIndex) {
    if (jellyfinIndex == null) return null;
    final streams = source.embeddedStreams(type);
    final pos = streams.indexWhere((s) => s.index == jellyfinIndex);
    return pos < 0 ? null : '${pos + 1}';
  }

  /// mpv-Spur-ID → Jellyfin-Stream (für schöne Namen wie "Deutsch - AC3 - 5.1").
  MediaStream? _jellyfinStreamFor(String type, String mpvId) {
    final source = _source;
    final n = int.tryParse(mpvId);
    if (source == null || n == null) return null;
    final streams = source.embeddedStreams(type);
    return n >= 1 && n <= streams.length ? streams[n - 1] : null;
  }

  String _trackLabel(String type, String id, String? title, String? language, String? codec) {
    final stream = _jellyfinStreamFor(type, id);
    if (stream?.displayTitle != null) return stream!.displayTitle!;
    return [?title, languageName(language), ?codec?.toUpperCase()].join(' · ');
  }

  // --- Schließen -------------------------------------------------------------

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _progressTimer?.cancel();
    final body = _progressBody();
    await _player.pause();
    var reported = false;
    if (_reportedStart) {
      try {
        await _api.reportPlaybackStopped(body).timeout(const Duration(seconds: 4));
        reported = true;
      } catch (_) {}
    }
    _saveLocalPlayback(synced: reported);
    if (_mini) await setWindowMiniPlayer(false);
    if (windowFullscreen.value != _restoreFullscreen) await setWindowFullscreen(_restoreFullscreen);
    if (!mounted) return;
    final item = _item;
    if (item != null) refreshItemData(ref, item);
    context.pop();
  }

  /// Wechselt direkt zur nächsten Folge (Vollbild bleibt erhalten).
  Future<void> _playNext() async {
    final next = _nextEpisode;
    if (next == null || _closing) return;
    _closing = true;
    _switchingToNext = true;
    _progressTimer?.cancel();
    final body = _progressBody();
    await _player.pause();
    var reported = false;
    if (_reportedStart) {
      try {
        await _api.reportPlaybackStopped(body).timeout(const Duration(seconds: 4));
        reported = true;
      } catch (_) {}
    }
    _saveLocalPlayback(synced: reported);
    if (!mounted) return;
    final item = _item;
    if (item != null) refreshItemData(ref, item);
    final ticks = next.userData.playbackPositionTicks;
    final query = Uri(queryParameters: {if (ticks > 0) 'start': '$ticks', 'rf': _restoreFullscreen ? '1' : '0'}).query;
    context.pushReplacement('/play/${next.id}?$query');
  }

  // --- Bedienelemente ein-/ausblenden ----------------------------------------

  void _showControls({bool autoHide = true}) {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _syncWindowChrome();
    }
    if (autoHide) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted || _hoveringControls || _anyPanelOpen || !_player.state.playing) return;
      setState(() => _controlsVisible = false);
      _syncWindowChrome();
    });
  }

  void _syncWindowChrome() => windowChromeVisible.value = _controlsVisible && !_fullscreen && !_mini;

  Future<void> _toggleFullscreen() async {
    if (_mini) await setWindowMiniPlayer(false);
    await toggleWindowFullscreen();
  }

  Future<void> _toggleMini() async {
    _closePanels();
    await setWindowMiniPlayer(!_mini);
    _focus.requestFocus();
  }

  void _seekBy(Duration delta) {
    final state = _player.state;
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) target = state.duration;
    _player.seek(target);
  }

  void _setVolume(double v) => _player.setVolume(v.clamp(0, 100).toDouble());

  void _toggleMute() {
    final v = _player.state.volume;
    if (v > 0) {
      _volumeBeforeMute = v;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute == 0 ? 100 : _volumeBeforeMute);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_sleeping && isDown) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.keyK) {
        _wakeUp();
        return KeyEventResult.handled;
      }
    }

    // In offenen Panels bewegen die Pfeiltasten die Auswahl, Enter wählt.
    final arrows = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.enter,
    };
    if (_anyPanelOpen && arrows.contains(key)) {
      if (node.hasPrimaryFocus && key != LogicalKeyboardKey.enter) {
        node.nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekBy(-_seekStep);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      _seekBy(_seekStep);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume(_player.state.volume + 5);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume(_player.state.volume - 5);
    } else if (isRepeat) {
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _player.playOrPause();
    } else if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyP) {
      _toggleMini();
    } else if (key == LogicalKeyboardKey.escape) {
      if (_mini) {
        _toggleMini();
      } else if (_anyPanelOpen) {
        _closePanels();
      } else if (_fullscreen) {
        _toggleFullscreen();
      } else {
        _close();
      }
    } else {
      return KeyEventResult.ignored;
    }
    _showControls(autoHide: _player.state.playing);
    return KeyEventResult.handled;
  }

  // --- Oberfläche ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Änderungen an der Untertitel-Darstellung sofort übernehmen.
    ref.listen(settingsProvider, (prev, next) {
      if (prev?.subtitleScale != next.subtitleScale || prev?.subtitleBackground != next.subtitleBackground) {
        _applySubtitleStyle();
      }
    });
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (_) => _showControls(autoHide: _player.state.playing),
          child: Stack(
            children: [
              // Ambilight: unscharfe, vergrößerte Kopie des Bildes hinter dem Video – leuchtet in
              // den Balken. Platz bleibt immer bestehen (sonst verlieren Elemente den Fokus).
              Positioned.fill(
                child: switch (settings.ambilight) {
                  _ when _mini => const SizedBox.shrink(),
                  AmbilightMode.always => _Ambilight(controller: _video),
                  AmbilightMode.window when !_fullscreen => _Ambilight(controller: _video),
                  _ => const SizedBox.shrink(),
                },
              ),
              Positioned.fill(
                child: Video(controller: _video, controls: NoVideoControls, fill: Colors.transparent),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _focus.requestFocus();
                    if (_anyPanelOpen) {
                      _closePanels();
                    } else {
                      _player.playOrPause();
                    }
                  },
                  // Im Mini-Player holt ein Doppelklick das große Fenster zurück.
                  onDoubleTap: () => _mini ? _toggleMini() : _toggleFullscreen(),
                ),
              ),
              if (_error == null)
                Center(
                  child: StreamBuilder<bool>(
                    stream: _player.stream.buffering,
                    initialData: true,
                    builder: (context, snap) => AnimatedOpacity(
                      opacity: (snap.data ?? false) ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (_error != null) Center(child: _buildError()),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: _mini ? _buildMiniControls() : _buildControls(),
                  ),
                ),
              ),
              if (_item != null && !_mini)
                PlayerSkipOverlay(
                  player: _player,
                  segments: _segments,
                  nextEpisode: _nextEpisode,
                  nextEpisodeImageUrl: _nextEpisode == null
                      ? null
                      : _api.imageUrlOrNull(Images.landscape(_nextEpisode!), fillWidth: 760, fillHeight: 428),
                  controlsVisible: _controlsVisible,
                  autoSkip: settings.autoSkipIntro,
                  // Schlaf-Timer "am Ende dieser Folge": keine nächste Folge starten.
                  autoPlayNext: settings.nextEpisodeCountdown && SleepTimer.instance.mode != SleepMode.endOfItem,
                  onSeek: (target) {
                    _player.seek(target);
                    _focus.requestFocus();
                  },
                  onPlayNext: _playNext,
                ),
              if (_sleeping)
                Positioned.fill(
                  child: _SleepOverlay(onContinue: _wakeUp, onClose: _close),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFFF6B6B)),
          const SizedBox(height: 14),
          Text(tr.playbackNotPossible, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          GlassButton(label: tr.back, icon: Icons.arrow_back_rounded, onPressed: _close),
        ],
      ),
    );
  }

  /// Vorschau beim Spulen: Trickplay-Bild (falls vorhanden), Zeit und Kapitel.
  Widget Function(Duration)? _previewBuilder() {
    final item = _item;
    final source = _source;
    if (item == null || source == null) return null;
    final info = item.trickplay(source.id);
    final headers = {'Authorization': _api.authorizationHeader};
    return (position) => info == null
        ? SeekTimeBubble(position: position, title: _chapterAt(position))
        : TrickplayPreview(
            info: info,
            position: position,
            title: _chapterAt(position),
            tileUrl: (tile) => _api.trickplayTileUrl(item.id, source.id, info.width, tile),
            headers: headers,
          );
  }

  Widget _hoverZone(Widget child) => MouseRegion(
    onEnter: (_) => _hoveringControls = true,
    onExit: (_) {
      _hoveringControls = false;
      if (_player.state.playing) _scheduleHide();
    },
    child: child,
  );

  /// Bedienung im Mini-Player: ziehen zum Verschieben, Mitte Pause, oben
  /// "Groß" und "Schließen", unten eine dünne Fortschrittsleiste.
  Widget _buildMiniControls() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0x66000000))),
        // Fenster an jeder freien Stelle verschiebbar.
        const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
        Center(
          child: StreamBuilder<bool>(
            stream: _player.stream.playing,
            initialData: _player.state.playing,
            builder: (context, snap) => _PlayerIconButton(
              icon: (snap.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: (snap.data ?? false) ? tr.pause : tr.play,
              size: 44,
              onPressed: _player.playOrPause,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              _PlayerIconButton(icon: Icons.open_in_full_rounded, tooltip: tr.bigWindow, onPressed: _toggleMini),
              _PlayerIconButton(icon: Icons.close_rounded, tooltip: tr.close, onPressed: _close),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: StreamBuilder<Duration>(
            stream: _player.stream.position,
            builder: (context, _) {
              final s = _player.state;
              final value = s.duration > Duration.zero ? s.position.inMilliseconds / s.duration.inMilliseconds : 0.0;
              return LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: AppColors.accent,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final item = _item;
    final title = item == null ? '' : (item.isEpisode ? (item.seriesName ?? item.name) : item.name);
    final subtitle = item == null
        ? null
        : item.isEpisode
        ? [?item.episodeLabel, item.name].join('  ·  ')
        : yearLabel(item);

    return Stack(
      children: [
        // Verläufe oben und unten für Lesbarkeit.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB0000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xD0000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          top: _fullscreen ? 20 : kTitleBarHeight + 8,
          left: 24,
          right: 24,
          child: _hoverZone(
            Row(
              children: [
                _PlayerIconButton(icon: Icons.arrow_back_rounded, tooltip: tr.backEsc, onPressed: _close),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 22,
          child: _hoverZone(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SeekBar(
                  player: _player,
                  previewBuilder: _previewBuilder(),
                  chapters: [for (final c in _chapters) c.start],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: _player.stream.playing,
                      initialData: _player.state.playing,
                      builder: (context, snap) => _PlayerIconButton(
                        icon: (snap.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        tooltip: (snap.data ?? false) ? tr.pauseSpace : tr.playSpace,
                        size: 40,
                        onPressed: _player.playOrPause,
                      ),
                    ),
                    _PlayerIconButton(
                      icon: Icons.replay_10_rounded,
                      tooltip: tr.rewind10,
                      onPressed: () => _seekBy(-_seekStep),
                    ),
                    _PlayerIconButton(
                      icon: Icons.forward_10_rounded,
                      tooltip: tr.forward10,
                      onPressed: () => _seekBy(_seekStep),
                    ),
                    const SizedBox(width: 4),
                    _VolumeControl(player: _player, onToggleMute: _toggleMute, onChanged: _setVolume),
                    const Spacer(),
                    StreamBuilder<Duration>(
                      stream: _player.stream.position,
                      builder: (context, _) {
                        final s = _player.state;
                        if (s.duration == Duration.zero) return const SizedBox.shrink();
                        final rate = s.rate <= 0 ? 1.0 : s.rate;
                        final remaining = (s.duration - s.position) * (1 / rate);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            tr.endsAt(formatClock(DateTime.now().add(remaining))),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                          ),
                        );
                      },
                    ),
                    if (_transcoding)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          qualityLabel(_maxBitrate).split(' · ').first,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_player.state.rate != 1.0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${_player.state.rate}×',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ListenableBuilder(
                      listenable: Listenable.merge([_sleepLeft, SleepTimer.instance]),
                      builder: (context, _) {
                        final timer = SleepTimer.instance;
                        final left = _sleepLeft.value;
                        final label = switch (timer.mode) {
                          SleepMode.off => null,
                          SleepMode.endOfItem => tr.atTheEnd,
                          SleepMode.minutes =>
                            left == null || left.inMinutes >= 1
                                ? tr.minutes(left?.inMinutes ?? 0)
                                : tr.seconds(left.inSeconds),
                        };
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (label != null)
                              Text(
                                label,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
                              ),
                            Builder(
                              builder: (buttonContext) => _PlayerIconButton(
                                icon: timer.active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                                tooltip: tr.sleepTimer,
                                onPressed: () => _showSleepMenu(buttonContext),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _PlayerIconButton(
                      icon: Icons.subtitles_rounded,
                      tooltip: tr.audioAndSubtitles,
                      onPressed: () => _setTrackPanel(!_trackPanelOpen),
                    ),
                    _PlayerIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: tr.playbackOptions,
                      onPressed: () => _setPlaybackPanel(!_playbackPanelOpen),
                    ),
                    _PlayerIconButton(
                      icon: Icons.picture_in_picture_alt_rounded,
                      tooltip: tr.miniPlayer,
                      onPressed: _toggleMini,
                    ),
                    _PlayerIconButton(
                      icon: _fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      tooltip: _fullscreen ? tr.exitFullscreen : tr.fullscreen,
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 32,
          bottom: 112,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                alignment: Alignment.bottomRight,
                child: child,
              ),
            ),
            child: _trackPanelOpen
                ? _hoverZone(
                    _TracksPanel(
                      key: const ValueKey('tracks'),
                      player: _player,
                      audioEntries: _audioEntries,
                      subtitleEntries: _subtitleEntries,
                      selectedAudio: _selectedAudioId,
                      selectedSubtitle: _selectedSubtitleId,
                      onAudio: _selectAudio,
                      onSubtitle: _selectSubtitle,
                      onClose: () => _setTrackPanel(false),
                    ),
                  )
                : _playbackPanelOpen
                ? _hoverZone(
                    PlaybackPanel(
                      key: const ValueKey('playback'),
                      rate: _player.state.rate,
                      onRate: _setRate,
                      maxBitrate: _maxBitrate,
                      onQuality: _setQuality,
                      audioDelay: _audioDelay,
                      subtitleDelay: _subtitleDelay,
                      onAudioDelay: (v) => _setDelay(audio: v),
                      onSubtitleDelay: (v) => _setDelay(subtitle: v),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  // --- Ton & Untertitel ------------------------------------------------------

  // Bei Direct Play wählt mpv die Spuren (IDs "1", "2" …). Bei Umrechnung
  // entscheidet der Server – dort heißen die Einträge "jf:<Jellyfin-Index>"
  // und ein Wechsel startet den Stream an derselben Stelle neu.

  List<_TrackEntry> _audioEntries() {
    if (_transcoding) {
      return [
        for (final s in _source?.mediaStreams.where((s) => s.type == 'Audio') ?? const <MediaStream>[])
          (id: 'jf:${s.index}', label: s.displayTitle ?? languageName(s.language)),
      ];
    }
    return [
      for (final t in _player.state.tracks.audio.where(_isRealTrack))
        (id: t.id, label: _trackLabel('Audio', t.id, t.title, t.language, t.codec)),
    ];
  }

  String? _selectedAudioId() => _transcoding ? 'jf:$_audioIndex' : _player.state.track.audio.id;

  String? _selectedSubtitleId() {
    if (_transcoding) return (_subtitleIndex ?? -1) < 0 ? 'no' : 'jf:$_subtitleIndex';
    final id = _player.state.track.subtitle.id;
    return id == 'auto' ? null : id;
  }

  List<_TrackEntry> _subtitleEntries() {
    if (_transcoding) {
      return [
        (id: 'no', label: tr.off),
        for (final s in _source?.mediaStreams.where((s) => s.type == 'Subtitle') ?? const <MediaStream>[])
          (id: 'jf:${s.index}', label: s.displayTitle ?? languageName(s.language)),
      ];
    }
    // Nur eingebettete Spuren aus mpv; nachgeladene Dateien zeigen wir separat
    // mit ihrem Jellyfin-Namen (mpv hängt sie mit fortlaufender ID hinten an).
    final embeddedCount = _source?.embeddedStreams('Subtitle').length;
    final tracks = _player.state.tracks.subtitle.where(_isRealTrack).where((t) {
      final n = int.tryParse(t.id);
      return n != null && (embeddedCount == null || embeddedCount == 0 || n <= embeddedCount);
    });
    return [
      (id: 'no', label: tr.off),
      for (final t in tracks) (id: t.id, label: _trackLabel('Subtitle', t.id, t.title, t.language, t.codec)),
      for (final s in _externalSubtitles)
        (id: _subtitleUri(s), label: '${s.displayTitle ?? languageName(s.language)}  (${tr.file})'),
    ];
  }

  void _selectAudio(String id) {
    if (id.startsWith('jf:')) {
      final index = int.parse(id.substring(3));
      if (index != _audioIndex) _switchStream(() => _audioIndex = index);
      return;
    }
    final t = _player.state.tracks.audio.where((t) => t.id == id).firstOrNull;
    if (t == null) return;
    _player.setAudioTrack(t);
    _audioIndex = _jellyfinStreamFor('Audio', id)?.index ?? _audioIndex;
  }

  void _selectSubtitle(String id) {
    if (_transcoding) {
      final index = id == 'no' ? -1 : int.parse(id.substring(3));
      if (index != _subtitleIndex) _switchStream(() => _subtitleIndex = index);
      return;
    }
    if (id == 'no') {
      _player.setSubtitleTrack(SubtitleTrack.no());
      _subtitleIndex = -1;
      return;
    }
    final ext = _externalSubtitles.where((s) => _subtitleUri(s) == id).firstOrNull;
    if (ext != null) {
      _player.setSubtitleTrack(_externalTrack(ext));
      _subtitleIndex = ext.index;
      return;
    }
    final t = _player.state.tracks.subtitle.where((t) => t.id == id).firstOrNull;
    if (t == null) return;
    _player.setSubtitleTrack(t);
    _subtitleIndex = _jellyfinStreamFor('Subtitle', id)?.index ?? _subtitleIndex;
  }

  void _setTrackPanel(bool open) {
    setState(() {
      _trackPanelOpen = open;
      if (open) _playbackPanelOpen = false;
    });
    _afterPanelChange();
  }

  void _setPlaybackPanel(bool open) {
    setState(() {
      _playbackPanelOpen = open;
      if (open) _trackPanelOpen = false;
    });
    _afterPanelChange();
  }

  void _closePanels() {
    setState(() {
      _trackPanelOpen = false;
      _playbackPanelOpen = false;
    });
    _afterPanelChange();
  }

  void _afterPanelChange() {
    if (_anyPanelOpen) {
      _showControls(autoHide: false);
    } else if (_player.state.playing) {
      _scheduleHide();
    }
    _focus.requestFocus();
  }

  // --- Geschwindigkeit, Qualität, Synchronisation ---------------------------

  Future<void> _setRate(double rate) async {
    await _player.setRate(rate);
    if (mounted) setState(() {});
  }

  void _setQuality(int? bitrate) {
    if (bitrate == _maxBitrate) return;
    _switchStream(() => _maxBitrate = bitrate);
  }

  Future<void> _setDelay({double? audio, double? subtitle}) async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    if (audio != null) {
      _audioDelay = double.parse(audio.toStringAsFixed(1));
      await native.setProperty('audio-delay', _audioDelay.toString());
    }
    if (subtitle != null) {
      _subtitleDelay = double.parse(subtitle.toStringAsFixed(1));
      await native.setProperty('sub-delay', _subtitleDelay.toString());
    }
    if (mounted) setState(() {});
  }

  /// Kapitelname an einer Position (für die Vorschau beim Spulen).
  String? _chapterAt(Duration position) {
    String? name;
    for (final c in _chapters) {
      if (c.start <= position) name = c.name;
    }
    return (name == null || name.isEmpty) ? null : name;
  }
}

// --- Bausteine ---------------------------------------------------------------
