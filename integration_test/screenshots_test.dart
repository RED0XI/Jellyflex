// Rendert einzelne Seiten mit Testdaten und speichert sie als PNG unter
// build/screenshots/ – zum Anschauen ohne echten Server.
//
// Start:  flutter test integration_test/screenshots_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/home_screen.dart';
import 'package:jellyflex/features/library/library_screen.dart';
import 'package:jellyflex/features/login/login_screen.dart';
import 'package:jellyflex/features/home/home_providers.dart';
import 'package:jellyflex/features/settings/settings_screen.dart';
import 'package:jellyflex/theme.dart';
import 'package:media_kit/media_kit.dart';

import 'test_settings.dart';
import 'test_helpers.dart';

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

Widget _app(Widget page) => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(_FakeSession.new),
    settingsProvider.overrideWith(testSettings),
    userImageProvider.overrideWith((ref) async => null),
    apiProvider.overrideWithValue(_ShotApi()),
  ],
  child: RepaintBoundary(
    key: shotKey,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: page),
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Einstellungen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1300));
    await tester.pumpWidget(_app(const SettingsScreen()));
    await pumpFor(tester, const Duration(seconds: 3)); // Schriften laden
    await saveShot(tester, 'settings');
  });

  testWidgets('Bibliothek mit Filtern', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(_app(const LibraryScreen(libraryId: 'lib', name: 'Filme', collectionType: 'movies')));
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Ungesehen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Jahrzehnt'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('90er').last);
    await pumpFor(tester, const Duration(seconds: 1));
    await saveShot(tester, 'library');
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
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: const HomeScreen()),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 6));
    await saveShot(tester, 'home_full');
  });

  // Braucht den Demo-Server mit Testvideo (Trailer = %TEMP%\jellyflex_test.mkv).
  testWidgets('Startseite: Trailer im Banner', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('http://localhost:8097/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: const HomeScreen()),
        ),
      ),
    );
    // Start nach 4 s, dann Laden und Einblenden – bis zu 20 s warten.
    double muteOpacity() {
      final finder = find.ancestor(of: find.byIcon(Icons.volume_off_rounded), matching: find.byType(AnimatedOpacity));
      if (finder.evaluate().isEmpty) return 0; // Banner noch nicht geladen
      return tester.widget<AnimatedOpacity>(finder.first).opacity;
    }

    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end) && muteOpacity() < 1) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await pumpFor(
      tester,
      const Duration(milliseconds: 1500),
    ); // Einblenden abwarten    debugPrint('Ton-Knopf sichtbar: ${muteOpacity()}');
    await saveShot(tester, 'home_trailer');
    expect(muteOpacity(), 1.0, reason: 'Trailer sollte laufen und eingeblendet sein');
  });

  testWidgets('Profilauswahl', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(testSettings),
          savedAccountsProvider.overrideWith(
            (ref) async => const [
              AuthSession(
                serverUrl: 'http://x',
                serverName: 'Aphelion',
                userId: 'a',
                userName: 'Alex',
                token: 't',
                deviceId: 'd',
              ),
              AuthSession(
                serverUrl: 'http://x',
                serverName: 'Aphelion',
                userId: 'b',
                userName: 'Gast',
                token: 't',
                deviceId: 'd',
              ),
            ],
          ),
        ],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: const LoginScreen()),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Wer schaut?'), findsOneWidget);
    await saveShot(tester, 'profiles');
  });
}
