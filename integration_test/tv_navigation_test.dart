// Bedienung mit der Fernbedienung – auf dem Desktop simuliert: Die App läuft im Fernseher-Modus
// (PlatformInfo.isTv), die Tasten kommen wie von einer Android-Fernbedienung (OK = "select").
// Prüft die Wege, die mit dem Steuerkreuz schiefgingen: Menüleiste von Unterseiten aus, "Zurück"
// auf einem Bereich, Regler in den Untertitel-Einstellungen, gehaltenes OK, "Schaust du noch?".
//
// Voraussetzung:  dart run tool/mock_server.dart   (und $TMPDIR/jellyflex_test.mkv)
// Start:          flutter test integration_test/tv_navigation_test.dart -d macos

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/platform/platform_info.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/features/home/home_nav.dart';
import 'package:jellyflex/features/player/player_screen.dart';
import 'package:jellyflex/widgets/app_intro.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:jellyflex/widgets/window_frame.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  late ProviderContainer container;
  Player? player;
  String location() => container.read(routerProvider).state.uri.toString();

  Future<void> startApp(WidgetTester tester, {Directory? settingsDir}) async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1280, 760));
    PlatformInfo.isTv = true;
    PlayerScreen.debugBeforeOpen = (p) async => player = p;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings(settingsDir)),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
  }

  Future<void> stopApp(WidgetTester tester) async {
    container.read(routerProvider).go('/');
    await pumpFor(tester, const Duration(milliseconds: 800));
    PlatformInfo.isTv = false;
    await tester.pumpWidget(const SizedBox());
  }

  /// Taste der Fernbedienung drücken und loslassen.
  Future<void> key(WidgetTester tester, LogicalKeyboardKey k, {int wait = 350}) async {
    await tester.sendKeyDownEvent(k, platform: 'android');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyUpEvent(k, platform: 'android');
    await pumpFor(tester, Duration(milliseconds: wait));
  }

  /// Hat ein Vorfahre des fokussierten Elements den Typ [T]?
  bool focusIn<T extends Widget>() {
    var hit = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
      if (e.widget is T) hit = true;
      return !hit;
    });
    return hit;
  }

  /// Links, bis der Fokus in der Menüleiste steht.
  Future<void> toRail(WidgetTester tester) async {
    for (var i = 0; i < 8 && !focusIn<TvNavRail>(); i++) {
      await key(tester, LogicalKeyboardKey.arrowLeft);
    }
    expect(focusIn<TvNavRail>(), isTrue, reason: 'links am Rand führt in die Menüleiste');
  }

  /// Erster sichtbarer Text im fokussierten Element (zum Nachsehen, wo der Fokus steht).
  String focusText() {
    var text = '';
    void visit(Element e) {
      if (text.isNotEmpty) return;
      final w = e.widget;
      if (w is Text && (w.data ?? '').isNotEmpty) {
        text = w.data!;
        return;
      }
      e.visitChildren(visit);
    }

    (FocusManager.instance.primaryFocus?.context as Element?)?.visitChildren(visit);
    return text;
  }

  Future<Player> waitForPlayer(WidgetTester tester) async {
    player = null;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((player?.state.duration ?? Duration.zero) > Duration.zero) break;
    }
    await pumpFor(tester, const Duration(milliseconds: 800));
    return player!;
  }

  testWidgets('Menüleiste von der Detailseite, zurück auf die Karte', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    expect(focusIn<LandscapeCard>() || focusIn<PosterCard>(), isTrue, reason: 'Start: Fokus auf einer Karte');
    final card = focusText();

    await key(tester, LogicalKeyboardKey.select);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(location(), startsWith('/item/'));

    // Links bis an den Rand: die Leiste öffnet sich (auf Unterseiten gehört kein Eintrag zur Seite).
    await toRail(tester);

    // Rechts: zurück auf die Seite – ohne Fehler (früher: Endlosrekursion).
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.takeException(), isNull);
    expect(focusIn<TvNavRail>(), isFalse, reason: 'rechts führt zurück auf die Seite');

    // Wieder in die Leiste, dann "Zurück": Startseite, Fokus wieder auf der Karte von vorhin.
    await toRail(tester);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await tester.binding.handlePopRoute();
    await pumpFor(tester, const Duration(milliseconds: 1200));
    expect(location(), '/');
    expect(focusIn<TvNavRail>(), isFalse, reason: 'der Fokus springt nach "Zurück" nicht in die Leiste');
    expect(focusText(), card, reason: 'Fokus wieder auf der Karte von vorhin');

    // Von der Leiste aus führt "rechts" immer auf die Seite.
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusIn<TvNavRail>(), isTrue);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.takeException(), isNull);
    expect(focusIn<TvNavRail>(), isFalse);

    await stopApp(tester);
  });

  testWidgets('Bereich über die Leiste; Zurück: erst Leiste, dann App zu', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusText(), 'Startseite');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusText(), 'Filme');
    await key(tester, LogicalKeyboardKey.select, wait: 1200);
    expect(location(), startsWith('/library/'));
    expect(focusIn<TvNavRail>(), isFalse, reason: 'nach der Wahl liegt der Fokus auf der Seite');

    // Bereich gewählt und sofort wieder links: nichts hängt, rechts führt auf die Seite.
    await toRail(tester);
    expect(focusText(), 'Filme', reason: 'die Leiste öffnet auf dem Eintrag der aktuellen Seite');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusText(), 'Serien');
    await key(tester, LogicalKeyboardKey.select, wait: 60);
    await key(tester, LogicalKeyboardKey.arrowLeft, wait: 1000);
    expect(location(), contains('lib-shows'));
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.takeException(), isNull);
    }
    expect(focusIn<TvNavRail>(), isFalse);

    // Zurück auf einem Bereich: erst in die Leiste, erst das zweite Zurück verlässt die App.
    await tester.binding.handlePopRoute();
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(exits, 0, reason: 'das erste Zurück beendet die App nicht');
    expect(focusIn<TvNavRail>(), isTrue);
    await tester.binding.handlePopRoute();
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(exits, 1);

    await stopApp(tester);
  });

  testWidgets('Regler in den Untertitel-Einstellungen fangen den Fokus nicht', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    container.read(routerProvider).go('/settings?section=playback');
    await pumpFor(tester, const Duration(milliseconds: 1500));

    // Bis in die Schrift-Auswahl wandern, von dort hoch auf den Regler "Position".
    for (var i = 0; i < 30 && focusText() != 'Standard'; i++) {
      await key(
        tester,
        focusText() == 'Rund' || focusText() == 'Klar' || focusText() == 'Serifen' || focusText() == 'Schreibmaschine'
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowDown,
        wait: 150,
      );
      if (focusIn<Slider>()) break;
      // Unterhalb der Schrift-Auswahl angekommen: von dort nach links in die Auswahl.
      if (i > 8 && focusText().isEmpty) await key(tester, LogicalKeyboardKey.arrowLeft, wait: 150);
    }
    for (var i = 0; i < 4 && !focusIn<Slider>(); i++) {
      await key(tester, LogicalKeyboardKey.arrowUp, wait: 200);
    }
    expect(focusIn<Slider>(), isTrue, reason: 'Regler mit dem Steuerkreuz erreichbar');
    final before = container.read(settingsProvider).subtitleStyle;

    // Runter verlässt den Regler und ändert nichts.
    await key(tester, LogicalKeyboardKey.arrowDown, wait: 200);
    expect(focusIn<Slider>(), isFalse, reason: 'runter führt vom Regler weg');
    expect(container.read(settingsProvider).subtitleStyle, before);

    // Zurück auf den Regler: rechts ändert den Wert.
    await key(tester, LogicalKeyboardKey.arrowUp, wait: 200);
    expect(focusIn<Slider>(), isTrue);
    await key(tester, LogicalKeyboardKey.arrowRight, wait: 200);
    expect(container.read(settingsProvider).subtitleStyle, isNot(before));
    expect(focusIn<Slider>(), isTrue);

    await stopApp(tester);
  });

  testWidgets('Textfeld: Tastatur erst mit OK, nach "Fertig" bleibt der Fokus auf dem Feld', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    container.read(routerProvider).go('/search');
    await pumpFor(tester, const Duration(milliseconds: 1500));
    TextField field() => tester.widget<TextField>(find.byType(TextField).first);
    final node = tester.widget<EditableText>(find.byType(EditableText).first).focusNode;
    node.requestFocus();
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(field().readOnly, isTrue, reason: 'das Feld nur zu streifen öffnet keine Tastatur');

    await key(tester, LogicalKeyboardKey.select);
    expect(field().readOnly, isFalse, reason: 'OK auf dem Feld öffnet die Tastatur');

    // "Suchen"/"Fertig" auf der Bildschirmtastatur.
    await tester.testTextInput.receiveAction(field().textInputAction ?? TextInputAction.done);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(field().readOnly, isTrue);
    expect(node.hasPrimaryFocus, isTrue, reason: 'der Fokus bleibt auf dem Feld');

    await stopApp(tester);
  });

  testWidgets('Gehaltenes OK auf einer Karte öffnet nur die Detailseite', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select, platform: 'android');
    for (var i = 0; i < 12; i++) {
      await pumpFor(tester, const Duration(milliseconds: 150));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select, platform: 'android');
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select, platform: 'android');
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(location(), startsWith('/item/'), reason: 'die Tastenwiederholung startet nicht gleich die Wiedergabe');
    await stopApp(tester);
  });

  testWidgets('Player: OK kurz und lang, "Schaust du noch?"', (tester) async {
    if (!await demoServerRunning()) return;
    await startApp(tester);
    PlayerScreen.autoPlayedInARow = PlayerScreen.stillWatchingAfter;
    container.read(routerProvider).push('/play/series0_s1_e1?auto=1');
    final p = await waitForPlayer(tester);
    await pumpFor(tester, const Duration(seconds: 4)); // Bedienung blendet aus

    // OK halten: schneller, loslassen: wieder normal.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select, platform: 'android');
    await pumpFor(tester, const Duration(milliseconds: 900));
    expect(p.state.rate, 2.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select, platform: 'android');
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(p.state.rate, 1.0);
    expect(p.state.playing, isTrue);

    // OK kurz: Pause, noch einmal: weiter.
    await key(tester, LogicalKeyboardKey.select, wait: 500);
    expect(p.state.playing, isFalse);
    await key(tester, LogicalKeyboardKey.select, wait: 500);
    expect(p.state.playing, isTrue);

    // Ende der Folge nach drei Folgen ohne Bedienung: Abfrage – rechts/links wechselt den Knopf,
    // OK auf "Weiterschauen" startet die nächste Folge.
    PlayerScreen.autoPlayedInARow = PlayerScreen.stillWatchingAfter;
    await p.seek(p.state.duration - const Duration(seconds: 2));
    await pumpFor(tester, const Duration(seconds: 5));
    expect(find.text('Schaust du noch?'), findsOneWidget);
    expect(focusText(), 'Weiterschauen', reason: 'Fokus auf dem Knopf der Abfrage');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusText(), 'Player schließen');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusText(), 'Player schließen', reason: 'der Fokus wandert nicht auf die verdeckte Bedienung');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusText(), 'Weiterschauen');
    await key(tester, LogicalKeyboardKey.select, wait: 2000);
    expect(location(), contains('series0_s1_e2'));

    await stopApp(tester);
  });

  testWidgets('Intro: Tasten gehören dem Intro, die App darunter bleibt stehen', (tester) async {
    if (!await demoServerRunning()) return;
    final temp = Directory.systemTemp.createTempSync('jellyflex_tv_intro_');
    File('${temp.path}/settings.json').writeAsStringSync(
      jsonEncode({'language': 'de', 'lastSeenVersion': appVersion, 'intro': true, 'soundEffects': false}),
    );
    AppIntro.showInTests = true;
    AppIntro.debugReset();
    addTearDown(() {
      AppIntro.showInTests = false;
      temp.deleteSync(recursive: true);
    });
    await windowManager.ensureInitialized();
    PlatformInfo.isTv = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(DemoSession.new),
          settingsProvider.overrideWith(() => testSettings(temp)),
        ],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    await pumpFor(tester, const Duration(milliseconds: 1500));
    expect(AppIntro.showing, isTrue);
    final frame = tester.state(find.byType(WindowFrame));
    final focused = FocusManager.instance.primaryFocus;

    // Pfeiltaste und OK überspringen das Intro – in der App darunter passiert nichts.
    await key(tester, LogicalKeyboardKey.arrowDown, wait: 60);
    expect(FocusManager.instance.primaryFocus, same(focused), reason: 'der Fokus unter dem Intro wandert nicht');
    await key(tester, LogicalKeyboardKey.select, wait: 1200);
    expect(AppIntro.showing, isFalse);
    expect(location(), '/', reason: 'OK hat unter dem Intro nichts ausgelöst');

    // Die App wurde am Ende des Intros nicht neu aufgebaut (sonst wäre z. B. der Controller weg).
    expect(tester.state(find.byType(WindowFrame)), same(frame));

    // Danach gehören die Tasten wieder der App.
    await key(tester, LogicalKeyboardKey.select, wait: 1500);
    expect(location(), startsWith('/item/'));

    await stopApp(tester);
  });
}
