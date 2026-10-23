import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jeder Text der App muss in jeder Zusatzsprache übersetzt sein (sonst würde er
/// still auf Englisch erscheinen). Prüft die Quelltexte in lib/l10n.
void main() {
  // Texte, die in allen Sprachen gleich bleiben dürfen.
  const languageNeutral = {'watchedComparison'};

  Set<String> members(String source) =>
      {for (final m in RegExp(r'\n  (?:String\??|List<String>) (?:get )?(\w+)').allMatches(source)) m.group(1)!}
        ..remove('_t');

  test('Französisch, Spanisch und Türkisch sind vollständig', () {
    final base = File('lib/l10n/strings.dart').readAsStringSync();
    final all = members(base.substring(base.indexOf('class S {'))).difference(languageNeutral);
    for (final lang in ['fr', 'es', 'tr']) {
      final source = File('lib/l10n/strings_$lang.dart').readAsStringSync();
      final done = {
        for (final m in RegExp(r'@override\s+(?:String\??|List<String>) (?:get )?(\w+)').allMatches(source))
          m.group(1)!,
      };
      expect(all.difference(done), isEmpty, reason: 'Fehlende Übersetzungen ($lang)');
    }
  });
}
