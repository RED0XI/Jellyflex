import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/format.dart';
import 'package:jellyflex/core/images.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/secure_store.dart';
import 'package:jellyflex/l10n/strings.dart';

void main() {
  // Diese Tests prüfen die deutschen Texte.
  setUp(() => appLanguage = AppLanguage.de);

  group('Images (wie jellyfin-web)', () {
    final episode = BaseItem({
      'Id': 'ep1',
      'Type': 'Episode',
      'SeriesId': 'series1',
      'ImageTags': {'Primary': 'still'},
      'SeriesPrimaryImageTag': 'seriesPoster',
      'SeriesThumbImageTag': 'seriesThumb',
      'ParentPrimaryImageItemId': 'season1',
      'ParentPrimaryImageTag': 'seasonPoster',
      'ParentBackdropItemId': 'series1',
      'ParentBackdropImageTags': ['bd0', 'bd1'],
      'ParentLogoItemId': 'series1',
      'ParentLogoImageTag': 'logo',
      'ImageBlurHashes': {
        'Primary': {'still': 'HASH_STILL', 'seasonPoster': 'HASH_SEASON'},
        'Backdrop': {'bd0': 'HASH_BD0', 'bd1': 'HASH_BD1'},
      },
    });

    test('Episode-Poster nutzt Staffelposter (preferParentPoster)', () {
      final ref = Images.poster(episode)!;
      expect(ref.itemId, 'season1');
      expect(ref.tag, 'seasonPoster');
      expect(ref.blurHash, 'HASH_SEASON');
    });

    test('Episode-Querformat nutzt Standbild der Folge', () {
      final ref = Images.landscape(episode)!;
      expect(ref.itemId, 'ep1');
      expect(ref.type, ImageType.primary);
      expect(ref.blurHash, 'HASH_STILL');
    });

    test('Ohne Episodenbilder wird das Serien-Thumb bevorzugt', () {
      final ref = Images.landscape(episode, episodeImages: false)!;
      expect(ref.itemId, 'series1');
      expect(ref.type, ImageType.thumb);
    });

    test('Backdrops werden mit allen Indizes von der Serie geerbt', () {
      final refs = Images.backdrops(episode);
      expect(refs.map((r) => r.index), [0, 1]);
      expect(refs.every((r) => r.itemId == 'series1'), isTrue);
      expect(refs.last.blurHash, 'HASH_BD1');
    });

    test('Logo wird von der Serie geerbt', () {
      expect(Images.logo(episode)!.itemId, 'series1');
    });

    test('Film ohne Thumb fällt im Querformat auf Backdrop zurück', () {
      final movie = BaseItem({
        'Id': 'm1',
        'Type': 'Movie',
        'ImageTags': {'Primary': 'p'},
        'BackdropImageTags': ['b'],
      });
      final ref = Images.landscape(movie)!;
      expect(ref.type, ImageType.backdrop);
      expect(ref.index, 0);
    });

    test('Bild-URL nutzt fillWidth/fillHeight und Index', () {
      final api = JellyfinApi(baseUrl: 'https://srv/jellyfin', deviceId: 'd');
      final url = api.imageUrl(Images.backdrops(episode)[1], fillWidth: 640, fillHeight: 360);
      expect(url, startsWith('https://srv/jellyfin/Items/series1/Images/Backdrop/1?'));
      expect(url, contains('tag=bd1'));
      expect(url, contains('fillWidth=640'));
      expect(url, contains('fillHeight=360'));
    });
  });

  group('Spuren & Untertitel', () {
    final source = MediaSource({
      'Id': 'ms',
      'DefaultAudioStreamIndex': 3,
      'MediaStreams': [
        {'Type': 'Video', 'Index': 0},
        {'Type': 'Subtitle', 'Index': 4, 'Codec': 'ass'},
        {'Type': 'Audio', 'Index': 2, 'Language': 'eng'},
        {'Type': 'Audio', 'Index': 3, 'Language': 'ger'},
        {'Type': 'Subtitle', 'Index': 5, 'Codec': 'subrip', 'IsExternal': true},
      ],
    });

    test('Eingebettete Spuren in Dateireihenfolge, externe ausgenommen', () {
      expect(source.embeddedStreams('Audio').map((s) => s.index), [2, 3]);
      expect(source.embeddedStreams('Subtitle').map((s) => s.index), [4]);
    });

    test('Externe SRT-Untertitel bekommen die passende URL', () {
      final api = JellyfinApi(baseUrl: 'https://srv', deviceId: 'd');
      final ext = source.mediaStreams.firstWhere((s) => s.isExternal);
      expect(api.subtitleUrl('item', 'ms', ext), 'https://srv/Videos/item/ms/Subtitles/5/Stream.srt');
    });
  });

  group('Trickplay & Abschnitte', () {
    test('Trickplay wählt die Auflösung nahe 320 px', () {
      final item = BaseItem({
        'Id': 'x',
        'Trickplay': {
          'ms': {
            '160': {'Width': 160, 'Height': 90},
            '320': {'Width': 320, 'Height': 180, 'TileWidth': 10, 'TileHeight': 10, 'Interval': 10000},
            '640': {'Width': 640, 'Height': 360},
          },
        },
      });
      final info = item.trickplay('ms')!;
      expect(info.width, 320);
      expect(info.interval, const Duration(seconds: 10));
      expect(item.trickplay('other'), isNull);
    });

    test('MediaSegment erkennt Position im Intro', () {
      final intro = MediaSegment({'Type': 'Intro', 'StartTicks': 600000000, 'EndTicks': 1500000000});
      expect(intro.start, const Duration(seconds: 60));
      expect(intro.end, const Duration(seconds: 150));
      expect(intro.contains(const Duration(seconds: 90)), isTrue);
      expect(intro.contains(const Duration(seconds: 150)), isFalse);
    });
  });

  group('Formatierung', () {
    test('Laufzeit und Zeitcode', () {
      expect(formatRuntime(const Duration(minutes: 105)), '1 Std. 45 Min.');
      expect(formatRuntime(const Duration(minutes: 48)), '48 Min.');
      expect(formatTimecode(const Duration(hours: 1, minutes: 5, seconds: 9)), '1:05:09');
      expect(formatTimecode(const Duration(minutes: 5, seconds: 9)), '5:09');
      expect(formatTimecode(Duration.zero), '0:00');
    });

    test('Server-Adresse wird normalisiert', () {
      expect(JellyfinApi.normalizeUrl('server.ts.net/jellyfin/'), 'https://server.ts.net/jellyfin');
      expect(JellyfinApi.normalizeUrl(' http://192.168.1.2:8096 '), 'http://192.168.1.2:8096');
    });

    test('Sprachcodes werden übersetzt', () {
      expect(languageName('ger'), 'Deutsch');
      expect(languageName('eng'), 'Englisch');
      expect(languageName(null), 'Unbekannt');
    });
  });

  group('SecureStore (DPAPI)', () {
    test('Speichert verschlüsselt und liest wieder', () async {
      final dir = await Directory.systemTemp.createTemp('jellyflex_test');
      final file = File('${dir.path}${Platform.pathSeparator}secure.bin');
      try {
        final store = SecureStore.forFile(file);
        await store.write(key: 'token', value: 'geheim-123');
        // Datei darf den Klartext nicht enthalten.
        final raw = await file.readAsBytes();
        expect(String.fromCharCodes(raw).contains('geheim-123'), isFalse);

        final reloaded = SecureStore.forFile(file);
        expect(await reloaded.read(key: 'token'), 'geheim-123');
        await reloaded.delete(key: 'token');
        expect(await SecureStore.forFile(file).read(key: 'token'), isNull);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
