// Prüft im echten Player (mpv): Untertitel-Stil und Sprache je Bibliothek und das Panel im Player.
//
// Voraussetzung: Testvideo mit zwei Untertiteln (de, en) – siehe lib/dev/player_harness.dart.
//
// Start:  flutter test integration_test/subtitle_style_test.dart -d macos   (bzw. -d windows)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/subtitle_style.dart';
import 'package:jellyflex/dev/player_harness.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Untertitel: Regeln der Bibliothek und Panel im Player', (tester) async {
    await windowManager.ensureInitialized();
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);

    // Allgemein Englisch und weiß; die Bibliothek "Anime" will Deutsch, groß und gelb.
    const anime = SubtitleStyle(scale: 1.5, color: 0xFFFFE14D, font: SubtitleFont.serif, raise: 10);
    final settings = const AppSettings(
      language: AppLanguage.de,
      subtitleLanguage: 'eng',
    ).withLibrarySubtitles('lib-test', const LibrarySubtitles(style: anime, language: 'ger'));

    await tester.pumpWidget(buildHarnessApp(settings: settings));
    await tester.pump();
    await tester.tap(find.text('Test-Player öffnen'));

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = player;
      if (p != null && p.state.tracks.subtitle.length >= 4 && p.state.duration > Duration.zero) break;
    }
    final p = player!;
    final mpv = p.platform as NativePlayer;
    await pumpFor(tester, const Duration(seconds: 2));

    // Die Bibliothek entscheidet über Sprache und Stil.
    expect(p.state.track.subtitle.language, 'ger');
    expect(await mpv.getProperty('sub-color'), '#FFFFE14D');
    expect(await mpv.getProperty('sub-font'), SubtitleFont.serif.family);
    expect(double.parse(await mpv.getProperty('sub-scale')), 1.5);
    expect(await mpv.getProperty('sub-pos'), '90');

    // Panel öffnen: über "Audio & Untertitel".
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(420, 320));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.subtitles_rounded));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.format_size_rounded));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Anime'), findsOneWidget);

    // Farbe ändern gilt sofort – für die Bibliothek, weil sie schon eigene Regeln hat.
    await tester.ensureVisible(find.bySemanticsLabel(tr.subtitleColorCyan));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.bySemanticsLabel(tr.subtitleColorCyan));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(await mpv.getProperty('sub-color'), '#FF7FE7FF');

    // "Überall" ändert nur das Allgemeine – das Bild dieser Bibliothek bleibt.
    await tester.ensureVisible(find.text(tr.subtitleScopeAll));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text(tr.subtitleScopeAll));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.ensureVisible(find.bySemanticsLabel(tr.subtitleColorGreen));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.bySemanticsLabel(tr.subtitleColorGreen));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(await mpv.getProperty('sub-color'), '#FF7FE7FF');

    // Zurück zur Bibliothek und auf das allgemeine Aussehen setzen: jetzt gilt Grün.
    await tester.ensureVisible(find.text('Anime'));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('Anime'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    final reset = find.text(tr.subtitleUseGeneral);
    await tester.ensureVisible(reset);
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(reset);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(await mpv.getProperty('sub-color'), '#FF8CFF9E');
    expect(await mpv.getProperty('sub-font'), SubtitleFont.standard.family);
  });
}
