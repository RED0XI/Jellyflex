import '../l10n/strings.dart';

/// Neuigkeiten je Version – fest in der App (offline, ohne Server oder GitHub).
/// Englisch und Deutsch; andere Sprachen zeigen Englisch. Neue Version: oben
/// einen Eintrag ergänzen (Versionen ohne Eintrag erscheinen nicht).
const changelog = <String, ({List<String> en, List<String> de})>{
  '0.3.4': (
    en: ['After an update, this window shows what’s new.'],
    de: ['Nach einem Update zeigt dieses Fenster, was neu ist.'],
  ),
  '0.3.2': (
    en: [
      'Updates install themselves: “Update” or “Restart now” – or simply when you close Jellyflex.',
      'Notices at the bottom of the window are readable again.',
    ],
    de: [
      'Updates installieren sich selbst: „Aktualisieren“ oder „Jetzt neu starten“ – oder einfach beim Schließen.',
      'Hinweise unten im Fenster sind wieder gut lesbar.',
    ],
  ),
  '0.3.0': (
    en: [
      'Downloads: choose the folder, only on Wi-Fi/LAN, speed limit, smaller versions with your languages.',
      'Smart downloads delete watched episodes and fetch the next ones.',
      '“Scenes” on the details page, audio and subtitle language remembered per series.',
      'New titles show up by themselves; the player remembers your volume.',
      'A profile with a PIN can lock itself when you’re away.',
    ],
    de: [
      'Downloads: Ordner wählbar, nur über WLAN/LAN, Tempo-Grenze, kleinere Fassung mit deinen Sprachen.',
      'Smart Downloads löschen gesehene Folgen und laden die nächsten.',
      '„Szenen“ auf der Detailseite, Ton- und Untertitelsprache je Serie gemerkt.',
      'Neue Titel erscheinen von selbst; der Player merkt sich die Lautstärke.',
      'Ein Profil mit PIN kann sich bei Abwesenheit sperren.',
    ],
  ),
};

/// Versionsnummer "1.2.3" zum Vergleichen.
List<int> _parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

int compareVersions(String a, String b) {
  final x = _parts(a);
  final y = _parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Neuigkeiten aller Versionen nach [since] bis einschließlich [current], neueste zuerst.
List<({String version, List<String> items})> changesSince(String since, String current) {
  final versions =
      changelog.keys.where((v) => compareVersions(v, since) > 0 && compareVersions(v, current) <= 0).toList()
        ..sort((a, b) => compareVersions(b, a));
  return [
    for (final v in versions) (version: v, items: appLanguage == AppLanguage.de ? changelog[v]!.de : changelog[v]!.en),
  ];
}
