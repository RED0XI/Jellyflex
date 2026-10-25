import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/performance_check.dart';

void main() {
  test('Kennzahlen einer Messreihe', () {
    final s = PerformanceCheck.stats([5, 1, 3, 2, 4, 10, 6, 7, 8, 9]);
    expect(s['n'], 10);
    expect(s['min'], 1);
    expect(s['max'], 10);
    expect(s['median'], 6);
    expect(s['p90'], 9);
    expect(s['avg'], 5.5);
  });

  test('leere Messreihe', () {
    expect(PerformanceCheck.stats([]), {'n': 0});
  });

  test('Werte werden auf eine Nachkommastelle gerundet', () {
    final s = PerformanceCheck.stats([1.234, 2.345]);
    expect(s['min'], 1.2);
    expect(s['max'], 2.3);
  });
}
