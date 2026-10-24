// Banner der Startseite blättert von selbst weiter – auch wenn die Maus über dem Bild steht.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/hero_banner_test.dart -d windows

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/hero_banner.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Banner blättert weiter, auch mit der Maus über dem Bild', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final settings = testSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => settings)],
        child: const JellyflexApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    // Ohne Trailer – hier geht es nur ums Weiterblättern.
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(settingsProvider.notifier).update((s) => s.copyWith(bannerTrailers: false));

    String title() => tester
        .widgetList<Text>(find.descendant(of: find.byType(HeroBanner), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .where((t) => t.isNotEmpty)
        .join(' | ');

    // Maus rechts auf das Bild (nicht auf Text oder Knöpfe).
    final banner = tester.getRect(find.byType(HeroBanner));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(Offset(banner.right - 120, banner.center.dy)));

    final first = title();
    await pumpFor(tester, const Duration(seconds: 11));
    expect(title(), isNot(first), reason: 'Nach 9 Sekunden kommt der nächste Titel');

    // Über dem Text dagegen bleibt er stehen (zum Lesen und Klicken).
    final text = tester.getCenter(find.descendant(of: find.byType(HeroBanner), matching: find.byType(Text)).first);
    await tester.sendEventToBinding(mouse.hover(text));
    final second = title();
    await pumpFor(tester, const Duration(seconds: 11));
    expect(title(), second);

    await tester.pumpWidget(const SizedBox());
  });
}
