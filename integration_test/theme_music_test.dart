// Titelmusik auf Detailseiten: standardmäßig aus (keine Anfrage), eingeschaltet
// wird sie vom eigenen Server geladen.
//
// Voraussetzung:  dart run tool/mock_server.dart  (und %TEMP%\jellyflex_test.mkv)
// Start:          flutter test integration_test/theme_music_test.dart -d windows

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/details/theme_music.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<String?> _lastTheme() async {
  final request = await HttpClient().getUrl(Uri.parse('$demoServer/debug/lasttheme'));
  final body = await utf8.decoder.bind(await request.close()).join();
  return (jsonDecode(body) as Map)['id'] as String?;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Titelmusik', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings()),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);
    expect(container.read(settingsProvider).themeMusic, isFalse, reason: 'Standard: aus');

    // Aus: keine Anfrage.
    router.push('/item/movie5');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(ThemeMusic), findsOneWidget);
    expect(await tester.runAsync(_lastTheme), isNot('theme_movie5'));
    router.pop();
    await pumpFor(tester, const Duration(seconds: 1));

    // An: Titelmusik vom eigenen Server.
    container.read(settingsProvider.notifier).update((s) => s.copyWith(themeMusic: true));
    router.push('/item/movie6');
    await pumpFor(tester, const Duration(seconds: 3));
    expect(await tester.runAsync(_lastTheme), 'theme_movie6');
    router.pop();
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}
