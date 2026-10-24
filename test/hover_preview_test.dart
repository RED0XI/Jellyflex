import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/widgets/hover_preview.dart';

void main() {
  test('Szenen-Vorschau: wenige Kacheln, keine Abspann-Bilder', () {
    // 100 Minuten, alle 10 Sekunden ein Bild, 10×10 pro Kachel.
    final info = TrickplayInfo({'ThumbnailCount': 600, 'TileWidth': 10, 'TileHeight': 10, 'Interval': 10000});
    final frames = scenesFrom(info);
    expect(frames, hasLength(9));
    expect(frames.toSet(), hasLength(9), reason: 'Jede Szene nur einmal');
    expect(frames.map((f) => f ~/ 100).toSet(), hasLength(3), reason: 'Nur drei Kacheln laden');
    expect(frames.every((f) => f > 0 && f < 600 * 0.9), isTrue, reason: 'Nicht der Anfang, nicht der Abspann');

    // Kurzer Titel: alles in einer Kachel, trotzdem gültige Nummern.
    final short = scenesFrom(TrickplayInfo({'ThumbnailCount': 40, 'TileWidth': 10, 'TileHeight': 10}));
    expect(short, isNotEmpty);
    expect(short.every((f) => f < 40), isTrue);
  });
}
