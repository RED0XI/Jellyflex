import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'jellyfin_api.dart';
import 'secure_store.dart';

class AuthSession {
  const AuthSession({
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.token,
    required this.deviceId,
  });

  final String serverUrl;
  final String serverName;
  final String userId;
  final String userName;
  final String token;
  final String deviceId;

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'serverName': serverName,
    'userId': userId,
    'userName': userName,
    'token': token,
    'deviceId': deviceId,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    serverUrl: json['serverUrl'] as String,
    serverName: (json['serverName'] as String?) ?? 'Jellyfin',
    userId: json['userId'] as String,
    userName: (json['userName'] as String?) ?? '',
    token: json['token'] as String,
    deviceId: json['deviceId'] as String,
  );
}

final _storage = SecureStore.instance;
const _sessionKey = 'jellyflex.session';
const _deviceIdKey = 'jellyflex.deviceId';
const _lastServerKey = 'jellyflex.lastServer';

/// Hält die aktuelle Anmeldung. `null` = nicht angemeldet.
class SessionController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final stored = await _storage.read(key: _sessionKey);
    if (stored == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  static Future<String> deviceId() async {
    var id = await _storage.read(key: _deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: id);
    }
    return id;
  }

  static Future<String?> lastServer() => _storage.read(key: _lastServerKey);

  /// API-Client für einen Server, bei dem man noch nicht angemeldet ist.
  static Future<JellyfinApi> anonymousApi(ServerInfo server) async =>
      JellyfinApi(baseUrl: server.url, deviceId: await deviceId());

  Future<void> loginWithPassword(ServerInfo server, String username, String password) async {
    final api = await anonymousApi(server);
    final result = await api.authenticate(username, password);
    await _complete(server, api.deviceId, result);
  }

  Future<void> loginWithQuickConnect(ServerInfo server, String secret) async {
    final api = await anonymousApi(server);
    final result = await api.authenticateWithQuickConnect(secret);
    await _complete(server, api.deviceId, result);
  }

  Future<void> _complete(ServerInfo server, String deviceId, AuthResult result) async {
    final session = AuthSession(
      serverUrl: server.url,
      serverName: server.name,
      userId: result.userId,
      userName: result.userName,
      token: result.token,
      deviceId: deviceId,
    );
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    await _storage.write(key: _lastServerKey, value: server.url);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    final session = state.value;
    if (session != null) {
      try {
        await ref.read(apiProvider).logout();
      } catch (_) {
        // Server nicht erreichbar – lokal trotzdem abmelden.
      }
    }
    await _storage.delete(key: _sessionKey);
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AuthSession?>(SessionController.new);

/// API-Client für den angemeldeten Benutzer.
///
/// Ohne Anmeldung gibt es einen leeren Platzhalter statt eines Fehlers:
/// Beim Abmelden bauen sich Seiten evtl. noch einmal auf, bevor der Router
/// zur Anmeldung wechselt – das soll keine Fehlerseite aufblitzen lassen.
final apiProvider = Provider<JellyfinApi>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return JellyfinApi(baseUrl: 'http://localhost', deviceId: 'signed-out');
  return JellyfinApi(
    baseUrl: session.serverUrl,
    deviceId: session.deviceId,
    token: session.token,
    userId: session.userId,
  );
});
