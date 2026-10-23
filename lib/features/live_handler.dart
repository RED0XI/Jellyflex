import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_lock.dart';
import '../core/app_shell.dart';
import '../core/auto_refresh.dart';
import '../core/downloads.dart';
import '../core/lists.dart';
import '../core/live_connection.dart';
import '../core/session.dart';
import '../core/server_status.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/window_frame.dart';
import 'details/details_screen.dart';
import 'home/home_providers.dart';
import 'person/person_screen.dart';

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

class _LiveHandlerState extends ConsumerState<LiveHandler> with WindowListener {
  /// Ohne Live-Verbindung (z. B. Proxy ohne WebSocket) so oft selbst nachsehen.
  static const _pollInterval = Duration(minutes: 5);
  static const _staleAfter = Duration(minutes: 2);

  StreamSubscription<LiveMessage>? _subscription;
  Timer? _refreshDebounce;
  Timer? _poll;
  LiveConnection? _connection;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _poll = Timer.periodic(_pollInterval, (_) {
      // Die Live-Verbindung meldet Änderungen selbst – nur ohne sie nachsehen.
      if (_connection?.connected.value ?? false) return;
      if (ref.read(serverOnlineProvider)) _refreshIfStale();
    });
    // Sprungliste der Taskleiste: Klick setzt einen Titel fort.
    AppShell.listen(_resume);
    ref.listenManual(sessionProvider, (_, session) {
      final signedIn = session.value != null;
      // Abgemeldet: Titel nicht mehr in der Taskleiste zeigen.
      if (!signedIn) AppShell.setJumpList(tr.continueWatching, const []);
      if (signedIn && AppShell.pendingResumeId != null) {
        final id = AppShell.pendingResumeId!;
        AppShell.pendingResumeId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _resume(id));
      }
    }, fireImmediately: true);
    ref.listenManual<LiveConnection?>(liveConnectionProvider, (_, connection) {
      _subscription?.cancel();
      _subscription = connection?.messages.listen(_onMessage);
      _connection?.connected.removeListener(_onConnectedChanged);
      _connection = connection;
      connection?.connected.addListener(_onConnectedChanged);
    }, fireImmediately: true);
    // Wieder erreichbar: Daten neu laden.
    ref.listenManual<bool>(serverOnlineProvider, (was, online) {
      if (was == false && online) {
        _refresh();
        appMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(tr.backOnline),
            behavior: SnackBarBehavior.floating,
            width: 420,
            backgroundColor: AppColors.surfaceHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _connection?.connected.removeListener(_onConnectedChanged);
    _subscription?.cancel();
    _refreshDebounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// Live-Verbindung steht wieder: Meldungen aus der Zwischenzeit fehlen → neu laden.
  /// (Ganz offline → online übernimmt der Hinweis "Wieder verbunden" unten.)
  bool _wasConnected = false;
  void _onConnectedChanged() {
    final now = _connection?.connected.value ?? false;
    if (now && !_wasConnected && ref.read(serverOnlineProvider)) _refreshIfStale();
    _wasConnected = now;
  }

  void _onMessage(LiveMessage message) {
    final data = message.data;
    switch (message.type) {
      case 'UserDataChanged' || 'LibraryChanged':
        // Mehrere Meldungen kurz hintereinander → nur einmal neu laden.
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 1500), _refresh);
        // Woanders gesehen (z. B. auf dem Fernseher)? Smart Downloads nachziehen.
        if (message.type == 'UserDataChanged') ref.read(downloadsProvider.notifier).runSmartSoon();
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
    if (appLocked.value && name != 'DisplayMessage') return;
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

  /// Titel aus der Sprungliste fortsetzen (an der gemerkten Stelle).
  Future<void> _resume(String id) async {
    if (ref.read(sessionProvider).value == null) {
      AppShell.pendingResumeId = id;
      return;
    }
    final account = ref.read(sessionProvider).value?.accountKey;
    try {
      final item = await ref.read(apiProvider).getItem(id);
      // Inzwischen ein anderes Profil? Dann nichts öffnen.
      if (!mounted || ref.read(sessionProvider).value?.accountKey != account) return;
      final ticks = item.userData.playbackPositionTicks;
      _open('/play/${item.id}${ticks > 0 ? '?start=$ticks' : ''}');
    } catch (e) {
      debugPrint('Fortsetzen aus der Sprungliste nicht möglich: $e');
    }
  }

  /// Kennungen vom Server landen in App-Adressen – nur harmlose Zeichen zulassen.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Seite öffnen. Läuft gerade ein Player, wird er ersetzt (die Wiedergabe endet) –
  /// so liegt nie ein Player unsichtbar unter einer anderen Seite und es entsteht
  /// kein zweiter Player.
  void _open(String location) {
    // Gesperrt (PIN nach Inaktivität): nichts von außen öffnen oder abspielen.
    if (appLocked.value) return;
    final router = widget.router;
    final inPlayer = router.routerDelegate.currentConfiguration.isNotEmpty && router.state.uri.path.startsWith('/play');
    if (inPlayer) {
      router.pushReplacement(location);
    } else {
      router.push(location);
    }
  }

  void _refresh() {
    _lastRefresh = DateTime.now();
    ref.invalidate(homeProvider);
    ref.invalidate(discoverProvider);
    ref.invalidate(libraryViewsProvider);
    ref.invalidate(itemProvider);
    ref.invalidate(seriesNextUpProvider);
    ref.invalidate(seasonsProvider);
    ref.invalidate(episodesProvider);
    ref.invalidate(collectionItemsProvider);
    ref.invalidate(personItemsProvider);
    ref.invalidate(personEpisodesProvider);
    ref.invalidate(watchlistProvider);
    ref.invalidate(playlistsProvider);
    ref.invalidate(playlistItemsProvider);
    contentChanged.value++;
  }

  /// Nur neu laden, wenn das letzte Mal schon etwas her ist (z. B. beim
  /// Zurückkehren ins Fenster – nicht bei jedem kurzen Wechsel).
  void _refreshIfStale() {
    if (ref.read(sessionProvider).value == null) return;
    if (DateTime.now().difference(_lastRefresh) < _staleAfter) return;
    _refresh();
  }

  // Fenster bekommt den Fokus zurück → nachsehen, was neu ist.
  @override
  void onWindowFocus() => _refreshIfStale();

  @override
  Widget build(BuildContext context) => widget.child;
}
