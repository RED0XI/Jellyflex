import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/format.dart';
import 'package:jellyflex/core/media_info.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/l10n/strings.dart';

void main() {
  tearDown(() => appLanguage = AppLanguage.en);

  test('Englisch ist Standard', () {
    expect(const AppSettings().language, AppLanguage.en);
    expect(AppSettings.fromJson(const {}).language, AppLanguage.en);
  });

  test('Englische Formate', () {
    appLanguage = AppLanguage.en;
    expect(formatRuntime(const Duration(minutes: 105)), '1 hr 45 min');
    expect(formatDate(DateTime(1975, 3, 12)), 'March 12, 1975');
    expect(formatWeekdayDate(DateTime(2026, 10, 23)), 'Friday, October 23');
    expect(languageName('ger'), 'German');
    expect(formatBitrate(62000000), '62.0 Mbit/s');
    expect(tr.decadeLabel(1980), '80s');
    expect(tr.episodesDownloading(1), '1 episode is downloading');
  });

  test('Deutsche Formate', () {
    appLanguage = AppLanguage.de;
    expect(formatRuntime(const Duration(minutes: 105)), '1 Std. 45 Min.');
    expect(formatDate(DateTime(1975, 3, 12)), '12. März 1975');
    expect(formatWeekdayDate(DateTime(2026, 10, 23)), 'Freitag, 23. Oktober');
    expect(languageName('eng'), 'Englisch');
    expect(formatBitrate(62000000), '62,0 Mbit/s');
    expect(tr.decadeLabel(1980), '80er');
  });

  test('Sprache wird mit den Einstellungen gespeichert', () {
    final json = const AppSettings(language: AppLanguage.de).toJson();
    expect(json['language'], 'de');
    expect(AppSettings.fromJson(json).language, AppLanguage.de);
  });

  test('Sprachvergleich unabhängig vom Code', () {
    expect(sameLanguage('ger', 'deu'), isTrue);
    expect(sameLanguage('de', 'ger'), isTrue);
    expect(sameLanguage('eng', 'ger'), isFalse);
    expect(sameLanguage('xyz', 'xyz'), isFalse, reason: 'Unbekannte Codes gelten nicht als gleich');
  });
}
