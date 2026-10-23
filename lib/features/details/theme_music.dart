import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/route_observer.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../core/system_certs.dart';

/// Spielt leise die Titelmusik eines Films/einer Serie, solange die
/// Detailseite sichtbar ist (falls in den Einstellungen eingeschaltet und auf
/// dem Server vorhanden). Blendet weich ein und aus – beim Verlassen der
/// Seite, beim Abspielen und wenn eine andere Seite darüber geöffnet wird.
class ThemeMusic extends ConsumerStatefulWidget {
  const ThemeMusic({super.key, required this.itemId});

  /// Film bzw. Serie (bei Folgen: die Serie).
  final String itemId;

  @override
  ConsumerState<ThemeMusic> createState() => _ThemeMusicState();
}

class _ThemeMusicState extends ConsumerState<ThemeMusic> with RouteAware {
  static const _volume = 32.0;

  Player? _player;
  Timer? _fade;
  ModalRoute<void>? _route;
  bool _visible = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(ThemeMusic old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId) {
      _stop();
      _start();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _fade?.cancel();
    _generation++;
    _player?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _visible = false;
    _stop();
  }

  @override
  void didPopNext() {
    _visible = true;
    _start();
  }

  Future<void> _start() async {
    if (!ref.read(settingsProvider).themeMusic) return;
    final generation = ++_generation;
    final api = ref.read(apiProvider);
    final song = await api.getThemeSong(widget.itemId).catchError((_) => null);
    if (song == null || !mounted || !_visible || generation != _generation) return;
    final player = _player ??= Player(configuration: const PlayerConfiguration(title: 'Jellyflex Titelmusik'));
    final native = player.platform;
    // Nur Ton – kein Bild dekodieren.
    if (native is NativePlayer) await native.setProperty('vid', 'no');
    await player.setVolume(0);
    await player.setPlaylistMode(PlaylistMode.single);
    await SystemCerts.secure(player);
    if (!mounted || generation != _generation) return;
    await player.open(Media(api.audioStreamUrl(song.id), httpHeaders: {'Authorization': api.authorizationHeader}));
    _fadeTo(_volume, const Duration(milliseconds: 1500));
  }

  void _stop() {
    _generation++;
    final player = _player;
    if (player == null) return;
    _fadeTo(0, const Duration(milliseconds: 500), then: player.stop);
  }

  void _fadeTo(double target, Duration duration, {Future<void> Function()? then}) {
    _fade?.cancel();
    final player = _player;
    if (player == null) return;
    final start = player.state.volume;
    const steps = 15;
    var step = 0;
    _fade = Timer.periodic(duration ~/ steps, (timer) {
      step++;
      player.setVolume(start + (target - start) * step / steps);
      if (step >= steps) {
        timer.cancel();
        then?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
