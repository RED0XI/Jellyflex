import '../l10n/strings.dart';
import 'models.dart';

/// "1 Std. 45 Min." bzw. "1 hr 45 min"
String formatRuntime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return tr.minutes(m);
  if (m == 0) return tr.hours(h);
  return '${tr.hours(h)} ${tr.minutes(m)}';
}

/// Player-Zeitanzeige: "1:05:09" bzw. "5:09"
String formatTimecode(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  // Wie bei üblichen Playern: "0:05", "20:00", "1:00:00" – führende Null nur nach Stunden.
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// "22:41"
String formatClock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "12. März 1975" bzw. "March 12, 1975"
String formatDate(DateTime d) => tr.date(d);

/// "Donnerstag, 23. Oktober" bzw. "Thursday, October 23"
String formatWeekdayDate(DateTime d) => tr.weekdayDate(d);

/// Alter in Jahren am Tag [at] (Standard: heute).
int ageAt(DateTime birth, [DateTime? at]) {
  final day = at ?? DateTime.now();
  var age = day.year - birth.year;
  if (day.month < birth.month || (day.month == birth.month && day.day < birth.day)) age--;
  return age;
}

/// Restlaufzeit für "Fortsetzen"-Buttons, z. B. "noch 34 Min."
String? remainingLabel(BaseItem item) {
  final total = item.runTimeTicks;
  final pos = item.userData.playbackPositionTicks;
  if (total == null || pos <= 0 || pos >= total) return null;
  return tr.remaining(formatRuntime(ticksToDuration(total - pos)));
}

/// Jahr bzw. Jahresspanne bei Serien ("2019–2023", "2021–").
String? yearLabel(BaseItem item) {
  final start = item.productionYear;
  if (start == null) return null;
  if (!item.isSeries) return '$start';
  final end = item.endDate?.year;
  if (item.status == 'Continuing') return '$start–';
  if (end != null && end != start) return '$start–$end';
  return '$start';
}

/// Untertitel für Karten (Jahr, Episodenangabe …).
String? cardSubtitle(BaseItem item) {
  if (item.isEpisode) {
    final label = item.episodeLabel;
    return [?label, item.name].join(' · ');
  }
  if (item.isSeason) return item.seriesName;
  return yearLabel(item);
}

/// Haupttitel für Karten (bei Episoden der Serienname).
String cardTitle(BaseItem item) => item.isEpisode ? (item.seriesName ?? item.name) : item.name;

/// Fortschritt 0..1 für die Fortschrittsleiste auf Karten.
double? progressOf(BaseItem item) {
  final pct = item.userData.playedPercentage;
  if (pct != null && pct > 0 && pct < 100) return pct / 100;
  final total = item.runTimeTicks;
  final pos = item.userData.playbackPositionTicks;
  if (total != null && total > 0 && pos > 0) return (pos / total).clamp(0, 1).toDouble();
  return null;
}

/// Sprachcodes (ISO 639-2 wie "ger"/"deu", ISO 639-1 wie "de") → einheitlicher Code.
const _languageCodes = {
  'ger': 'de',
  'deu': 'de',
  'de': 'de',
  'eng': 'en',
  'en': 'en',
  'jpn': 'ja',
  'ja': 'ja',
  'fre': 'fr',
  'fra': 'fr',
  'fr': 'fr',
  'spa': 'es',
  'es': 'es',
  'ita': 'it',
  'it': 'it',
  'tur': 'tr',
  'tr': 'tr',
  'kor': 'ko',
  'ko': 'ko',
  'rus': 'ru',
  'ru': 'ru',
  'por': 'pt',
  'pt': 'pt',
  'dut': 'nl',
  'nld': 'nl',
  'nl': 'nl',
  'pol': 'pl',
  'pl': 'pl',
  'chi': 'zh',
  'zho': 'zh',
  'zh': 'zh',
};

/// Einheitlicher Sprachcode (z. B. "de") oder `null`, wenn unbekannt.
String? languageKey(String? code) => code == null ? null : _languageCodes[code.toLowerCase()];

/// Name einer Sprache in der Sprache der Oberfläche ("Deutsch" bzw. "German").
String languageName(String? code) {
  if (code == null || code.isEmpty || code.toLowerCase() == 'und') return tr.unknown;
  final key = languageKey(code);
  return (key == null ? null : tr.languageName(key)) ?? code.toUpperCase();
}
