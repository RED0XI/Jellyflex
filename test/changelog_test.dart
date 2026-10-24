import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/changelog.dart';
import 'package:jellyflex/core/version.dart';
import 'package:jellyflex/l10n/strings.dart';

void main() {
  test('Neuigkeiten zwischen zwei Versionen, neueste zuerst', () {
    appLanguage = AppLanguage.en;
    expect(changesSince('0.2.0', '0.3.4').map((c) => c.version), ['0.3.4', '0.3.2', '0.3.0']);
    expect(changesSince('0.3.2', '0.3.3'), isEmpty, reason: '0.3.3 hat keine Neuigkeiten');
    expect(changesSince('0.3.4', '0.3.4'), isEmpty);
    expect(compareVersions('0.10.0', '0.9.9'), greaterThan(0));
  });

  test('Jeder Eintrag hat englische und deutsche Texte, die aktuelle Version ist nicht älter', () {
    for (final MapEntry(key: v, value: e) in changelog.entries) {
      expect(e.en, isNotEmpty, reason: v);
      expect(e.de.length, e.en.length, reason: v);
    }
    // Neueste Neuigkeiten gehören höchstens zur nächsten Version.
    final newest = (changelog.keys.toList()..sort(compareVersions)).last;
    expect(compareVersions(newest, appVersion), lessThanOrEqualTo(1 + 0), reason: 'Eintrag $newest');
  });
}
