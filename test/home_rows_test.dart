import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/home_rows.dart';
import 'package:jellyflex/core/settings.dart';

void main() {
  test('Reihen: Standard, Reihenfolge, ausgeblendet, unbekannte und neue Einträge', () {
    expect(HomeRows.parse(const []).map((r) => r.id), HomeRows.all);
    final rows = HomeRows.parse(const ['favorites', '!resume', 'quatsch', 'favorites']);
    expect(rows.first, (id: 'favorites', visible: true));
    expect(rows[1], (id: 'resume', visible: false));
    expect(rows.length, HomeRows.all.length, reason: 'fehlende Reihen werden ergänzt, Unbekanntes ignoriert');
    expect(HomeRows.encode(rows).take(2), ['favorites', '!resume']);
  });

  test('Reihen werden mit den Einstellungen gespeichert', () {
    final s = AppSettings.fromJson(const AppSettings(homeRows: ['!genres', 'libraries']).toJson());
    expect(s.homeRows.take(2), ['!genres', 'libraries']);
    expect(AppSettings.fromJson(const {}).homeRows, HomeRows.all);
  });
}
