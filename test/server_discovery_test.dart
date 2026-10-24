import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/server_discovery.dart';
import 'package:jellyflex/core/settings.dart';

List<int> _json(Object value) => utf8.encode(jsonEncode(value));

void main() {
  test('Antwort eines Servers wird gelesen', () {
    final s = ServerDiscovery.parse(_json({'Address': 'http://192.168.1.20:8096', 'Id': 'abc', 'Name': 'Wohnzimmer'}));
    expect(s?.name, 'Wohnzimmer');
    expect(s?.address, 'http://192.168.1.20:8096');
    // Ohne Namen: die Adresse als Name.
    expect(ServerDiscovery.parse(_json({'Address': 'https://nas.local', 'Id': 'x'}))?.name, 'nas.local');
  });

  test('Unerwartete oder gefährliche Antworten werden verworfen', () {
    for (final bad in [
      utf8.encode('kein json'),
      _json([1, 2]),
      _json({'Id': 'abc'}),
      _json({'Address': 'file:///C:/Windows', 'Id': 'abc'}),
      _json({'Address': 'javascript:alert(1)', 'Id': 'abc'}),
      _json({'Address': 'http://user:pw@host', 'Id': 'abc'}),
      _json({'Address': 'http://host/?token=1', 'Id': 'abc'}),
      _json({'Address': 'http://host', 'Id': ''}),
      List.filled(5000, 32),
    ]) {
      expect(ServerDiscovery.parse(bad), isNull, reason: utf8.decode(bad, allowMalformed: true));
    }
    // Steuerzeichen im Namen fliegen raus, zu lange Namen werden gekürzt.
    final s = ServerDiscovery.parse(_json({'Address': 'http://h', 'Id': 'a', 'Name': 'A\u0000B\n${'x' * 100}'}));
    expect(s?.name, startsWith('AB'));
    expect(s!.name.length, 60);
  });

  test('Namen ohne Richtungswechsel; Adressen außerhalb des Heimnetzes werden erkannt', () {
    final spoof = ServerDiscovery.parse(_json({'Address': 'http://h', 'Id': 'a', 'Name': 'Home\u202Eevil'}));
    expect(spoof?.name, 'Homeevil');

    DiscoveredServer at(String address, [String responder = '192.168.1.5']) =>
        ServerDiscovery.parse(_json({'Address': address, 'Id': 'x'}), responder: responder)!;
    expect(at('http://192.168.1.20:8096').inHomeNetwork, isTrue);
    expect(at('http://10.0.0.2:8096').inHomeNetwork, isTrue);
    expect(at('http://nas.local:8096').inHomeNetwork, isTrue);
    expect(at('http://localhost:8096').inHomeNetwork, isTrue);
    expect(at('http://nas:8096').inHomeNetwork, isTrue);
    expect(at('http://media.example.com', 'media.example.com').inHomeNetwork, isTrue, reason: 'Gerät selbst');
    expect(at('https://jellyfin.example.com').inHomeNetwork, isFalse);
    expect(at('http://8.8.8.8:8096').inHomeNetwork, isFalse);
    expect(at('http://192.168.1.20').responder, '192.168.1.5');
  });

  test('Suche im Netz: fragt und sammelt die Antworten', () async {
    // Kleiner "Server" auf localhost, der wie Jellyfin antwortet.
    final responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final questions = <String>[];
    responder.listen((event) {
      final d = event == RawSocketEvent.read ? responder.receive() : null;
      if (d == null) return;
      questions.add(utf8.decode(d.data));
      responder.send(_json({'Address': 'http://127.0.0.1:8096', 'Id': 'srv', 'Name': 'Test'}), d.address, d.port);
    });
    ServerDiscovery.target = InternetAddress.loopbackIPv4;
    ServerDiscovery.port = responder.port;
    try {
      final found = await ServerDiscovery.search(timeout: const Duration(seconds: 1));
      expect(found.map((s) => s.name), ['Test'], reason: 'Doppelte Antworten nur einmal');
      expect(found.single.responder, '127.0.0.1', reason: 'Antwortendes Gerät wird gemerkt');
      expect(questions.first, 'who is JellyfinServer?');
    } finally {
      responder.close();
    }
  });

  test('Frisch installiert: Assistent; vorhandene Einstellungen: schon eingerichtet', () {
    expect(AppSettings.fromJson({}).setupDone, isTrue);
    expect(AppSettings.fromJson({'setupDone': false}).setupDone, isFalse);
    final dir = Directory.systemTemp.createTempSync('jellyflex_setup_');
    try {
      final fresh = SettingsController(File('${dir.path}${Platform.pathSeparator}settings.json'));
      expect(fresh.build().setupDone, isFalse);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
