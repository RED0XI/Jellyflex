import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/series_tracks.dart';
import 'package:jellyflex/core/settings.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('jellyflex_series_tracks_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Sprachen je Serie und Konto, auch nach Neustart', () {
    final file = File('${dir.path}\\series_tracks.json');
    final store = SeriesTracks.forFile(file);
    store.setAudio('konto1', 'serieA', 'jpn');
    store.setSubtitle('konto1', 'serieA', 'ger');
    store.setSubtitle('konto1', 'serieB', subtitlesOff);

    // Neu laden (wie nach einem Neustart).
    final again = SeriesTracks.forFile(file);
    expect(again.get('konto1', 'serieA'), (audio: 'jpn', subtitle: 'ger'));
    expect(again.get('konto1', 'serieB'), (audio: null, subtitle: subtitlesOff));
    expect(again.get('konto2', 'serieA'), (audio: null, subtitle: null), reason: 'Anderes Konto');
  });

  test('Beschädigte Datei → neu anfangen', () {
    final file = File('${dir.path}\\series_tracks.json')..writeAsStringSync('{kaputt');
    final store = SeriesTracks.forFile(file);
    expect(store.get('k', 's'), (audio: null, subtitle: null));
    store.setAudio('k', 's', 'eng');
    expect(SeriesTracks.forFile(file).get('k', 's').audio, 'eng');
  });
}
