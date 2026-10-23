import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/seasons.dart';

void main() {
  test('Saison nach Datum', () {
    expect(currentSeason(DateTime(2026, 10, 14)), isNull);
    expect(currentSeason(DateTime(2026, 10, 15)), Season.halloween);
    expect(currentSeason(DateTime(2026, 10, 31)), Season.halloween);
    expect(currentSeason(DateTime(2026, 11, 1)), Season.halloween);
    expect(currentSeason(DateTime(2026, 11, 2)), isNull);
    expect(currentSeason(DateTime(2026, 12, 1)), Season.christmas);
    expect(currentSeason(DateTime(2026, 12, 26)), Season.christmas);
    expect(currentSeason(DateTime(2026, 12, 27)), isNull);
    expect(currentSeason(DateTime(2026, 12, 31)), Season.newYear);
    expect(currentSeason(DateTime(2027, 1, 1)), Season.newYear);
    expect(currentSeason(DateTime(2027, 1, 2)), isNull);
    expect(currentSeason(DateTime(2027, 2, 6)), isNull);
    expect(currentSeason(DateTime(2027, 2, 14)), Season.valentine);
    expect(currentSeason(DateTime(2027, 2, 15)), isNull);
  });
}
