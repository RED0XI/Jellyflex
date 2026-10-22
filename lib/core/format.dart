import 'models.dart';

/// "1 Std. 45 Min." bzw. "48 Min."
String formatRuntime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m Min.';
  if (m == 0) return '$h Std.';
  return '$h Std. $m Min.';
}

/// Player-Zeitanzeige: "1:05:09" bzw. "05:09"
String formatTimecode(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// "22:41"
String formatClock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Restlaufzeit für "Fortsetzen"-Buttons, z. B. "noch 34 Min."
String? remainingLabel(BaseItem item) {
  final total = item.runTimeTicks;
  final pos = item.userData.playbackPositionTicks;
  if (total == null || pos <= 0 || pos >= total) return null;
  return 'noch ${formatRuntime(ticksToDuration(total - pos))}';
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

const _languageNames = {
  'ger': 'Deutsch',
  'deu': 'Deutsch',
  'de': 'Deutsch',
  'eng': 'Englisch',
  'en': 'Englisch',
  'jpn': 'Japanisch',
  'ja': 'Japanisch',
  'fre': 'Französisch',
  'fra': 'Französisch',
  'fr': 'Französisch',
  'spa': 'Spanisch',
  'es': 'Spanisch',
  'ita': 'Italienisch',
  'it': 'Italienisch',
  'tur': 'Türkisch',
  'tr': 'Türkisch',
  'kor': 'Koreanisch',
  'ko': 'Koreanisch',
  'rus': 'Russisch',
  'ru': 'Russisch',
  'por': 'Portugiesisch',
  'pt': 'Portugiesisch',
  'dut': 'Niederländisch',
  'nld': 'Niederländisch',
  'nl': 'Niederländisch',
  'pol': 'Polnisch',
  'pl': 'Polnisch',
  'chi': 'Chinesisch',
  'zho': 'Chinesisch',
  'zh': 'Chinesisch',
  'und': 'Unbekannt',
};

String languageName(String? code) {
  if (code == null || code.isEmpty) return 'Unbekannt';
  return _languageNames[code.toLowerCase()] ?? code.toUpperCase();
}
