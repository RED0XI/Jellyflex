// Alle Texte der Oberfläche – Englisch (Standard) und Deutsch nebeneinander.
// Weitere Sprachen (Französisch, Spanisch, Türkisch) überschreiben die Texte in
// eigenen Dateien (strings_fr.dart …); was dort fehlt, erscheint auf Englisch.
//
// Verwendung überall (auch ohne BuildContext): `tr.downloads`, `tr.endsAt('22:41')`.

part 'strings_es.dart';
part 'strings_fr.dart';
part 'strings_tr.dart';

enum AppLanguage {
  en('English'),
  de('Deutsch'),
  fr('Français'),
  es('Español'),
  tr('Türkçe');

  const AppLanguage(this.nativeName);

  /// Name der Sprache in der Sprache selbst (für die Auswahl).
  final String nativeName;
}

/// Aktuelle Sprache der Oberfläche (wird aus den Einstellungen gesetzt).
AppLanguage appLanguage = AppLanguage.en;

/// Texte in der aktuellen Sprache.
S get tr => switch (appLanguage) {
  AppLanguage.en => S.en,
  AppLanguage.de => S.de,
  AppLanguage.fr => S.fr,
  AppLanguage.es => S.es,
  AppLanguage.tr => S.turkish,
};

class S {
  const S._(this._de);

  static const en = S._(false);
  static const de = S._(true);
  static const S fr = _Fr();
  static const S es = _Es();
  static const S turkish = _Tr();

  final bool _de;

  String _t(String en, String de) => _de ? de : en;

  // --- Allgemein ---------------------------------------------------------------

  String get retry => _t('Try again', 'Erneut versuchen');
  String get back => _t('Back', 'Zurück');
  String get close => _t('Close', 'Schließen');
  String get cancel => _t('Cancel', 'Abbrechen');
  String get delete => _t('Delete', 'Löschen');
  String get details => _t('Details', 'Details');
  String get play => _t('Play', 'Abspielen');
  String get resume => _t('Resume', 'Fortsetzen');
  String get pause => _t('Pause', 'Pause');
  String get off => _t('Off', 'Aus');
  String get storage => _t('Storage', 'Speicher');
  String get about => _t('About Jellyflex', 'Über Jellyflex');
  String get appVersionLabel => _t('App version', 'App-Version');
  String get updateCheck => _t('Look for updates', 'Nach Updates sehen');
  String get updateCheckHint => _t(
    'At start, asks GitHub only for the newest version number – nothing about you or your server. Off by default.',
    'Fragt beim Start nur GitHub nach der neuesten Versionsnummer – nichts über dich oder deinen Server. Standardmäßig aus.',
  );
  String get checkNow => _t('Check now', 'Jetzt prüfen');
  String updateAvailable(String v) => _t('Version $v is available', 'Version $v ist verfügbar');
  String get upToDate => _t('You have the newest version', 'Du hast die neueste Version');
  String get updateCheckFailed => _t('Couldn’t check for updates', 'Konnte nicht nach Updates sehen');
  String get errorReport => _t('Error report', 'Fehlerbericht');
  String get errorReportHint => _t(
    'Version, settings and recent messages as a text file – to pass on if something goes wrong.',
    'Version, Einstellungen und letzte Meldungen als Textdatei – zum Weitergeben, wenn etwas nicht klappt.',
  );
  String get errorReportPrivacy => _t(
    'Nothing is sent. Passwords, tokens, server address, names and your user folder are removed.',
    'Es wird nichts verschickt. Passwörter, Tokens, Server-Adresse, Namen und dein Benutzerordner sind entfernt.',
  );
  String get create => _t('Create', 'Erstellen');
  String get copy => _t('Copy', 'Kopieren');
  String get copied => _t('Copied', 'Kopiert');
  String get saveAs => _t('Save as …', 'Speichern unter …');
  String get imageCache => _t('Image cache', 'Bild-Zwischenspeicher');
  String imageCacheHint(String used) => _t(
    'Posters and backgrounds are kept on disk so they appear instantly. In use: $used',
    'Poster und Hintergründe bleiben auf der Festplatte und erscheinen sofort. Belegt: $used',
  );
  String get clearCache => _t('Clear', 'Leeren');
  String get cacheCleared => _t('Image cache cleared', 'Bild-Zwischenspeicher geleert');
  String get unknown => _t('Unknown', 'Unbekannt');
  String get library => _t('Library', 'Bibliothek');
  String get serverUnreachable =>
      _t('The server can’t be reached right now.', 'Der Server ist gerade nicht erreichbar.');
  String get didNotWork => _t('Sorry, that didn’t work.', 'Das hat leider nicht geklappt.');

  // --- Fenster -----------------------------------------------------------------

  String get minimize => _t('Minimize', 'Minimieren');
  String get maximize => _t('Maximize', 'Maximieren');
  String get restore => _t('Restore', 'Wiederherstellen');

  // --- Zeit & Zahlen -----------------------------------------------------------

  String hours(int h) => _t('$h hr', '$h Std.');
  String minutes(int m) => _t('$m min', '$m Min.');
  String remaining(String duration) => _t('$duration left', 'noch $duration');
  String endsAt(String time) => _t('Ends at $time', 'Endet um $time');
  String timeOfDay(int hour) => _t('$hour:00', '$hour:00 Uhr');
  String get midnight => _t('Midnight', 'Mitternacht');

  List<String> get months => _de
      ? const [
          'Januar',
          'Februar',
          'März',
          'April',
          'Mai',
          'Juni',
          'Juli',
          'August',
          'September',
          'Oktober',
          'November',
          'Dezember',
        ]
      : const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];

  List<String> get weekdays => _de
      ? const ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag']
      : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// "12. März 1975" bzw. "March 12, 1975"
  String date(DateTime d) =>
      _t('${months[d.month - 1]} ${d.day}, ${d.year}', '${d.day}. ${months[d.month - 1]} ${d.year}');

  /// "Donnerstag, 23. Oktober" bzw. "Thursday, October 23"
  String weekdayDate(DateTime d) => _t(
    '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}',
    '${weekdays[d.weekday - 1]}, ${d.day}. ${months[d.month - 1]}',
  );

  /// Sprachname zu einem ISO-639-1-Code ("de", "en" …).
  String? languageName(String code) => (_de ? _languagesDe : _languagesEn)[code];

  static const _languagesEn = {
    'de': 'German',
    'en': 'English',
    'ja': 'Japanese',
    'fr': 'French',
    'es': 'Spanish',
    'it': 'Italian',
    'tr': 'Turkish',
    'ko': 'Korean',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'nl': 'Dutch',
    'pl': 'Polish',
    'zh': 'Chinese',
  };
  static const _languagesDe = {
    'de': 'Deutsch',
    'en': 'Englisch',
    'ja': 'Japanisch',
    'fr': 'Französisch',
    'es': 'Spanisch',
    'it': 'Italienisch',
    'tr': 'Türkisch',
    'ko': 'Koreanisch',
    'ru': 'Russisch',
    'pt': 'Portugiesisch',
    'nl': 'Niederländisch',
    'pl': 'Polnisch',
    'zh': 'Chinesisch',
  };

  // --- Medieninfo ----------------------------------------------------------------

  String channels(int n) => _t('$n channels', '$n Kanäle');
  String get original => _t('Original', 'Original');
  String get version => _t('Version', 'Fassung');

  // --- Startseite --------------------------------------------------------------

  String get continueWatching => _t('Continue watching', 'Weiterschauen');
  String get nextUp => _t('Next up', 'Als Nächstes');
  String newIn(String library) => _t('New in $library', 'Neu in $library');
  String get yourFavorites => _t('Your favorites', 'Deine Favoriten');
  String get collections => _t('Collections', 'Sammlungen');
  String becauseYouWatched(String name) => _t('Because you watched “$name”', 'Weil du „$name“ angesehen hast');
  String becauseYouLike(String name) => _t('Because you like “$name”', 'Weil dir „$name“ gefällt');
  String moreFrom(String name) => _t('More from $name', 'Mehr von $name');
  String withPerson(String name) => _t('With $name', 'Mit $name');
  String get recommendations => _t('Recommendations', 'Empfehlungen');

  // --- Einstellungen -----------------------------------------------------------

  String get settings => _t('Settings', 'Einstellungen');
  String get language => _t('Language', 'Sprache');
  String get appLanguage => _t('App language', 'Sprache der App');
  String get appLanguageHint => _t('Menus, buttons and texts.', 'Menüs, Knöpfe und Texte.');
  String get playback => _t('Playback', 'Wiedergabe');
  String get preferredAudio => _t('Preferred audio track', 'Bevorzugte Tonspur');
  String get preferredAudioHint => _t('Chosen at start if available.', 'Wird beim Start gewählt, falls vorhanden.');
  String get preferredSubtitles => _t('Preferred subtitles', 'Bevorzugte Untertitel');
  String get preferredSubtitlesHint =>
      _t('Full subtitles are preferred over forced ones.', 'Vollständige Untertitel werden vor erzwungenen gewählt.');
  String get asInJellyfin => _t('As in Jellyfin', 'Wie in Jellyfin');
  String get quality => _t('Quality', 'Qualität');
  String get qualityHint => _t(
    'Original plays the file directly. Lower levels let the server convert it – good for slow connections.',
    'Original spielt die Datei direkt ab. Niedrigere Stufen lassen den Server umrechnen – gut bei langsamer Verbindung.',
  );
  String get ambilight => _t('Ambilight glow', 'Ambilight-Leuchten');
  String get ambilightHint => _t(
    'The picture’s colours glow softly in the black bars next to or above the video.',
    'Die Farben des Bildes leuchten sanft in den schwarzen Balken neben bzw. über dem Video.',
  );
  String get onlyInWindow => _t('Only in window', 'Nur im Fenster');
  String get always => _t('Always', 'Immer');
  String get alwaysInclFullscreen => _t('Always (also fullscreen)', 'Immer (auch Vollbild)');
  String get autoSkipIntro => _t('Skip intro & recap automatically', 'Intro & Rückblick automatisch überspringen');
  String get autoSkipIntroHint =>
      _t('Off: only the “Skip intro” button appears.', 'Aus: Es erscheint nur der Knopf „Intro überspringen“.');
  String get autoplayNext => _t('Play next episode automatically', 'Nächste Folge automatisch abspielen');
  String get autoplayNextHint => _t('With a countdown at the end of an episode.', 'Mit Countdown am Ende einer Folge.');
  String get subtitleAppearance => _t('Subtitle appearance', 'Untertitel-Darstellung');
  String get size => _t('Size', 'Größe');
  String get background => _t('Background', 'Hintergrund');
  String get subtitleBackgroundHint =>
      _t('Semi-transparent box behind the text.', 'Halbtransparenter Kasten hinter dem Text.');
  String get subtitlePreview => _t('This is how your subtitles look.', 'So sehen deine Untertitel aus.');
  String get home => _t('Home', 'Startseite');
  String get search => _t('Search', 'Suchen');
  String get more => _t('More', 'Mehr');
  String get goodMorning => _t('Good morning', 'Guten Morgen');
  String get goodAfternoon => _t('Good afternoon', 'Hallo');
  String get goodEvening => _t('Good evening', 'Guten Abend');
  String get coverStory => _t('Cover story', 'Titelgeschichte');
  String get layout => _t('Layout', 'Layout');
  String get watchlist => _t('Watchlist', 'Merkliste');
  String get myLists => _t('My lists', 'Meine Listen');
  String get addToWatchlist => _t('Add to watchlist', 'Auf die Merkliste');
  String get removeFromWatchlist => _t('Remove from watchlist', 'Von der Merkliste nehmen');
  String addedToWatchlist(String name) => _t('“$name” is on your watchlist', '„$name“ steht auf der Merkliste');
  String removedFromWatchlist(String name) =>
      _t('“$name” removed from your watchlist', '„$name“ von der Merkliste genommen');
  String get addToList => _t('Add to list', 'Zu Liste hinzufügen');
  String get addToListMenu => _t('Add to list …', 'Zu Liste hinzufügen …');
  String addedToList(String list) => _t('Added to “$list”', 'Zu „$list“ hinzugefügt');
  String get newList => _t('New list', 'Neue Liste');
  String get listNameHint => _t('Name, e.g. “Movie night”', 'Name, z. B. „Filmabend“');
  String get listsHint => _t(
    'Private lists on your Jellyfin server – available on all your devices.',
    'Private Listen auf deinem Jellyfin-Server – auf all deinen Geräten verfügbar.',
  );
  String get noListsYet => _t(
    'No lists yet. Use the bookmark on a title or “Add to list”.',
    'Noch keine Listen. Nutze das Lesezeichen bei einem Titel oder „Zu Liste hinzufügen“.',
  );
  String get listEmpty => _t('This list is empty.', 'Diese Liste ist leer.');
  String get deleteList => _t('Delete list', 'Liste löschen');
  String deleteListQuestion(String name) => _t('Delete “$name”?', '„$name“ löschen?');
  String get deleteListText => _t(
    'The list is deleted on your server. The titles themselves stay.',
    'Die Liste wird auf deinem Server gelöscht. Die Titel selbst bleiben.',
  );
  String removeFromList(String name) => _t('Remove “$name” from the list', '„$name“ aus der Liste entfernen');
  String get shortcuts => _t('Keyboard shortcuts', 'Tastenkürzel');
  String get shortcutsEverywhere => _t('Everywhere', 'Überall');
  String get shortcutsPlayer => _t('Player', 'Player');
  String get shortcutsController => _t('Controller', 'Controller');
  String get shortcutMoveFocus => _t('Move selection', 'Auswahl bewegen');
  String get shortcutOpen => _t('Open / choose', 'Öffnen / wählen');
  String get shortcutSeek => _t('10 s back / forward', '10 s zurück / vor');
  String get shortcutVolume => _t('Volume', 'Lautstärke');
  String get shortcutScreenshot => _t('Screenshot', 'Bildschirmfoto');
  String get shortcutMenu => _t('Menu (like right-click)', 'Menü (wie Rechtsklick)');
  String get keySpace => _t('Space', 'Leertaste');
  String get profilePin => _t('Profile PIN', 'Profil-PIN');
  String get profilePinHint => _t(
    'Optional: asks for a PIN before this profile opens on this computer.',
    'Optional: fragt nach einer PIN, bevor dieses Profil auf diesem Computer öffnet.',
  );
  String get profilePinOnHint =>
      _t('On – this profile only opens with its PIN.', 'An – dieses Profil öffnet nur mit seiner PIN.');
  String get pinSet => _t('Set PIN', 'PIN festlegen');
  String get pinChange => _t('Change PIN', 'PIN ändern');
  String get pinRemove => _t('Remove', 'Entfernen');
  String get pinSaved => _t('PIN saved', 'PIN gespeichert');
  String get pinRemoved => _t('PIN removed', 'PIN entfernt');
  String get pinCurrent => _t('Current PIN', 'Aktuelle PIN');
  String get pinChoose => _t('Choose a PIN', 'PIN wählen');
  String get pinChooseHint => _t('4 to 6 digits', '4 bis 6 Ziffern');
  String get pinRepeat => _t('Repeat PIN', 'PIN wiederholen');
  String get pinFormat => _t('Please enter 4 to 6 digits', 'Bitte 4 bis 6 Ziffern eingeben');
  String get pinWrong => _t('Wrong PIN', 'Falsche PIN');
  String pinLocked(int s) => _t('Too many tries – wait $s s', 'Zu viele Versuche – $s s warten');
  String pinFor(String name) => _t('PIN for $name', 'PIN für $name');
  String pinDigits(int n) => _t('$n digits entered', '$n Ziffern eingegeben');
  String get pinDelete => _t('Delete digit', 'Ziffer löschen');
  String get pinConfirm => _t('Confirm', 'Bestätigen');
  String get pinProtected => _t('Protected with PIN', 'Mit PIN geschützt');
  String downloadFinished(String name) => _t('“$name” is downloaded', '„$name“ ist heruntergeladen');
  String downloadsFinished(int n) => _t('$n downloads finished', '$n Downloads fertig');
  String get themeMusic => _t('Theme music', 'Titelmusik');
  String get themeMusicHint => _t(
    'Plays a title’s theme song quietly on its page (if your server has one).',
    'Spielt leise die Titelmusik auf der Detailseite (falls der Server eine hat).',
  );
  String get select => _t('Select', 'Auswählen');
  String get selected => _t('selected', 'ausgewählt');
  String get notSelected => _t('not selected', 'nicht ausgewählt');
  String selectedCount(int n) => _t('$n selected', '$n ausgewählt');
  String get selectAll => _t('Select all', 'Alle auswählen');
  String get endSelection => _t('End selection (Esc)', 'Auswahl beenden (Esc)');
  String get favorite => _t('Favorite', 'Favorit');
  String get selectionMarkedWatched => _t('Marked as watched', 'Als gesehen markiert');
  String get selectionMarkedUnwatched => _t('Marked as unwatched', 'Als ungesehen markiert');
  String get selectionAddedToFavorites => _t('Added to favorites', 'Zu Favoriten hinzugefügt');
  String get selectionDownloading => _t('Downloads started', 'Downloads gestartet');
  String get recentSearches => _t('Recent searches', 'Letzte Suchen');
  String get clearHistory => _t('Clear history', 'Verlauf löschen');
  String get filterAll => _t('All', 'Alle');
  String get people => _t('People', 'Personen');
  String get onlyUnwatched => _t('Only unwatched', 'Nur ungesehene');
  String removeSearch(String term) => _t('Remove “$term”', '„$term“ entfernen');
  String get recapOnlyYou => _t('Only your profile counts', 'Gezählt wird nur dein Profil');
  String get watched => _t('Watched', 'Gesehen');
  String get chapters => _t('Chapters', 'Kapitel');
  String get chaptersKey => _t('Chapters (C)', 'Kapitel (C)');
  String chapterN(int n) => _t('Chapter $n', 'Kapitel $n');
  String get screenshotSaved => _t('Screenshot saved to Pictures', 'Bildschirmfoto unter Bilder gespeichert');
  String get screenshotFailed => _t('Couldn’t take a screenshot', 'Bildschirmfoto hat nicht geklappt');
  String get statsTitle => _t('Playback info (I)', 'Wiedergabe-Infos (I)');
  String get statsPlayback => _t('Playback', 'Wiedergabe');
  String get statsDecoder => _t('Decoder', 'Dekodierung');
  String get statsSoftware => _t('Software (CPU)', 'Software (CPU)');
  String get statsHardware => _t('Hardware', 'Hardware');
  String get statsBuffer => _t('Buffer', 'Puffer');
  String get statsDropped => _t('Dropped frames', 'Ausgelassen');
  String get statsDirectPlay => _t('Direct play (original file)', 'Direkt (Originaldatei)');
  String get statsTranscoding => _t('Converted by the server', 'Vom Server umgerechnet');
  String get statsLocalFile => _t('Downloaded file', 'Heruntergeladene Datei');
  String episodesWatchedOf(int n, int total) => _t('$n of $total watched', '$n von $total gesehen');
  String downloadedOf(int n, int total) => _t('$n of $total downloaded', '$n von $total heruntergeladen');
  String get markSeasonWatched => _t('Mark season watched', 'Staffel als gesehen markieren');
  String get markSeasonUnwatched => _t('Mark season unwatched', 'Staffel als ungesehen markieren');
  String markSeasonWatchedQuestion(String season) =>
      _t('Mark “$season” as watched?', '„$season“ als gesehen markieren?');
  String markSeasonWatchedDetail(int n) => _t(
    'All $n episodes will be marked as watched. Your yearly recap won’t count them as watched time.',
    'Alle $n Folgen werden als gesehen markiert. Im Jahresrückblick zählen sie nicht als geschaute Zeit.',
  );
  String seasonMarkedWatched(String season) => _t('$season marked as watched', '$season als gesehen markiert');
  String seasonMarkedUnwatched(String season) => _t('$season marked as unwatched', '$season als ungesehen markiert');
  String recapMarkedNote(int n) => _t(
    '$n ${n == 1 ? 'title was' : 'titles were'} only marked as watched (not counted)',
    '$n ${n == 1 ? 'Titel wurde' : 'Titel wurden'} nur als gesehen markiert (nicht gezählt)',
  );
  String get layoutHint => _t(
    'Changes how the whole app is built – navigation, banner, cards, type. Colours stay as chosen below.',
    'Ändert den ganzen Aufbau – Navigation, Banner, Karten, Schrift. Die Farben bleiben wie unten gewählt.',
  );
  String get bannerTrailers => _t('Trailers in the banner', 'Trailer im Banner');
  String get bannerTrailersHint => _t(
    'After a few seconds, plays the title’s trailer muted (if available).',
    'Spielt nach ein paar Sekunden stumm den Trailer des Titels ab (falls vorhanden).',
  );
  String get screensaver => _t('Screensaver', 'Bildschirmschoner');
  String get screensaverHint => _t(
    'After a while without input, shows images of your movies and shows with a clock. Never during playback.',
    'Zeigt nach einer Weile ohne Eingabe Bilder deiner Filme und Serien mit Uhr. Nie während der Wiedergabe.',
  );
  String get showNow => _t('Show now', 'Jetzt anzeigen');
  String afterMinutes(int m) => _t('After $m min', 'Nach $m Min.');
  String get seasonalThemes => _t('Seasonal touches', 'Saisonale Akzente');
  String get seasonalThemesHint => _t(
    'For Halloween, Christmas, New Year’s Eve and Valentine’s Day: a matching row and small effects on the home page.',
    'Zu Halloween, Weihnachten, Silvester und Valentinstag: passende Reihe und kleine Effekte auf der Startseite.',
  );
  String get episodeImages => _t('Episode images in “Continue watching”', 'Episodenbilder bei „Weiterschauen“');
  String get episodeImagesHint => _t(
    'Off: show the series image instead of the episode still.',
    'Aus: Statt des Standbilds der Folge das Bild der Serie zeigen.',
  );
  String get personalize => _t('Personalize', 'Personalisieren');
  String get appName => _t('App name', 'Name der App');
  String get appNameHint => _t(
    'Shown in the title bar, the window title and at sign-in.',
    'Erscheint in der Titelleiste, im Fenstertitel und bei der Anmeldung.',
  );
  String get logo => _t('Logo', 'Logo');
  String get logoHint => _t(
    'An image (PNG, JPG …) – shown before the name and as the taskbar icon.',
    'Ein Bild (PNG, JPG …) – wird vor dem Namen und als Symbol in der Taskleiste gezeigt.',
  );
  String get sounds => _t('Sounds', 'Klänge');
  String get soundsHint => _t(
    'Ticks and jingles in “Surprise me” and the movie quiz.',
    'Ticken und Melodien bei „Überrasch mich“ und im Film-Quiz.',
  );
  String get theme => _t('Theme', 'Theme');
  String get themeHint => _t('Colours of the whole app – changes instantly.', 'Farben der ganzen App – wirkt sofort.');

  /// Name und Beschreibung eines Layouts (Englisch/Deutsch stehen im Layout selbst).
  String layoutName(String id, String en, String de) => _t(en, de);
  String layoutDescription(String id, String en, String de) => _t(en, de);

  String themeName(String id) => switch (id) {
    'midnight' => _t('Midnight', 'Mitternacht'),
    'oled' => _t('OLED Black', 'OLED-Schwarz'),
    'cinema' => _t('Cinema Red', 'Kinorot'),
    'frost' => _t('Nordic Frost', 'Nordischer Frost'),
    'sunset' => _t('Sunset', 'Sonnenuntergang'),
    'synthwave' => _t('Synthwave', 'Synthwave'),
    'emerald' => _t('Emerald', 'Smaragd'),
    'noir' => _t('Noir Gold', 'Noir-Gold'),
    _ => id,
  };
  String get images => _t('Images', 'Bilder');
  String get loading => _t('Loading …', 'Lädt …');
  String get chooseImage => _t('Choose image …', 'Bild wählen …');
  String get removeLogo => _t('Remove logo', 'Logo entfernen');
  String get imageUnreadable => _t('This image couldn’t be read.', 'Dieses Bild konnte nicht gelesen werden.');
  String get resetToJellyflex => _t('Reset to Jellyflex', 'Auf Jellyflex zurücksetzen');
  String get account => _t('Account', 'Konto');
  String get signOut => _t('Sign out', 'Abmelden');
  String basedOn(String name, String version) =>
      _t('$name · based on Jellyflex $version', '$name · basiert auf Jellyflex $version');

  /// Kommazahl mit dem passenden Dezimaltrennzeichen ("1.5" bzw. "1,5").
  String decimal(double value, int digits) {
    final text = value.toStringAsFixed(digits);
    return _de ? text.replaceAll('.', ',') : text;
  }

  // --- Detailseite -----------------------------------------------------------------

  String contentCouldNotLoad(Object e) =>
      _t('The content couldn’t be loaded.\n$e', 'Inhalt konnte nicht geladen werden.\n$e');
  String get moreEpisodes => _t('More episodes', 'Weitere Folgen');
  String seasonsCount(int n) => _t(n == 1 ? '1 season' : '$n seasons', n == 1 ? '1 Staffel' : '$n Staffeln');
  String seasonN(int n) => _t('Season $n', 'Staffel $n');
  String episodeN(int n) => _t('Episode $n', 'Folge $n');
  String get fromStart => _t('From the start', 'Von vorne');
  String versionLabel(String v) => _t('Version: $v', 'Fassung: $v');
  String get markUnplayed => _t('Mark as unwatched', 'Als ungesehen markieren');
  String get markPlayed => _t('Mark as watched', 'Als gesehen markieren');
  String get removeFavorite => _t('Remove from favorites', 'Aus Favoriten entfernen');
  String get addFavorite => _t('Add to favorites', 'Zu Favoriten hinzufügen');
  String get mediaInfoTooltip =>
      _t('Media info (resolution, audio, subtitles …)', 'Medieninfo (Auflösung, Ton, Untertitel …)');
  String get downloadOffline => _t('Download (watch offline)', 'Herunterladen (offline ansehen)');
  String get downloadedClickToDelete => _t('Downloaded – click to delete', 'Heruntergeladen – klicken zum Löschen');
  String get pauseDownload => _t('Pause download', 'Download pausieren');
  String get resumeDownload => _t('Resume download', 'Download fortsetzen');
  String get seasonAlreadyDownloaded =>
      _t('All episodes of this season are already downloaded', 'Alle Folgen dieser Staffel sind schon heruntergeladen');
  String episodesDownloading(int n) => _t(
    n == 1 ? '1 episode is downloading' : '$n episodes are downloading',
    n == 1 ? '1 Folge wird heruntergeladen' : '$n Folgen werden heruntergeladen',
  );
  String get downloadSeason => _t('Download season', 'Staffel herunterladen');
  String get thisEpisode => _t('This episode', 'Diese Folge');
  String get cast => _t('Cast', 'Besetzung');
  String get youMightLike => _t('You might also like', 'Das könnte dir auch gefallen');
  String get inThisCollection => _t('In this collection', 'In dieser Sammlung');

  // --- Medieninfo-Fenster ----------------------------------------------------------

  String get mediaInfo => _t('Media info', 'Medieninfo');
  String get format => _t('Format', 'Format');
  String get totalBitrate => _t('Total bitrate', 'Gesamtbitrate');
  String get runtime => _t('Runtime', 'Laufzeit');
  String get fileName => _t('File name', 'Dateiname');
  String get video => _t('Video', 'Video');
  String get resolution => _t('Resolution', 'Auflösung');
  String get codec => _t('Codec', 'Codec');
  String get dynamicRange => _t('Dynamic range', 'Dynamikumfang');
  String get bitDepth => _t('Bit depth', 'Farbtiefe');
  String get frameRate => _t('Frame rate', 'Bildrate');
  String get bitrate => _t('Bitrate', 'Bitrate');
  String audioCount(int n) => _t('Audio ($n)', 'Ton ($n)');
  String subtitlesCount(int n) => _t('Subtitles ($n)', 'Untertitel ($n)');
  String get defaultTrack => _t('Default', 'Standard');
  String get forced => _t('Forced', 'Erzwungen');

  // --- Kontextmenü -----------------------------------------------------------------

  String get playFromStart => _t('Play from the start', 'Von vorne abspielen');
  String get goToSeries => _t('Go to series', 'Zur Serie');
  String get alreadyWatched => _t('Already watched', 'Bereits angeschaut');
  String get forget => _t('Forget', 'Vergessen');
  String get download => _t('Download', 'Herunterladen');
  String get deleteDownload => _t('Delete download', 'Download löschen');
  String markedWatched(String name) => _t('“$name” marked as watched', '„$name“ als angeschaut markiert');
  String markedUnwatched(String name) => _t('“$name” marked as unwatched', '„$name“ als ungesehen markiert');
  String get addedToFavorites => _t('Added to favorites', 'Zu Favoriten hinzugefügt');
  String get removedFromFavorites => _t('Removed from favorites', 'Aus Favoriten entfernt');
  String downloadStarted(String name) => _t('Download started: $name', 'Download gestartet: $name');
  String get downloadDeleted => _t('Download deleted', 'Download gelöscht');
  String get removedFromContinue => _t('Removed from “Continue watching”', 'Aus „Weiterschauen“ entfernt');

  // --- Downloads-Seite ---------------------------------------------------------------

  String get downloads => _t('Downloads', 'Downloads');
  String get savedForOffline =>
      _t('Saved on this PC for offline viewing', 'Zum Offline-Schauen auf diesem PC gespeichert');
  String downloadsSummary(int count, String size) =>
      _t('$count ${count == 1 ? 'title' : 'titles'} · $size used', '$count Titel · $size belegt');
  String get openFolder => _t('Open folder', 'Ordner öffnen');
  String get noDownloadsYet => _t('No downloads yet.', 'Noch keine Downloads.');
  String get noDownloadsHint => _t(
    'Click “Download” on a details page or via right-click.',
    'Auf einer Detailseite oder per Rechtsklick auf „Herunterladen“ tippen.',
  );
  String get downloading => _t('Downloading', 'Wird heruntergeladen');
  String get readyOffline => _t('Ready to watch offline', 'Bereit zum Offline-Schauen');
  String get deleteDownloadQuestion => _t('Delete download?', 'Download löschen?');
  String deleteDownloadText(String name) => _t(
    '“$name” will be deleted from this PC. Everything stays on the server.',
    '„$name“ wird von diesem PC gelöscht. Auf dem Server bleibt alles erhalten.',
  );
  String get waiting => _t('Waiting …', 'Wartet …');
  String receivedOf(String received, String total) => _t('$received of $total', '$received von $total');
  String get starting => _t('Starting …', 'Startet …');
  String paused(String? reason) =>
      _t('Paused${reason != null ? ' – $reason' : ''}', 'Pausiert${reason != null ? ' – $reason' : ''}');
  String failed(String? reason) => _t('Failed: ${reason ?? 'unknown'}', 'Fehlgeschlagen: ${reason ?? 'unbekannt'}');
  String get done => _t('Done', 'Fertig');
  String get cancelAndDelete => _t('Cancel and delete', 'Abbrechen und löschen');

  // --- Anmeldung ------------------------------------------------------------------

  String get noServerAtAddress =>
      _t('No Jellyfin server was found at this address.', 'Unter dieser Adresse wurde kein Jellyfin-Server gefunden.');
  String get wrongCredentials => _t('Username or password is wrong.', 'Benutzername oder Passwort ist falsch.');
  String signInFailedCode(String code) => _t('Sign-in failed ($code).', 'Anmeldung fehlgeschlagen ($code).');
  String signInFailed(Object e) => _t('Sign-in failed: $e', 'Anmeldung fehlgeschlagen: $e');
  String get quickConnectExpired =>
      _t('Quick Connect expired. Please try again.', 'Quick Connect ist abgelaufen. Bitte erneut versuchen.');
  String get quickConnectFailed =>
      _t('Quick Connect couldn’t be started.', 'Quick Connect konnte nicht gestartet werden.');
  String get tagline => _t('Your cinema. On your desktop.', 'Dein Kino. Auf dem Desktop.');
  String get whoIsWatching => _t('Who’s watching?', 'Wer schaut?');
  String get addAccount => _t('Add account', 'Konto hinzufügen');
  String get toProfileSelection => _t('Back to profiles', 'Zur Profilauswahl');
  String get connectServer => _t('Connect to server', 'Server verbinden');
  String get enterServerAddress =>
      _t('Enter the address of your Jellyfin server.', 'Gib die Adresse deines Jellyfin-Servers ein.');
  String get serverAddress => _t('Server address', 'Server-Adresse');
  String get connect => _t('Connect', 'Verbinden');
  String get quickConnectHint => _t(
    'Open Jellyfin on a signed-in device → Profile → Quick Connect and enter this code:',
    'Öffne Jellyfin auf einem angemeldeten Gerät → Profil → Quick Connect und gib diesen Code ein:',
  );
  String get otherServer => _t('Other server', 'Anderer Server');
  String get certificateInvalid => _t(
    'The server’s security certificate is invalid. For your safety, Jellyflex won’t connect.',
    'Das Sicherheitszertifikat des Servers ist ungültig. Zu deiner Sicherheit verbindet Jellyflex nicht.',
  );
  String get unencryptedWarning => _t(
    'Unencrypted connection: your password and data can be read on the network. Only use this at home.',
    'Unverschlüsselte Verbindung: Passwort und Daten sind im Netz mitlesbar. Nur im eigenen Heimnetz nutzen.',
  );
  String get signIn => _t('Sign in', 'Anmelden');
  String get username => _t('Username', 'Benutzername');
  String get password => _t('Password', 'Passwort');
  String get signInWithQuickConnect => _t('Sign in with Quick Connect', 'Mit Quick Connect anmelden');
  String get removeAccount => _t('Remove account', 'Konto entfernen');

  // --- Bibliothek --------------------------------------------------------------------

  String get sortTitle => _t('Title', 'Titel');
  String get sortAdded => _t('Recently added', 'Zuletzt hinzugefügt');
  String get sortReleased => _t('Release date', 'Erscheinungsdatum');
  String get sortRating => _t('Rating', 'Bewertung');
  String get sortRandom => _t('Random', 'Zufällig');
  String titlesCount(int n) => _t(n == 1 ? '1 title' : '$n titles', '$n Titel');
  String get unwatched => _t('Unwatched', 'Ungesehen');
  String get favorites => _t('Favorites', 'Favoriten');
  String get genre => _t('Genre', 'Genre');
  String get allGenres => _t('All genres', 'Alle Genres');
  String get decade => _t('Decade', 'Jahrzehnt');
  String decadeLabel(int d) => _t('${d >= 2000 ? d : d % 100}s', '${d >= 2000 ? d : d % 100}er');
  String get allYears => _t('All years', 'Alle Jahre');
  String get resetFilters => _t('Reset filters', 'Filter zurücksetzen');
  String libraryCouldNotLoad(Object e) =>
      _t('The library couldn’t be loaded.\n$e', 'Bibliothek konnte nicht geladen werden.\n$e');
  String get noTitlesMatch => _t('No titles match these filters.', 'Keine Titel passen zu diesen Filtern.');

  // --- Startseite & Navigation ---------------------------------------------------------

  String homeCouldNotLoad(Object e) =>
      _t('The home page couldn’t be loaded.\n$e', 'Die Startseite konnte nicht geladen werden.\n$e');
  String get viewDownloads => _t('View downloads', 'Downloads ansehen');
  String get libraries => _t('Libraries', 'Bibliotheken');
  String get movieQuiz => _t('Movie quiz', 'Film-Quiz');
  String get surpriseMe => _t('Surprise me', 'Überrasch mich');
  String get searchCtrlF => _t('Search (Ctrl+F)', 'Suchen (Strg+F)');
  String get profile => _t('Profile', 'Profil');
  String get switchUser => _t('Switch user', 'Benutzer wechseln');
  String get yearlyRecap => _t('Year in review', 'Jahresrückblick');
  String get soundOn => _t('Sound on', 'Ton an');
  String get soundOff => _t('Sound off', 'Ton aus');
  String get watch => _t('Watch', 'Ansehen');
  String get moreInfo => _t('More info', 'Mehr Infos');

  // --- Suche ---------------------------------------------------------------------------

  String get searchHint => _t('Search titles, episodes or actors …', 'Titel, Folgen oder Schauspieler suchen …');
  String get clear => _t('Clear', 'Leeren');
  String searchFailed(Object e) => _t('Search failed: $e', 'Suche fehlgeschlagen: $e');
  String get whatDoYouFeelLike => _t('What are you in the mood for?', 'Wonach ist dir heute?');
  String nothingFoundFor(String term) => _t('Nothing found for “$term”.', 'Nichts gefunden für „$term“.');
  String get movies => _t('Movies', 'Filme');
  String get shows => _t('Shows', 'Serien');
  String get episodes => _t('Episodes', 'Folgen');

  // --- Personenseite -------------------------------------------------------------------

  String personCouldNotLoad(Object e) =>
      _t('Person couldn’t be loaded.\n$e', 'Person konnte nicht geladen werden.\n$e');
  String get noTitlesWithPerson => _t(
    'There are no movies or shows with this person on your server.',
    'Auf deinem Server gibt es keine Filme oder Serien mit dieser Person.',
  );
  String get onYourServer => _t('On your server', 'Auf deinem Server');
  String allCount(int n) => _t('All ($n)', 'Alle ($n)');
  String moviesCount(int n) => _t('Movies ($n)', 'Filme ($n)');
  String showsCount(int n) => _t('Shows ($n)', 'Serien ($n)');
  String get guestAppearances => _t('Appearances in single episodes', 'Auftritte in einzelnen Folgen');
  String bornOn(String date, int? age, String? place) => _t(
    'Born $date${age != null ? ' ($age years)' : ''}${place != null ? ' in $place' : ''}',
    'Geboren am $date${age != null ? ' ($age Jahre)' : ''}${place != null ? ' in $place' : ''}',
  );
  String bornIn(String place) => _t('Born in $place', 'Geboren in $place');
  String diedOn(String date, int? age) =>
      _t('Died $date${age != null ? ' ($age years)' : ''}', 'Gestorben am $date${age != null ? ' ($age Jahre)' : ''}');
  String movieCount(int n) => _t(n == 1 ? '1 movie' : '$n movies', n == 1 ? '1 Film' : '$n Filme');
  String showCount(int n) => _t(n == 1 ? '1 show' : '$n shows', n == 1 ? '1 Serie' : '$n Serien');
  String episodeCount(int n) => _t(n == 1 ? '1 episode' : '$n episodes', n == 1 ? '1 Folge' : '$n Folgen');
  String onYourServerCounts(String counts) => _t('$counts on your server', '$counts auf deinem Server');
  String get showLess => _t('Show less', 'Weniger anzeigen');
  String get showMore => _t('Show more', 'Mehr anzeigen');

  // --- Saisons ----------------------------------------------------------------------

  String get halloween => _t('Spooky season', 'Gruselzeit');
  String get christmas => _t('Christmas time', 'Weihnachtszeit');
  String get newYearsEve => _t('New Year’s Eve', 'Silvester');
  String get valentinesDay => _t('Valentine’s Day', 'Valentinstag');

  // --- Überrasch mich ------------------------------------------------------------------

  String get nothingFoundLoosen =>
      _t('Nothing found – loosen the filters a bit.', 'Nichts gefunden – lockere die Filter etwas.');
  String get letChanceDecide =>
      _t('Let chance decide what’s on tonight.', 'Lass den Zufall entscheiden, was heute läuft.');
  String get spinning => _t('Spinning …', 'Dreht …');
  String get spin => _t('Spin', 'Drehen');
  String get spinAgain => _t('Spin again', 'Nochmal drehen');
  String get anyTime => _t('Any time', 'Egal');
  String get both => _t('Both', 'Beides');
  String get unwatchedOnly => _t('Unwatched only', 'Nur Ungesehenes');
  String get all => _t('All', 'Alle');
  String genreLabel(String g) => _t('Genre: $g', 'Genre: $g');
  String finishedBy(String time) => _t('Finished by: $time', 'Fertig bis: $time');
  String get startSeries => _t('Start series', 'Serie starten');

  // --- Film-Quiz -----------------------------------------------------------------------

  String get quizNeedsTitles => _t(
    'The quiz needs at least 4 movies or shows with a backdrop image.',
    'Für das Quiz braucht es mindestens 4 Filme oder Serien mit Hintergrundbild.',
  );
  String roundOf(int n, int total) => _t('Round $n of $total', 'Runde $n von $total');
  String points(int n) => _t('$n points', '$n Punkte');
  String correctPlus(int n) => _t('Correct! +$n', 'Richtig! +$n');
  String get notQuite => _t('Not quite', 'Leider nicht');
  String get result => _t('Result', 'Ergebnis');
  String get next => _t('Next', 'Weiter');
  String get verdictPro => _t('Movie pro! 🍿', 'Filmprofi! 🍿');
  String get verdictStrong => _t('Strong showing! 🎬', 'Starke Leistung! 🎬');
  String get verdictNotBad => _t('Not bad! 🎞️', 'Nicht schlecht! 🎞️');
  String get verdictMore => _t('Room to grow … 📼', 'Da geht noch was … 📼');
  String get newRecord => _t('New record!', 'Neuer Rekord!');
  String correctOf(int correct, int rounds, int record) =>
      _t('$correct of $rounds correct  ·  Record: $record', '$correct von $rounds richtig  ·  Rekord: $record');
  String get playAgain => _t('Play again', 'Nochmal spielen');

  // --- Jahresrückblick -------------------------------------------------------------------

  String recapFileName(String app, int year) => _t('$app Year in review $year', '$app Rückblick $year');
  String savedToPictures(String name) => _t('Saved to Pictures: $name', 'Gespeichert in Bilder: $name');
  String get show => _t('Show', 'Anzeigen');
  String get imageNotSaved => _t('The image couldn’t be saved.', 'Das Bild konnte nicht gespeichert werden.');
  String get calculatingYear => _t('Adding up your year …', 'Wir rechnen dein Jahr zusammen …');
  String get saveAsImage => _t('Save as image', 'Als Bild speichern');
  String get watchAgain => _t('Watch again', 'Nochmal ansehen');
  String yourYear(int y) => _t('Your $y', 'Dein Jahr $y');
  String get nothingThisYear =>
      _t('You haven’t finished anything this year yet.', 'In diesem Jahr hast du noch nichts zu Ende geschaut.');
  String get letsLookBack => _t('Let’s look back.', 'Lass uns zurückblicken.');
  String get youWatched => _t('You watched', 'Du hast');
  String get hoursSuffix => _t(' hours', ' Stunden');
  String watchedComparison(String comparison) => _t(comparison, 'geschaut. $comparison');
  String get thatWas => _t('That was', 'Das waren');
  String get movieWord => _t('movie', 'Film');
  String get moviesWord => _t('movies', 'Filme');
  String get episodeWord => _t('episode', 'Folge');
  String get episodesWord => _t('episodes', 'Folgen');
  String get showWord => _t('show', 'Serie');
  String get showsWord => _t('shows', 'Serien');
  String longestMovie(String name, String runtime) =>
      _t('Longest movie: $name ($runtime)', 'Der längste Film: $name ($runtime)');
  String get favoriteGenre => _t('Your favorite genre', 'Dein Lieblingsgenre');
  String get showOfTheYear => _t('Your show of the year', 'Deine Serie des Jahres');
  String episodesWatched(int n) =>
      _t(n == 1 ? '1 episode watched' : '$n episodes watched', n == 1 ? '1 Folge geschaut' : '$n Folgen geschaut');
  String get seenMostOften => _t('Seen most often', 'Am häufigsten gesehen');
  String inTitles(int n) => _t(n == 1 ? 'in 1 title' : 'in $n titles', n == 1 ? 'in 1 Titel' : 'in $n Titeln');
  String get biggestMarathon => _t('Your biggest marathon', 'Dein größter Marathon');
  String inOneDay(String duration) => _t('$duration in one day 🍿', '$duration an einem Tag 🍿');
  String favoriteHourText(int hour) =>
      _t('You like to watch around ${timeOfDay(hour)}.', 'Am liebsten schaust du gegen ${timeOfDay(hour)}.');
  String daysInARow(String days) => _t('That’s $days days in a row.', 'Das sind $days Tage am Stück.');
  String asLongAsTitanic(String times) => _t('As long as $times× “Titanic”.', 'So lang wie $times× „Titanic“.');
  String get nightOwl => _t('Night owl 🦉', 'Nachteule 🦉');
  String get earlyBird => _t('Early bird ☀️', 'Frühaufsteher ☀️');
  String get eveningWatcher => _t('After-work watcher 🛋️', 'Feierabend-Gucker 🛋️');
  String get afternoonWatcher => _t('Afternoon watcher ☕', 'Nachmittags-Gucker ☕');
  String recapTitle(String app, int year) => _t('$app · Year in review $year', '$app · Rückblick $year');
  String get hoursWord => _t('Hours', 'Stunden');
  String get moviesTitle => _t('Movies', 'Filme');
  String get episodesTitle => _t('Episodes', 'Folgen');
  String get showsTitle => _t('Shows', 'Serien');
  String get favoriteGenreShort => _t('Favorite genre', 'Lieblingsgenre');
  String get showOfTheYearShort => _t('Show of the year', 'Serie des Jahres');
  String get favoriteTime => _t('Favorite time', 'Lieblingszeit');

  // --- Player ----------------------------------------------------------------------

  String get sleepTimer => _t('Sleep timer', 'Schlaf-Timer');
  String get endOfThisEpisode => _t('At the end of this episode', 'Am Ende dieser Folge');
  String get endOfThisMovie => _t('At the end of the movie', 'Am Ende des Films');
  String inMinutes(int m) => _t('In $m minutes', 'In $m Minuten');
  String get atTheEnd => _t('at the end', 'am Ende');
  String seconds(int sec) => _t('$sec s', '$sec s');
  String get noPlayableFile => _t('No playable file found.', 'Keine abspielbare Datei gefunden.');
  String get noTranscodeFromServer =>
      _t('The server didn’t provide a converted version.', 'Der Server hat keine umgerechnete Fassung geliefert.');
  String fileCouldNotLoad(String message) =>
      _t('The file couldn’t be loaded.\n$message', 'Die Datei konnte nicht geladen werden.\n$message');
  String get playbackNotPossible => _t('Playback not possible', 'Wiedergabe nicht möglich');
  String get bigWindow => _t('Big window (P)', 'Großes Fenster (P)');
  String get backEsc => _t('Back (Esc)', 'Zurück (Esc)');
  String get pauseSpace => _t('Pause (Space)', 'Pause (Leertaste)');
  String get playSpace => _t('Play (Space)', 'Abspielen (Leertaste)');
  String get rewind10 => _t('Back 10 s (←)', '10 s zurück (←)');
  String get forward10 => _t('Forward 10 s (→)', '10 s vor (→)');
  String get audioAndSubtitles => _t('Audio & subtitles', 'Audio & Untertitel');
  String get playbackOptions =>
      _t('Playback: speed, quality, sync', 'Wiedergabe: Geschwindigkeit, Qualität, Synchronisation');
  String get miniPlayer => _t('Mini player (P)', 'Mini-Player (P)');
  String get exitFullscreen => _t('Exit fullscreen (F)', 'Vollbild beenden (F)');
  String get fullscreen => _t('Fullscreen (F)', 'Vollbild (F)');
  String get mute => _t('Mute (M)', 'Stumm (M)');
  String get audio => _t('Audio', 'Audio');
  String get subtitles => _t('Subtitles', 'Untertitel');
  String get noAudioTracks => _t('No audio tracks found', 'Keine Tonspuren gefunden');
  String get noSubtitles => _t('No subtitles available', 'Keine Untertitel vorhanden');
  String get file => _t('File', 'Datei');
  String get goodNight => _t('Good night', 'Gute Nacht');
  String get sleepTimerPaused =>
      _t('The sleep timer paused playback.', 'Der Schlaf-Timer hat die Wiedergabe angehalten.');
  String get keepWatching => _t('Keep watching', 'Weiterschauen');
  String get closePlayer => _t('Close player', 'Player schließen');
  String get skipIntro => _t('Skip intro', 'Intro überspringen');
  String get skipRecap => _t('Skip recap', 'Rückblick überspringen');
  String get skipPreview => _t('Skip preview', 'Vorschau überspringen');
  String get skipCommercial => _t('Skip commercial', 'Werbung überspringen');
  String get skip => _t('Skip', 'Überspringen');
  String get nextEpisodeCaps => _t('NEXT EPISODE', 'NÄCHSTE FOLGE');
  String get watchCredits => _t('Watch credits', 'Abspann ansehen');
  String get watchNow => _t('Watch now', 'Jetzt ansehen');
  String get speed => _t('Speed', 'Geschwindigkeit');
  String get sync => _t('Sync', 'Synchronisation');
  String get sound => _t('Audio', 'Ton');
  String get withoutConversion => _t('no conversion', 'ohne Umrechnung');
  String get reset => _t('Reset', 'Zurücksetzen');

  // --- Server & Downloads (Fehlermeldungen) -------------------------------------

  String get notAJellyfinServer => _t('Not a Jellyfin server', 'Kein Jellyfin-Server');
  String get serverNotReachable => _t('Server not reachable', 'Server nicht erreichbar');
  String get otherAccountSignedIn => _t('Another account is signed in', 'Anderes Konto angemeldet');
  String get noFileFound => _t('No file found', 'Keine Datei gefunden');
  String connectionInterrupted(String received, String total) =>
      _t('Connection interrupted ($received of $total)', 'Verbindung unterbrochen ($received von $total)');
  String get unexpectedServerAddress => _t(
    'The server sent an address that doesn’t belong to it – blocked.',
    'Der Server lieferte eine fremde Adresse – blockiert.',
  );
  String get noConnectionToServer => _t('No connection to the server', 'Keine Verbindung zum Server');
  String get serverOffline => _t('Server not reachable', 'Server nicht erreichbar');
  String get offlineHint => _t('Your downloads still work.', 'Deine Downloads funktionieren weiterhin.');
  String get backOnline => _t('Connected to the server again', 'Wieder mit dem Server verbunden');
  String serverError(int? code) => _t('Server error $code', 'Server-Fehler $code');
  String get encryptionFailed => _t('Encryption failed', 'Verschlüsselung fehlgeschlagen');
}
