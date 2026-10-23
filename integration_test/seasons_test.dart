// Prüft die saisonalen Akzente auf der Startseite gegen den Demo-Server:
// Halloween-Reihe und Emoji, Effekte, Abschalten in den Einstellungen.
// Bildschirmfotos für Halloween, Weihnachten und Valentinstag.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/seasons_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/seasons.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/home_providers.dart';
import 'package:jellyflex/widgets/media_row.dart';
import 'package:jellyflex/widgets/seasonal_particles.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_settings.dart';

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'seasons-test',
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Saisonale Akzente', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    final temp = Directory.systemTemp.createTempSync('jellyflex_seasons_');
    try {
      Future<ProviderContainer> start(DateTime date) async {
        seasonClock = () => date;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith(_DemoSession.new),
              settingsProvider.overrideWith(() => testSettings(temp)),
            ],
            child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
          ),
        );
        await _pumpFor(tester, const Duration(seconds: 4));
        return ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
      }

      // --- Halloween: Reihe, Emoji, Effekte ---
      final container = await start(DateTime(2026, 10, 31, 20));
      expect(find.byType(SeasonalParticles), findsOneWidget);
      expect(find.text('🎃'), findsOneWidget);
      // Bannerhöhe überspringen, damit die Reihe gebaut wird.
      final home = tester.widget<CustomScrollView>(find.byType(CustomScrollView).first);
      home.controller!.jumpTo(950);
      await _pumpFor(tester, const Duration(seconds: 1));
      debugPrint('Saison-Reihe: ${container.read(seasonalSectionProvider)}');
      debugPrint('Reihen: ${find.byType(MediaRow).evaluate().map((e) => (e.widget as MediaRow).title).toList()}');
      await _saveShot(tester, 'season_debug');
      expect(find.text('🎃  Gruselzeit'), findsOneWidget);
      home.controller!.jumpTo(0);
      await _pumpFor(tester, const Duration(seconds: 2));
      await _saveShot(tester, 'season_halloween');

      // --- Abschalten ---
      container.read(settingsProvider.notifier).update((s) => s.copyWith(seasonalThemes: false));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(SeasonalParticles), findsNothing);
      expect(find.text('🎃'), findsNothing);
      container.read(settingsProvider.notifier).update((s) => s.copyWith(seasonalThemes: true));

      // --- Weihnachten, Valentinstag: nur Bildschirmfotos der Effekte ---
      await start(DateTime(2026, 12, 20, 18));
      expect(find.text('🎄'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 2));
      await _saveShot(tester, 'season_christmas');

      await start(DateTime(2027, 2, 14, 19));
      expect(find.text('💘'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 3));
      await _saveShot(tester, 'season_valentine');

      // --- Normaler Tag: nichts ---
      await start(DateTime(2027, 3, 10, 12));
      expect(find.byType(SeasonalParticles), findsNothing);
    } finally {
      seasonClock = DateTime.now;
      await tester.pumpWidget(const SizedBox());
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
