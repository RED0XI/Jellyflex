import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/live_connection.dart';
import '../theme.dart';
import '../widgets/window_frame.dart';
import 'details/details_screen.dart';
import 'home/home_providers.dart';

/// Für Meldungen von außerhalb einer Seite (z. B. "Nachricht senden" vom Handy).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Setzt Nachrichten der Live-Verbindung in der App um:
/// Daten neu laden, Fernsteuerung (Abspielen, Navigation), Mitteilungen.
class LiveHandler extends ConsumerStatefulWidget {
  const LiveHandler({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<LiveHandler> createState() => _LiveHandlerState();
}

class _LiveHandlerState extends ConsumerState<LiveHandler> {
  StreamSubscription<LiveMessage>? _subscription;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    ref.listenManual<LiveConnection?>(liveConnectionProvider, (_, connection) {
      _subscription?.cancel();
      _subscription = connection?.messages.listen(_onMessage);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  void _onMessage(LiveMessage message) {
    final data = message.data;
    switch (message.type) {
      case 'UserDataChanged' || 'LibraryChanged':
        // Mehrere Meldungen kurz hintereinander → nur einmal neu laden.
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 1500), _refresh);
      case 'Play':
        final ids = (data['ItemIds'] as List?)?.whereType<String>().toList() ?? const [];
        if (ids.isEmpty || !_safeId.hasMatch(ids.first)) return;
        final ticks = (data['StartPositionTicks'] as num?)?.toInt() ?? 0;
        _open('/play/${ids.first}${ticks > 0 ? '?start=$ticks' : ''}');
      case 'Playstate':
        final command = data['Command'] as String?;
        if (command != null) RemoteControl.onPlaystate?.call(command, data);
      case 'GeneralCommand':
        final name = data['Name'] as String?;
        final args = (data['Arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        if (name != null) _general(name, args);
    }
  }

  void _general(String name, Map<String, dynamic> args) {
    // Zuerst darf der Player (falls offen) den Befehl übernehmen.
    if (RemoteControl.onGeneral?.call(name, args) ?? false) return;
    final router = widget.router;
    switch (name) {
      case 'DisplayMessage':
        final header = args['Header'] as String?;
        final text = args['Text'] as String? ?? '';
        appMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(header == null || header.isEmpty ? text : '$header: $text'),
            behavior: SnackBarBehavior.floating,
            width: 480,
            backgroundColor: AppColors.surfaceHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            // Server bestimmt die Dauer – aber nie endlos.
            duration: Duration(milliseconds: (int.tryParse('${args['TimeoutMs']}') ?? 5000).clamp(1000, 15000)),
          ),
        );
      case 'DisplayContent':
        final id = args['ItemId'] as String?;
        if (id != null && _safeId.hasMatch(id)) _open('/item/$id');
      case 'GoHome':
        router.go('/');
      case 'GoToSearch':
        _open('/search');
      case 'GoToSettings':
        _open('/settings');
      case 'Back':
        if (router.canPop()) router.pop();
      case 'ToggleFullscreen':
        toggleWindowFullscreen();
    }
  }

  /// Kennungen vom Server landen in App-Adressen – nur harmlose Zeichen zulassen.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Seite öffnen. Läuft gerade ein Player, wird er ersetzt (die Wiedergabe endet) –
  /// so liegt nie ein Player unsichtbar unter einer anderen Seite und es entsteht
  /// kein zweiter Player.
  void _open(String location) {
    final router = widget.router;
    final inPlayer = router.routerDelegate.currentConfiguration.isNotEmpty && router.state.uri.path.startsWith('/play');
    if (inPlayer) {
      router.pushReplacement(location);
    } else {
      router.push(location);
    }
  }

  void _refresh() {
    ref.invalidate(homeProvider);
    ref.invalidate(discoverProvider);
    ref.invalidate(itemProvider);
    ref.invalidate(seriesNextUpProvider);
    ref.invalidate(episodesProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
