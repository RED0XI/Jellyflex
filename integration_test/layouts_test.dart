// Layouts: jedes Layout live umschalten, Aufbau prüfen (Navigation, Kopf),
// Seitenverlauf bleibt beim Umschalten erhalten; Bildschirmfotos je Layout.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/layouts_test.dart -d windows

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/layouts.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/hero_banner.dart';
import 'package:jellyflex/features/home/home_headers.dart';
import 'package:jellyflex/features/home/home_nav.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/widgets/layout_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Layouts', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_layouts_');
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(DemoSession.new),
            settingsProvider.overrideWith(() => testSettings(temp, AppLanguage.en)),
          ],
          child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 3));
      final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      final settings = container.read(settingsProvider.notifier);
      final router = container.read(routerProvider);

      // Auswahl in den Einstellungen.
      router.push('/settings?section=appearance');
      await pumpFor(tester, const Duration(seconds: 1));
      await tester.ensureVisible(find.byType(LayoutPicker));
      await pumpFor(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Magazine'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(container.read(settingsProvider).layoutId, 'magazine');
      await saveShot(tester, 'layout_picker');
      router.pop();
      await pumpFor(tester, const Duration(seconds: 1));

      for (final layout in appLayouts) {
        settings.update((s) => s.copyWith(layoutId: layout.id));
        await pumpFor(tester, const Duration(seconds: 2));
        expect(appLayout.id, layout.id);

        // Aufbau passt zum Layout.
        expect(find.byType(SideNav), layout.nav == NavStyle.sidebar ? findsOneWidget : findsNothing, reason: layout.id);
        expect(find.byType(TabsNav), layout.nav == NavStyle.tabs ? findsOneWidget : findsNothing, reason: layout.id);
        expect(find.byType(MagazineHero), layout.hero == HeroStyle.split ? findsOneWidget : findsNothing);
        expect(find.byType(HeroBanner), layout.hero == HeroStyle.banner ? findsOneWidget : findsNothing);
        expect(find.byType(GreetingHeader), layout.hero == HeroStyle.none ? findsOneWidget : findsNothing);
        await saveShot(tester, 'layout_${layout.id}_home');

        // Etwas scrollen: Reihen und Karten.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
        await pumpFor(tester, const Duration(milliseconds: 800));
        await saveShot(tester, 'layout_${layout.id}_rows');

        router.push('/item/movie0');
        await pumpFor(tester, const Duration(seconds: 2));
        await saveShot(tester, 'layout_${layout.id}_details');
        router.pop();
        await pumpFor(tester, const Duration(seconds: 1));
      }

      // Umschalten behält den Seitenverlauf (Navigator bleibt erhalten).
      router.push('/item/movie0');
      await pumpFor(tester, const Duration(seconds: 1));
      settings.update((s) => s.copyWith(layoutId: 'library'));
      await pumpFor(tester, const Duration(seconds: 1));
      settings.update((s) => s.copyWith(layoutId: 'cinema'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(router.state.uri.path, '/item/movie0');
      expect(router.canPop(), isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
