import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Ein Jellyfin-Server, der sich im Heimnetz gemeldet hat.
class DiscoveredServer {
  const DiscoveredServer({required this.id, required this.name, required this.address, this.responder = ''});

  final String id;
  final String name;

  /// Adresse, wie der Server sie selbst nennt (z. B. `http://192.168.1.20:8096`).
  final String address;

  /// IP-Adresse des Geräts, das geantwortet hat.
  final String responder;

  /// Zeigt die genannte Adresse ins Heimnetz (oder auf das antwortende Gerät)? Sonst könnte
  /// ein fremdes Gerät im Netz auf einen Server im Internet locken – das wird dann angezeigt.
  bool get inHomeNetwork {
    final host = Uri.parse(address).host.toLowerCase();
    // Das antwortende Gerät selbst, dieser PC oder ein Gerätename ohne Punkt (z. B. "nas").
    if (host == responder || host == 'localhost' || !host.contains('.')) return true;
    if (const ['.local', '.lan', '.home', '.internal', '.home.arpa'].any(host.endsWith)) return true;
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return false;
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
    }
    return (b[0] & 0xFE) == 0xFC; // IPv6: fc00::/7
  }
}

/// Sucht Jellyfin-Server im Heimnetz – nur auf ausdrücklichen Wunsch (Knopf auf der Anmeldeseite).
///
/// Wie Jellyfins eigene Apps: eine UDP-Rundfrage "who is JellyfinServer?" an Port 7359, jeder
/// Server antwortet mit Name und Adresse. Die Frage verlässt das Heimnetz nicht. Antworten kann
/// aber jedes Gerät im Netz – deshalb wird ein Fund nur angezeigt; verbunden wird erst nach einem
/// Klick, und die Adresse wird dann genauso geprüft wie eine eingetippte.
abstract final class ServerDiscovery {
  static const _question = 'who is JellyfinServer?';

  /// Steuerzeichen und Richtungswechsel (z. B. U+202E, das Text rückwärts zeigt) – fliegen aus Namen.
  static final _unsafeChars = RegExp(r'[\x00-\x1F\x7F\u200E\u200F\u202A-\u202E\u2066-\u2069]');

  /// Ziel der Rundfrage (Tests: localhost).
  static InternetAddress target = InternetAddress('255.255.255.255');
  static int port = 7359;

  /// Fragt im Heimnetz und sammelt die Antworten, die innerhalb von [timeout] eintreffen.
  static Future<List<DiscoveredServer>> search({Duration timeout = const Duration(seconds: 3)}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final found = <String, DiscoveredServer>{};
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      final server = datagram == null ? null : parse(datagram.data, responder: datagram.address.address);
      if (server != null && found.length < 20) found.putIfAbsent(server.id, () => server);
    });
    try {
      final question = utf8.encode(_question);
      socket.send(question, target, port);
      // Kurz darauf noch einmal – UDP-Pakete gehen manchmal verloren.
      const resend = Duration(milliseconds: 400);
      await Future<void>.delayed(resend);
      socket.send(question, target, port);
      await Future<void>.delayed(timeout - resend);
    } finally {
      await sub.cancel();
      socket.close();
    }
    return found.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Antwort eines Servers lesen; alles Unerwartete wird verworfen.
  static DiscoveredServer? parse(List<int> data, {String responder = ''}) {
    if (data.length > 4096) return null;
    try {
      final json = jsonDecode(utf8.decode(data));
      if (json is! Map) return null;
      final address = json['Address'];
      final id = json['Id'];
      final name = json['Name'];
      if (address is! String || address.length > 300 || id is! String || id.isEmpty || id.length > 100) return null;
      final uri = Uri.tryParse(address);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        return null;
      }
      final cleanName = name is String ? name.replaceAll(_unsafeChars, '').trim() : '';
      return DiscoveredServer(
        id: id,
        name: cleanName.isEmpty ? uri.host : (cleanName.length > 60 ? cleanName.substring(0, 60) : cleanName),
        address: address,
        responder: responder,
      );
    } catch (_) {
      return null;
    }
  }
}
