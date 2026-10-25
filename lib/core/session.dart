import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'jellyfin_api.dart';
import 'profile_pin.dart';
import 'secure_store.dart';

class AuthSession {
  const AuthSession({
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.token,
    required this.deviceId,
    this.userImageTag,
    this.pinHash,
  });

  final String serverUrl;
  final String serverName;
  final String userId;
  final String userName;
  final String token;
  final String deviceId;
  final String? userImageTag;

  /// Hash der Profil-PIN (siehe [ProfilePin]); `null` = ohne PIN.
  final String? pinHash;

  bool get hasPin => pinHash != null;

  AuthSession withPin(String? hash) => AuthSession(
    serverUrl: serverUrl,
    serverName: serverName,
    userId: userId,
    userName: userName,
    token: token,
    deviceId: deviceId,
    userImageTag: userImageTag,
    pinHash: hash,
  );

  /// Eindeutig pro Server + Benutzer (für die Liste gespeicherter Konten).
  String get accountKey => '$serverUrl|$userId';

  /// Profilbild (anonym abrufbar), sonst `null`.
  String? get userImageUrl => userImageTag == null
      ? null
      : '$serverUrl/UserImage?${Uri(queryParameters: {'userId': userId, 'tag': userImageTag}).query}';

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'serverName': serverName,
    'userId': userId,
    'userName': userName,
    'token': token,
    'deviceId': deviceId,
    'userImageTag': userImageTag,
    if (pinHash != null) 'pinHash': pinHash,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    serverUrl: json['serverUrl'] as String,
    serverName: (json['serverName'] as String?) ?? 'Jellyfin',
    userId: json['userId'] as String,
    userName: (json['userName'] as String?) ?? '',
    token: json['token'] as String,
    deviceId: json['deviceId'] as String,
    userImageTag: json['userImageTag'] as String?,
    pinHash: json['pinHash'] as String?,
  );
}

SecureStore get _storage => SecureStore.instance;

/// Anmeldung hat geklappt, aber das Profil ist mit einer PIN geschützt –
/// erst nach richtiger PIN mit `activate(account, pinChecked: true)` öffnen.
class PinRequired implements Exception {
  const PinRequired(this.account);

  final AuthSession account;
}

const _sessionKey = 'jellyflex.session';
const _deviceIdKey = 'jellyflex.deviceId';
const _lastServerKey = 'jellyflex.lastServer';
const _accountsKey = 'jellyflex.accounts';

/// Alle Konten, mit denen man sich auf diesem Gerät angemeldet hat.
Future<List<AuthSession>> loadSavedAccounts() async {
  final raw = await _storage.read(key: _accountsKey);
  if (raw == null) return const [];
  try {
    return (jsonDecode(raw) as List).map((e) => AuthSession.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
}

Future<void> _saveAccounts(List<AuthSession> accounts) =>
    _storage.write(key: _accountsKey, value: jsonEncode([for (final a in accounts) a.toJson()]));

final savedAccountsProvider = FutureProvider.autoDispose<List<AuthSession>>((ref) {
  ref.watch(sessionProvider); // nach An-/Abmeldung neu laden
  return loadSavedAccounts();
});

/// Hält die aktuelle Anmeldung. `null` = nicht angemeldet.
class SessionController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    // Fehlversuche bei Profil-PINs (überstehen einen Neustart).
    await ProfilePin.load();
    final stored = await _storage.read(key: _sessionKey);
    if (stored == null) return null;
    try {
      final session = AuthSession.fromJson(jsonDecode(stored) as Map<String, dynamic>);
      // Anmeldungen aus älteren Versionen in die Kontoliste übernehmen.
      final accounts = await loadSavedAccounts();
      if (!accounts.any((a) => a.accountKey == session.accountKey)) {
        await _saveAccounts([...accounts, session]);
      }
      // Profil mit PIN: nicht automatisch öffnen, sondern über "Wer schaut?" mit PIN.
      final saved = accounts.where((a) => a.accountKey == session.accountKey).firstOrNull;
      if ((saved ?? session).hasPin) {
        await _storage.delete(key: _sessionKey);
        return null;
      }
      return session;
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
    // Wer das Server-Passwort kennt, ist der Kontoinhaber – eine vergessene PIN
    // darf ihn nicht aussperren. Bei Konten ohne Passwort gilt die PIN weiter.
    await _complete(server, api.deviceId, result, ownerProven: password.isNotEmpty);
  }

  Future<void> loginWithQuickConnect(ServerInfo server, String secret) async {
    final api = await anonymousApi(server);
    final result = await api.authenticateWithQuickConnect(secret);
    // Quick Connect muss auf einem angemeldeten Gerät desselben Kontos bestätigt werden.
    await _complete(server, api.deviceId, result, ownerProven: true);
  }

  /// [ownerProven]: mit Passwort bzw. bestätigtem Quick Connect angemeldet – dann
  /// wird eine gesetzte Profil-PIN entfernt (neu festlegen in den Einstellungen).
  Future<void> _complete(ServerInfo server, String deviceId, AuthResult result, {bool ownerProven = false}) async {
    final session = AuthSession(
      serverUrl: server.url,
      serverName: server.name,
      userId: result.userId,
      userName: result.userName,
      token: result.token,
      deviceId: deviceId,
      userImageTag: result.userImageTag,
    );
    await _storage.write(key: _lastServerKey, value: server.url);
    final previous = await loadSavedAccounts();
    // Erneute Anmeldung ohne Nachweis (Konto ohne Passwort) behält die Profil-PIN.
    final pin = ownerProven ? null : previous.where((a) => a.accountKey == session.accountKey).firstOrNull?.pinHash;
    if (ownerProven) ProfilePin.recordSuccess(session.accountKey);
    final accounts = [...previous]..removeWhere((a) => a.accountKey == session.accountKey);
    final withPin = session.withPin(pin);
    await _saveAccounts([withPin, ...accounts]);
    // Auch nach erneuter Anmeldung (z. B. Konto ohne Passwort) gilt die PIN.
    await activate(withPin);
  }

  /// Profil-PIN des angemeldeten Kontos setzen (`null` = entfernen).
  Future<void> setPin(String? pinHash) async {
    final session = state.value;
    if (session == null) return;
    final updated = session.withPin(pinHash);
    final saved = await loadSavedAccounts();
    final accounts = [
      for (final a in saved) a.accountKey == session.accountKey ? updated : a,
      if (!saved.any((a) => a.accountKey == session.accountKey)) updated,
    ];
    await _saveAccounts(accounts);
    await _storage.write(key: _sessionKey, value: jsonEncode(updated.toJson()));
    state = AsyncData(updated);
    ref.invalidate(savedAccountsProvider);
  }

  /// Zu einem gespeicherten Konto wechseln. Ein Profil mit PIN öffnet nur mit
  /// [pinChecked] (sonst [PinRequired]) – die einzige Stelle, die ein Profil öffnet.
  Future<void> activate(AuthSession session, {bool pinChecked = false}) async {
    if (session.hasPin && !pinChecked) throw PinRequired(session);
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    state = AsyncData(session);
  }

  /// Der Server nimmt die Anmeldung von [session] nicht mehr an (abgelaufen, Passwort geändert,
  /// im Dashboard abgemeldet): zur Anmeldung zurück. Das Profil bleibt in der Auswahl (mit PIN),
  /// aber ohne Zugang – ein Klick darauf fragt nach dem Passwort.
  Future<void> sessionExpired(AuthSession session) async {
    if (state.value?.token != session.token) return; // schon erledigt
    final saved = await loadSavedAccounts();
    await _saveAccounts([
      for (final a in saved)
        a.accountKey == session.accountKey
            ? AuthSession(
                serverUrl: a.serverUrl,
                serverName: a.serverName,
                userId: a.userId,
                userName: a.userName,
                token: '',
                deviceId: a.deviceId,
                userImageTag: a.userImageTag,
                pinHash: a.pinHash,
              )
            : a,
    ]);
    await _storage.delete(key: _sessionKey);
    state = const AsyncData(null);
    ref.invalidate(savedAccountsProvider);
  }

  /// Zur Profilauswahl zurück, ohne das Konto zu vergessen.
  Future<void> switchUser() async {
    await _storage.delete(key: _sessionKey);
    state = const AsyncData(null);
  }

  /// Gespeichertes Konto vergessen (meldet es beim Server ab, falls möglich).
  /// Suchverlauf eines Kontos löschen (beim Abmelden/Vergessen).
  Future<void> _forgetSearches(AuthSession account) => _storage.delete(key: 'jellyflex.searches.${account.accountKey}');

  Future<void> forgetAccount(AuthSession account) async {
    await _forgetSearches(account);
    try {
      await JellyfinApi(
        baseUrl: account.serverUrl,
        deviceId: account.deviceId,
        token: account.token,
        userId: account.userId,
      ).logout();
    } catch (_) {}
    final accounts = [...await loadSavedAccounts()]..removeWhere((a) => a.accountKey == account.accountKey);
    await _saveAccounts(accounts);
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> logout() async {
    final session = state.value;
    if (session != null) await _forgetSearches(session);
    if (session != null) {
      try {
        await ref.read(apiProvider).logout();
      } catch (_) {
        // Server nicht erreichbar – lokal trotzdem abmelden.
      }
    }
    if (session != null) {
      final accounts = [...await loadSavedAccounts()]..removeWhere((a) => a.accountKey == session.accountKey);
      await _saveAccounts(accounts);
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
  )..onUnauthorized = () => ref.read(sessionProvider.notifier).sessionExpired(session);
});
