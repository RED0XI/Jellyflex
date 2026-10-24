import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'downloads.dart';
import 'live_connection.dart';
import 'session.dart';

/// Ist der eigene Jellyfin-Server erreichbar?
///
/// Die Live-Verbindung merkt einen Abbruch sofort. Ob wirklich der Server weg
/// ist (und nicht nur die Live-Verbindung, z. B. hinter einem Proxy ohne
/// WebSocket), klärt eine kurze Anfrage an den Server. Solange er nicht
/// erreichbar ist, wird alle 15 s erneut nachgesehen.
class ServerStatus extends Notifier<bool> {
  Timer? _timer;
  bool _checking = false;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    final connection = ref.watch(liveConnectionProvider);
    if (connection == null) return true;
    void onChange() {
      if (connection.connected.value) {
        _stopChecking();
        _set(true);
      } else {
        // Kurz warten: ein kurzer Wackler soll keine Meldung auslösen.
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 3), _startChecking);
      }
    }

    connection.connected.addListener(onChange);
    ref.onDispose(() => connection.connected.removeListener(onChange));
    // Kaltstart ohne erreichbaren Server: Die Live-Verbindung kommt nie zustande, es gibt also
    // auch keinen Abbruch, der die Prüfung auslöst – deshalb nach kurzer Zeit selbst nachsehen.
    if (!connection.connected.value) _timer = Timer(const Duration(seconds: 3), _startChecking);
    return true;
  }

  /// Jetzt nachsehen (z. B. "Erneut versuchen").
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final online = await ref.read(apiProvider).ping();
      if (!ref.mounted) return;
      _set(online);
      if (online) {
        _stopChecking();
        ref.read(liveConnectionProvider)?.retryNow();
      }
    } finally {
      _checking = false;
    }
  }

  void _startChecking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
    check();
  }

  void _stopChecking() {
    _timer?.cancel();
    _timer = null;
  }

  void _set(bool online) {
    if (state == online) return;
    state = online;
    // Offline Geschautes jetzt nachmelden.
    if (online) ref.read(downloadsProvider.notifier).syncPending();
  }
}

final serverOnlineProvider = NotifierProvider<ServerStatus, bool>(ServerStatus.new);
