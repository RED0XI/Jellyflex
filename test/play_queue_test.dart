import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/play_queue.dart';

void main() {
  test('Zufallswiedergabe: nächster Titel der Warteschlange', () {
    PlayQueue.start(['a', 'b', 'c']);
    expect(PlayQueue.contains('b'), isTrue);
    expect(PlayQueue.after('a'), 'b');
    expect(PlayQueue.after('c'), isNull, reason: 'Am Ende ist Schluss');
    expect(PlayQueue.after('x'), isNull, reason: 'Gehört nicht dazu');
    PlayQueue.clear();
    expect(PlayQueue.contains('a'), isFalse);
  });
}
