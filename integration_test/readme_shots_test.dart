// Bilder für die README – mit einem echten Server, an dem in einem
// eigenen Profil schon jemand angemeldet ist (z. B. dem Jellyfin-Demo-Server).
//
// Start:  flutter test integration_test/readme_shots_test.dart -d windows
//           --dart-define=SHOTS_PROFILE=<Ordner mit settings.json und secure.bin>
// Ohne SHOTS_PROFILE wird der Test übersprungen. Mit --dart-define=SHOTS_ONLY=home,player
// nur einzelne Bilder. Ergebnis: build/readme_shots/*.png – danach `python tool/readme_shots.py`
// (verkleinert nach docs/screenshots/*.jpg).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';

const _profile = String.fromEnvironment('SHOTS_PROFILE');
final _boundary = GlobalKey();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  /// Echte Zeit vergehen lassen (Netzwerk, Bilder, Animationen).
  Future<void> wait(WidgetTester tester, [int ms = 1500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scharfes Bild (1,5-fach) nach build/readme_shots/[name].png.
  Future<void> shot(WidgetTester tester, String name) async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.5));
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final file = File('build/readme_shots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    debugPrint('SHOT ${file.path}');
  }

  testWidgets('README-Bilder', (tester) async {
    if (_profile.isEmpty) {
      markTestSkipped('SHOTS_PROFILE nicht gesetzt');
      return;
    }
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1600, 900));
    // Zeitlos und ohne Fenster davor: "Was ist neu" gilt als gesehen, keine Saison-Deko.
    final file = File('$_profile${Platform.pathSeparator}settings.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    file.writeAsStringSync(
      jsonEncode({
        ...json,
        'language': 'en',
        'lastSeenVersion': appVersion,
        'seasonalThemes': false,
        'bannerTrailers': false,
        'layoutId': 'cinema',
        'themeId': 'midnight',
      }),
    );
    final settings = testSettings(Directory(_profile), AppLanguage.en);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => settings)],
        child: RepaintBoundary(key: _boundary, child: const JellyflexApp()),
      ),
    );
    await wait(tester, 8000);
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final router = container.read(routerProvider);
    final api = container.read(apiProvider);
    final ctrl = container.read(settingsProvider.notifier);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));

    const only = String.fromEnvironment('SHOTS_ONLY');
    Future<void> attempt(String name, Future<void> Function() body) async {
      if (only.isNotEmpty && !only.split(',').any(name.startsWith)) return;
      try {
        await body();
      } catch (e) {
        debugPrint('SHOT FEHLER $name: $e');
      }
    }

    // --- Startseite (Kino-Layout) -----------------------------------------------------
    await attempt('home', () async {
      router.go('/');
      await wait(tester, 6000);
      await shot(tester, 'home');
      // Etwas tiefer: die Reihen.
      await tester.sendEventToBinding(mouse.hover(const Offset(800, 600)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 500)));
      await wait(tester, 3000);
      await shot(tester, 'home_rows');
      await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));
    });

    // Titel vom Server: Filme und Serien.
    final views = await tester.runAsync(api.getUserViews) ?? const <BaseItem>[];
    final movieLib = views.where((v) => v.collectionType == 'movies').firstOrNull;
    final picks = await tester.runAsync(() => api.getRandomPicks(includeItemTypes: 'Movie', limit: 40)) ?? [];
    final movie =
        picks.where((m) => m.name.toLowerCase().contains('sintel')).firstOrNull ??
        picks.where((m) => m.backdropImageTags.isNotEmpty && m.overview != null).firstOrNull;
    final series = (await tester.runAsync(() => api.getRandomPicks(includeItemTypes: 'Series', limit: 20)) ?? [])
        .where((s) => s.backdropImageTags.isNotEmpty)
        .firstOrNull;

    // --- Detailseiten -----------------------------------------------------------------
    if (movie != null) {
      await attempt('details', () async {
        router.go('/');
        await wait(tester, 500);
        router.push('/item/${movie.id}');
        await wait(tester, 6000);
        await shot(tester, 'details');
      });
    }
    if (series != null) {
      await attempt('series', () async {
        router.go('/');
        await wait(tester, 500);
        router.push('/item/${series.id}');
        await wait(tester, 5000);
        await tester.sendEventToBinding(mouse.hover(const Offset(800, 600)));
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 260)));
        await wait(tester, 3000);
        await shot(tester, 'series');
        await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));
      });
    }

    // --- Bibliothek mit Szenen-Vorschau -----------------------------------------------
    if (movieLib != null) {
      await attempt('library', () async {
        router.go('/');
        await wait(tester, 500);
        router.push('/library/${movieLib.id}?name=${Uri.encodeComponent(movieLib.name)}&type=movies');
        await wait(tester, 5000);
        final cards = find.byType(PosterCard);
        if (cards.evaluate().length > 3) {
          await tester.sendEventToBinding(mouse.hover(tester.getCenter(cards.at(2))));
          await wait(tester, 2600);
        }
        await shot(tester, 'library');
        await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));
      });
    }

    // --- Player mit Vorschau beim Spulen ----------------------------------------------
    if (movie != null) {
      await attempt('player', () async {
        router.go('/');
        await wait(tester, 500);
        final runtime = movie.runtime ?? const Duration(minutes: 10);
        router.push('/play/${movie.id}?start=${(runtime.inMicroseconds * 0.3 * 10).round()}');
        await wait(tester, 9000);
        final seekBar = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SeekBar');
        await tester.sendEventToBinding(mouse.hover(const Offset(800, 450)));
        await wait(tester, 400);
        if (seekBar.evaluate().isNotEmpty) {
          final rect = tester.getRect(seekBar.first);
          await tester.sendEventToBinding(mouse.hover(Offset(rect.left + rect.width * 0.55, rect.center.dy)));
          await wait(tester, 1500);
        }
        await shot(tester, 'player');
        await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));
        router.go('/');
        await wait(tester, 1500);
      });
    }

    // --- Andere Layouts und Farben ----------------------------------------------------
    for (final (layout, theme) in const [('couch', 'midnight'), ('magazine', 'noir'), ('library', 'emerald')]) {
      await attempt('layout_$layout', () async {
        ctrl.update((s) => s.copyWith(layoutId: layout, themeId: theme));
        router.go('/');
        await wait(tester, 4000);
        // Die Startseite merkt sich, wie weit gescrollt war – für das Bild ganz nach oben.
        await tester.sendEventToBinding(mouse.hover(const Offset(1000, 500)));
        for (var i = 0; i < 8; i++) {
          await tester.sendEventToBinding(mouse.scroll(const Offset(0, -800)));
          await wait(tester, 150);
        }
        await tester.sendEventToBinding(mouse.hover(const Offset(1590, 450)));
        await wait(tester, 3000);
        await shot(tester, 'layout_$layout');
      });
    }
    ctrl.update((s) => s.copyWith(layoutId: 'cinema', themeId: 'midnight'));
    await wait(tester, 1000);

    // --- Einrichtung beim ersten Start (eigene, leere Einstellungen) -----------------
    await attempt('welcome', () async {
      await tester.pumpWidget(const SizedBox());
      await wait(tester, 500);
      final fresh = Directory.systemTemp.createTempSync('jellyflex_shots_welcome_');
      File('${fresh.path}${Platform.pathSeparator}settings.json')
          .writeAsStringSync('{"language":"en","setupDone":false}');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_SignedOut.new),
            settingsProvider.overrideWith(() => testSettings(fresh, AppLanguage.en)),
          ],
          child: RepaintBoundary(key: _boundary, child: const JellyflexApp()),
        ),
      );
      await wait(tester, 3000);
      await tester.tap(find.text(S.en.next));
      await wait(tester, 2000);
      await shot(tester, 'welcome');
    });

    await tester.pumpWidget(const SizedBox());
  });
}

class _SignedOut extends SessionController {
  @override
  Future<AuthSession?> build() async => null;
}
