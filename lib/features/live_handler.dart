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
        if (ids.isEmpty) return;
        final ticks = (data['StartPositionTicks'] as num?)?.toInt() ?? 0;
        widget.router.push('/play/${ids.first}${ticks > 0 ? '?start=$ticks' : ''}');
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
            duration: Duration(milliseconds: int.tryParse('${args['TimeoutMs']}') ?? 5000),
          ),
        );
      case 'DisplayContent':
        final id = args['ItemId'] as String?;
        if (id != null) router.push('/item/$id');
      case 'GoHome':
        router.go('/');
      case 'GoToSearch':
        router.push('/search');
      case 'GoToSettings':
        router.push('/settings');
      case 'Back':
        if (router.canPop()) router.pop();
      case 'ToggleFullscreen':
        toggleWindowFullscreen();
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
