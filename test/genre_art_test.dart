import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/features/genre/genre_screen.dart';

BaseItem _item(String id, List<String> genres, {bool backdrop = true}) => BaseItem({
  'Id': id,
  'Name': id,
  'Type': 'Movie',
  'Genres': genres,
  'BackdropImageTags': backdrop ? ['tag-$id'] : <String>[],
});

void main() {
  test('Genre-Kacheln: jedes Bild höchstens einmal', () {
    // Ein Titel mit vielen Genres darf nicht überall auftauchen.
    final pool = [
      _item('a', ['Action', 'Drama', 'Comedy']),
      _item('b', ['Action']),
      _item('c', ['Drama', 'Comedy']),
    ];
    final art = assignGenreArt(['Action', 'Drama', 'Comedy'], pool);
    expect(art.length, 3, reason: 'Alle drei Genres bekommen ein Bild');
    expect(art.values.map((i) => i.id).toSet().length, 3, reason: 'Kein Bild doppelt');
  });

  test('Genre-Kacheln: mehr Genres als passende Titel – die übrigen bleiben frei', () {
    final pool = [
      _item('a', ['Action', 'Drama']),
      _item('b', ['Krimi'], backdrop: false),
    ];
    final art = assignGenreArt(['Action', 'Drama', 'Krimi'], pool);
    expect(art.length, 1);
    expect(art.containsKey('Krimi'), isFalse, reason: 'Ohne Hintergrundbild kein Kandidat');
  });
}
