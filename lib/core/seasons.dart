// Jahreszeitliche Akzente: Halloween, Weihnachten, Silvester, Valentinstag –
// je eine passende Reihe auf der Startseite und kleine Effekte über dem Banner.

import '../l10n/strings.dart';

enum Season {
  halloween,
  christmas,
  newYear,
  valentine;

  /// Name der Saison in der Sprache der Oberfläche.
  String get title => switch (this) {
    halloween => tr.halloween,
    christmas => tr.christmas,
    newYear => tr.newYearsEve,
    valentine => tr.valentinesDay,
  };
}

/// Uhr für die Saison-Erkennung (in Tests austauschbar).
DateTime Function() seasonClock = DateTime.now;

/// Aktuelle Saison oder `null`.
Season? currentSeason([DateTime? date]) {
  final d = date ?? seasonClock();
  final m = d.month;
  final day = d.day;
  if ((m == 10 && day >= 15) || (m == 11 && day == 1)) return Season.halloween;
  if (m == 12 && day <= 26) return Season.christmas;
  if ((m == 12 && day == 31) || (m == 1 && day == 1)) return Season.newYear;
  if (m == 2 && day >= 7 && day <= 14) return Season.valentine;
  return null;
}

class SeasonInfo {
  const SeasonInfo({required this.emoji, this.genres = const [], this.keywords = const []});

  final String emoji;

  /// Genres für die Reihe (deutsche und englische Namen, je nach Metadaten).
  final List<String> genres;

  /// Wörter im Titel, die gut passen (z. B. "Weihnacht", "Christmas").
  final List<String> keywords;
}

const seasonInfo = <Season, SeasonInfo>{
  Season.halloween: SeasonInfo(
    emoji: '🎃',
    genres: ['Horror', 'Mystery', 'Thriller'],
    keywords: ['Halloween', 'Hexe', 'Witch', 'Vampir', 'Vampire', 'Zombie', 'Geist', 'Ghost'],
  ),
  Season.christmas: SeasonInfo(
    emoji: '🎄',
    keywords: ['Weihnacht', 'Christmas', 'Santa', 'Grinch', 'Xmas', 'Nikolaus', 'Kevin', 'Polar Express'],
  ),
  Season.newYear: SeasonInfo(
    emoji: '🥂',
    genres: ['Komödie', 'Comedy'],
    keywords: ['Silvester', 'New Year', 'Dinner for One', 'Party'],
  ),
  Season.valentine: SeasonInfo(emoji: '💘', genres: ['Liebesfilm', 'Romantik', 'Romance'], keywords: ['Love', 'Liebe']),
};
