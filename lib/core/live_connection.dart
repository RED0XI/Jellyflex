import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

  void start() => _connect();

  Future<void> _connect() async {
    if (_closed) return;
    try {
      final query = Uri(queryParameters: {'api_key': ?api.token, 'deviceId': api.deviceId}).query;
      final url = '${api.baseUrl.replaceFirst(RegExp('^http', caseSensitive: false), 'ws')}/socket?$query';
      final socket = await WebSocket.connect(url, headers: {'Authorization': api.authorizationHeader});
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempt = 0;
      socket.listen(_onData, onDone: _scheduleReconnect, onError: (_) => _scheduleReconnect(), cancelOnError: true);
      // Dem Server mitteilen, dass diese App fernsteuerbar ist.
      await api.reportCapabilities();
    } catch (_) {
      _scheduleReconnect();
    }
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
    if (_closed || (_reconnect?.isActive ?? false)) return;
    _attempt++;
    final delay = Duration(seconds: math.min(60, 1 << math.min(_attempt, 6)));
    _reconnect = Timer(delay, _connect);
  }

  Future<void> close() async {
    _closed = true;
    _keepAlive?.cancel();
    _reconnect?.cancel();
    await _socket?.close();
    _socket = null;
    await _messages.close();
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
