import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_api.dart';
import 'models.dart';
import 'session.dart';

/// Nachricht vom Server über die Live-Verbindung (WebSocket).
class LiveMessage {
  const LiveMessage(this.type, this.data);

  /// z. B. "UserDataChanged", "Playstate", "GeneralCommand", "Play".
  final String type;
  final Json data;
}

/// Hält eine WebSocket-Verbindung zum Jellyfin-Server offen:
/// - der Server meldet Änderungen (z. B. auf anderem Gerät weitergeschaut)
/// - andere Geräte können die App fernsteuern (Abspielen, Pause, Lautstärke …)
///
/// Bricht die Verbindung ab, wird mit wachsender Wartezeit neu verbunden.
class LiveConnection {
  LiveConnection(this.api);

  final JellyfinApi api;
  final _messages = StreamController<LiveMessage>.broadcast();
  WebSocket? _socket;
  Timer? _keepAlive;
  Timer? _reconnect;
  bool _closed = false;
  int _attempt = 0;

  Stream<LiveMessage> get messages => _messages.stream;
  bool get isConnected => _socket != null;

  /// Ob die Verbindung gerade steht (für die Anzeige "Server nicht erreichbar").
  final connected = ValueNotifier<bool>(false);

  /// Nicht auf die nächste Wartezeit warten, sondern sofort neu verbinden.
  void retryNow() {
    if (_closed || isConnected) return;
    _reconnect?.cancel();
    _attempt = 0;
    _connect();
  }

  void start() => _connect();

  /// Zählt Verbindungen – Meldungen alter Verbindungen werden ignoriert.
  int _generation = 0;
  StreamSubscription<dynamic>? _subscription;

  Future<void> _connect() async {
    if (_closed) return;
    final generation = ++_generation;
    WebSocket? socket;
    try {
      // Anmeldung nur über den Authorization-Kopf – ein Token in der Adresse
      // landet sonst in Protokollen von Proxys (z. B. nginx).
      final query = Uri(queryParameters: {'deviceId': api.deviceId}).query;
      final url = '${api.baseUrl.replaceFirst(RegExp('^http', caseSensitive: false), 'ws')}/socket?$query';
      socket = await WebSocket.connect(url, headers: {'Authorization': api.authorizationHeader});
      if (_closed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempt = 0;
      connected.value = true;
      _subscription = socket.listen(
        (raw) {
          if (generation == _generation) _onData(raw);
        },
        onDone: () => _lost(generation),
        onError: (_) => _lost(generation),
        cancelOnError: true,
      );
      // Dem Server mitteilen, dass diese App fernsteuerbar ist.
      await api.reportCapabilities();
    } catch (_) {
      _lost(generation);
    }
  }

  /// Verbindung [generation] ist weg (oder unbrauchbar): aufräumen, neu versuchen.
  void _lost(int generation) {
    if (generation != _generation) return;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close().ignore();
    _scheduleReconnect();
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final type = (msg['MessageType'] as String?) ?? '';
    final data = msg['Data'];

    if (type == 'ForceKeepAlive') {
      // Der Server erwartet regelmäßig ein Lebenszeichen.
      final seconds = (data as num?)?.toInt() ?? 60;
      _keepAlive?.cancel();
      _send({'MessageType': 'KeepAlive'});
      _keepAlive = Timer.periodic(
        Duration(seconds: math.max(5, seconds ~/ 2)),
        (_) => _send({'MessageType': 'KeepAlive'}),
      );
      return;
    }
    if (type == 'KeepAlive') return;
    _messages.add(LiveMessage(type, data is Map ? data.cast<String, dynamic>() : {'Value': data}));
  }

  void _send(Map<String, dynamic> message) {
    try {
      _socket?.add(jsonEncode(message));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _keepAlive?.cancel();
    _socket = null;
    if (!_closed) connected.value = false;
    if (_closed || (_reconnect?.isActive ?? false)) return;
    _attempt++;
    final delay = Duration(seconds: math.min(60, 1 << math.min(_attempt, 6)));
    _reconnect = Timer(delay, _connect);
  }

  Future<void> close() async {
    _closed = true;
    _keepAlive?.cancel();
    _reconnect?.cancel();
    await _subscription?.cancel();
    await _socket?.close();
    _socket = null;
    await _messages.close();
    connected.dispose();
  }
}

/// Live-Verbindung des angemeldeten Benutzers (`null` ohne Anmeldung).
final liveConnectionProvider = Provider<LiveConnection?>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;
  final connection = LiveConnection(ref.watch(apiProvider))..start();
  ref.onDispose(connection.close);
  return connection;
});

/// Empfänger für Fernsteuerbefehle an den Player (vom Player gesetzt).
abstract final class RemoteControl {
  /// Playstate-Befehle: "Stop", "Pause", "Unpause", "PlayPause", "NextTrack",
  /// "Seek" (Data.SeekPositionTicks), "Rewind", "FastForward".
  static void Function(String command, Json data)? onPlaystate;

  /// Allgemeine Befehle für den Player: "SetVolume", "VolumeUp", "ToggleMute",
  /// "SetAudioStreamIndex", "SetSubtitleStreamIndex" … (mit Arguments).
  static bool Function(String name, Map<String, dynamic> arguments)? onGeneral;
}
