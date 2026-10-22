// Rendert einzelne Seiten mit Testdaten und speichert sie als PNG unter
// build/screenshots/ – zum Anschauen ohne echten Server.
//
// Start:  flutter test integration_test/screenshots_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/home/home_providers.dart';
import 'package:jellyflex/features/settings/settings_screen.dart';
import 'package:jellyflex/theme.dart';

class _FakeSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: 'https://aphelion.example/jellyfin',
    serverName: 'Aphelion',
    userId: 'u',
    userName: 'Alex',
    token: 't',
    deviceId: 'd',
  );
}

final _shotKey = GlobalKey();

Future<void> _saveShot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget page) => ProviderScope(
  overrides: [sessionProvider.overrideWith(_FakeSession.new), userImageProvider.overrideWith((ref) async => null)],
  child: RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: page),
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Einstellungen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1300));
    await tester.pumpWidget(_app(const SettingsScreen()));
    await _pumpFor(tester, const Duration(seconds: 3)); // Schriften laden
    await _saveShot(tester, 'settings');
  });
}
