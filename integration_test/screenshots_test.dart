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
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/home/home_screen.dart';
import 'package:jellyflex/features/library/library_screen.dart';
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

class _ShotApi extends JellyfinApi {
  _ShotApi() : super(baseUrl: 'http://localhost:1', deviceId: 'd', token: 't', userId: 'u');

  @override
  Future<List<String>> getGenres(String? parentId, {String includeItemTypes = 'Movie,Series'}) async => [
    'Action',
    'Drama',
    'Sci-Fi',
  ];

  @override
  Future<LibraryPage> getLibraryPage({
    required String parentId,
    required String includeItemTypes,
    required String sortBy,
    required String sortOrder,
    int startIndex = 0,
    int limit = 100,
    List<String> filters = const [],
    String? genre,
    List<int> years = const [],
    String? nameStartsWith,
    String? nameLessThan,
  }) async {
    const names = [
      'Das Echo der Sterne',
      'Nachtfalter',
      'Kalte Brandung',
      'Der letzte Sommer',
      'Projekt Aurora',
      'Stadt aus Glas',
      'Die Uhrmacherin',
      'Sturmwarnung',
      'Unter Null',
      'Grenzgänger',
    ];
    final items = [
      for (var i = 0; i < names.length; i++)
        BaseItem({
          'Id': 'm$i',
          'Name': names[i],
          'Type': 'Movie',
          'ProductionYear': 1990 + i,
          'UserData': {'Played': i == 2, 'PlaybackPositionTicks': i == 4 ? 20000000000 : 0},
          'RunTimeTicks': 60000000000,
        }),
    ];
    return LibraryPage(items, items.length);
  }
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
  overrides: [
    sessionProvider.overrideWith(_FakeSession.new),
    userImageProvider.overrideWith((ref) async => null),
    apiProvider.overrideWithValue(_ShotApi()),
  ],
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

  testWidgets('Bibliothek mit Filtern', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(_app(const LibraryScreen(libraryId: 'lib', name: 'Filme', collectionType: 'movies')));
    await _pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Ungesehen'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Jahrzehnt'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('90er').last);
    await _pumpFor(tester, const Duration(seconds: 1));
    await _saveShot(tester, 'library');
  });

  // Braucht den Demo-Server: dart run tool/mock_server.dart
  testWidgets('Startseite (Demo-Server)', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('http://localhost:8097/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(1440, 2900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new)],
        child: RepaintBoundary(
          key: _shotKey,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: const HomeScreen()),
        ),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 6));
    await _saveShot(tester, 'home_full');
  });
}

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: 'http://localhost:8097',
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'd',
  );
}
