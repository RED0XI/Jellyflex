import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/session.dart';

/// Adresse des Demo-Servers (dart run tool/mock_server.dart).
const demoServer = 'http://localhost:8097';

/// Angemeldet am Demo-Server (beliebige Zugangsdaten).
class DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: demoServer,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'integration-test',
  );
}

/// Um die App legen (`RepaintBoundary(key: shotKey, …)`), damit [saveShot] fotografieren kann.
final shotKey = GlobalKey();

/// Bildschirmfoto nach build/screenshots/[name].png.
Future<void> saveShot(WidgetTester tester, String name) async {
  final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

/// Echte Zeit vergehen lassen (Netzwerk, Animationen) und dabei Frames zeichnen.
Future<void> pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Läuft der Demo-Server? Sonst wird der Test übersprungen.
Future<bool> demoServerRunning() async {
  try {
    await HttpClient().getUrl(Uri.parse('$demoServer/System/Info/Public')).then((r) => r.close());
    return true;
  } catch (_) {
    markTestSkipped('Demo-Server läuft nicht');
    return false;
  }
}
