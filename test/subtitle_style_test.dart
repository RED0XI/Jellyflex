import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/item_library.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/core/subtitle_style.dart';
import 'package:jellyflex/core/track_choice.dart';
import 'package:jellyflex/widgets/subtitle_style_editor.dart';

void main() {
  group('SubtitleStyle', () {
    test('Standard entspricht dem bisherigen Aussehen', () {
      final props = const SubtitleStyle().toMpv();
      expect(props['sub-bold'], 'yes');
      expect(props['sub-color'], '#FFFFFFFF');
      expect(props['sub-border-size'], '1.6');
      expect(props['sub-border-style'], 'outline-and-shadow');
      expect(props['sub-scale'], '1.00');
      expect(props['sub-pos'], '100');
      expect(props['sub-ass-override'], 'scale');
      expect(props['sub-back-color'], '#B3000000');
    });

    test('Einstellungen werden zu mpv-Werten', () {
      final props = const SubtitleStyle(
        scale: 1.5,
        font: SubtitleFont.serif,
        bold: false,
        color: 0xFFFFE14D,
        edge: SubtitleEdge.box,
        boxOpacity: 0.5,
        raise: 20,
        forceOnStyled: true,
      ).toMpv();
      expect(props['sub-font'], 'Georgia');
      expect(props['sub-bold'], 'no');
      expect(props['sub-color'], '#FFFFE14D');
      expect(props['sub-border-style'], 'background-box');
      expect(props['sub-back-color'], '#80000000');
      expect(props['sub-pos'], '80');
      expect(props['sub-scale'], '1.50');
      expect(props['sub-ass-override'], 'force');
    });

    test('Älteres mpv (Windows): Kasten nur, wenn er gewählt ist', () {
      // Ohne sub-border-style zeichnet mpv den Kasten, sobald sub-back-color nicht durchsichtig ist.
      final outline = const SubtitleStyle().toMpv(legacyBox: true);
      expect(outline.containsKey('sub-border-style'), isFalse);
      expect(outline['sub-back-color'], '#00000000');
      expect(outline['sub-border-size'], '1.6');

      final box = const SubtitleStyle(edge: SubtitleEdge.box, boxOpacity: 0.5).toMpv(legacyBox: true);
      expect(box.containsKey('sub-border-style'), isFalse);
      expect(box['sub-back-color'], '#80000000');
    });

    test('Speichern und Lesen; kaputte Werte werden begrenzt', () {
      const style = SubtitleStyle(scale: 1.4, font: SubtitleFont.mono, edge: SubtitleEdge.thick, raise: 10);
      expect(SubtitleStyle.fromJson(jsonDecode(jsonEncode(style.toJson()))), style);
      final odd = SubtitleStyle.fromJson({
        'scale': 99,
        'font': 'gibtsnicht',
        'edge': 'x',
        'raise': -5,
        'boxOpacity': 9,
      });
      expect(odd.scale, SubtitleStyle.maxScale);
      expect(odd.font, SubtitleFont.standard);
      expect(odd.edge, SubtitleEdge.outline);
      expect(odd.raise, 0);
      expect(odd.boxOpacity, 1.0);
    });
  });

  group('Einstellungen', () {
    test('Größe und Kasten älterer Versionen bleiben erhalten', () {
      final s = AppSettings.fromJson({'subtitleScale': 1.3, 'subtitleBackground': true});
      expect(s.subtitleStyle.scale, 1.3);
      expect(s.subtitleStyle.edge, SubtitleEdge.box);
      expect(AppSettings.fromJson(const {}).subtitleStyle, const SubtitleStyle());
    });

    test('Regeln je Bibliothek werden gespeichert und überstimmen die allgemeinen', () {
      const anime = SubtitleStyle(scale: 1.8, color: 0xFFFFE14D);
      final s = const AppSettings(subtitleLanguage: 'eng')
          .withLibrarySubtitles('anime', const LibrarySubtitles(style: anime, language: 'ger'));
      final loaded = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(loaded.subtitleStyleFor('anime'), anime);
      expect(loaded.subtitleLanguageFor('anime'), 'ger');
      expect(loaded.subtitleStyleFor('filme'), const SubtitleStyle());
      expect(loaded.subtitleLanguageFor('filme'), 'eng');
      expect(loaded.subtitleLanguageFor(null), 'eng');
    });

    test('Nur eine der beiden Regeln: der Rest kommt von den allgemeinen', () {
      final s = const AppSettings(subtitleLanguage: 'eng')
          .withLibrarySubtitles('a', const LibrarySubtitles(language: subtitlesOff));
      expect(s.subtitleLanguageFor('a'), subtitlesOff);
      expect(s.subtitleStyleFor('a'), s.subtitleStyle);
      expect(s.hasLibraryStyle('a'), isFalse);
    });

    test('Ohne eigene Werte fällt die Bibliothek aus der Liste', () {
      final s = const AppSettings().withLibrarySubtitles('a', const LibrarySubtitles(language: 'ger'));
      expect(s.subtitleLibraries, hasLength(1));
      expect(s.withLibrarySubtitles('a', const LibrarySubtitles()).subtitleLibraries, isEmpty);
    });

    test('Die Sprache der Bibliothek wählt die Spur; die gemerkte der Serie geht vor', () {
      final source = MediaSource({
        'Id': 's',
        'MediaStreams': [
          {'Index': 2, 'Type': 'Subtitle', 'Language': 'eng'},
          {'Index': 3, 'Type': 'Subtitle', 'Language': 'ger'},
        ],
      });
      final s = const AppSettings(subtitleLanguage: 'eng')
          .withLibrarySubtitles('anime', const LibrarySubtitles(language: 'ger'));
      expect(preferredSubtitleIndex(source, setting: s.subtitleLanguageFor('anime')), 3);
      expect(preferredSubtitleIndex(source, setting: s.subtitleLanguageFor('filme')), 2);
      expect(preferredSubtitleIndex(source, remembered: 'eng', setting: s.subtitleLanguageFor('anime')), 2);
    });
  });

  group('Bibliothek eines Titels', () {
    late Directory dir;
    late JellyfinApi api;
    var requests = 0;
    var offline = false;

    setUp(() async {
      requests = 0;
      offline = false;
      dir = await Directory.systemTemp.createTemp('jellyflex_libs');
      api = JellyfinApi(baseUrl: 'http://server.test', deviceId: 'test', token: 't', userId: 'u');
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            if (offline) {
              return handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {'Id': 'season', 'Type': 'Season'},
                  {'Id': 'folder', 'Type': 'Folder'},
                  {'Id': 'lib-anime', 'Type': 'CollectionFolder'},
                  {'Id': 'root', 'Type': 'UserRootFolder'},
                ],
              ),
            );
          },
        ),
      );
    });

    tearDown(() => dir.delete(recursive: true));

    test('Fragt einmal je Serie und merkt es sich über den Neustart hinaus', () async {
      final file = File('${dir.path}/libs.json');
      final libs = ItemLibraries.forFile(file);
      expect(await libs.resolve(api, itemId: 'ep1', seriesId: 'serie'), 'lib-anime');
      expect(await libs.resolve(api, itemId: 'ep2', seriesId: 'serie'), 'lib-anime');
      expect(requests, 1);

      offline = true;
      final reopened = ItemLibraries.forFile(file);
      expect(await reopened.resolve(api, itemId: 'ep3', seriesId: 'serie'), 'lib-anime');
      expect(requests, 1);
    });

    test('Ohne Server und ohne Merkzettel: unbekannt, kein Fehler', () async {
      offline = true;
      final libs = ItemLibraries.forFile(File('${dir.path}/libs.json'));
      expect(await libs.resolve(api, itemId: 'film'), isNull);
    });
  });

  testWidgets('Editor meldet Schrift, Farbe und Rand; Kasten zeigt die Deckkraft', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var style = const SubtitleStyle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: SubtitleStyleEditor(style: style, onChanged: (v) => setState(() => style = v)),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsNWidgets(2));
    await tester.tap(find.text('Serif'));
    await tester.pump();
    expect(style.font, SubtitleFont.serif);

    await tester.tap(find.text('Box'));
    await tester.pumpAndSettle();
    expect(style.edge, SubtitleEdge.box);
    expect(find.byType(Slider), findsNWidgets(3));

    await tester.tap(find.bySemanticsLabel('Yellow'));
    await tester.pump();
    expect(style.color, subtitleColors[1]);
  });
}
