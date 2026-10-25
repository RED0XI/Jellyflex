part of 'strings.dart';

// Français. Was hier fehlt, erscheint auf Englisch.

final class _Fr extends S {
  const _Fr() : super._(false);

  // --- Allgemein ---
  @override
  String get retry => 'Réessayer';
  @override
  String get back => 'Retour';
  @override
  String get close => 'Fermer';
  @override
  String get cancel => 'Annuler';
  @override
  String get delete => 'Supprimer';
  @override
  String get details => 'Détails';
  @override
  String get play => 'Lecture';
  @override
  String get resume => 'Reprendre';
  @override
  String get pause => 'Pause';
  @override
  String get off => 'Désactivé';
  @override
  String get storage => 'Stockage';
  @override
  String get about => 'À propos de Jellyflex';
  @override
  String get appVersionLabel => 'Version de l’app';
  @override
  String get updateCheck => 'Rechercher des mises à jour';
  @override
  String get updateCheckHint =>
      'Au démarrage, demande seulement à GitHub le numéro de la dernière version – rien sur vous ni sur votre serveur. Désactivé par défaut.';
  @override
  String get checkNow => 'Vérifier';
  @override
  String updateAvailable(String v) => 'La version $v est disponible';
  @override
  String get upToDate => 'Vous avez la dernière version';
  @override
  String get updateCheckFailed => 'Impossible de vérifier les mises à jour';
  @override
  String get errorReport => 'Rapport d’erreur';
  @override
  String get errorReportHint =>
      'Version, réglages et derniers messages dans un fichier texte – à transmettre si quelque chose ne va pas.';
  @override
  String get errorReportPrivacy =>
      'Rien n’est envoyé. Mots de passe, jetons, adresse du serveur, noms et dossier utilisateur sont retirés.';
  @override
  String get create => 'Créer';
  @override
  String get copy => 'Copier';
  @override
  String get copied => 'Copié';
  @override
  String get saveAs => 'Enregistrer sous …';
  @override
  String get imageCache => 'Cache d’images';
  @override
  String imageCacheHint(String used) =>
      'Affiches et arrière-plans restent sur le disque et s’affichent tout de suite. Utilisé : $used';
  @override
  String get clearCache => 'Vider';
  @override
  String get cacheCleared => 'Cache d’images vidé';
  @override
  String get unknown => 'Inconnu';
  @override
  String get library => 'Bibliothèque';
  @override
  String get serverUnreachable => 'Le serveur est injoignable pour le moment.';
  @override
  String get didNotWork => 'Désolé, ça n’a pas marché.';
  @override
  String get minimize => 'Réduire';
  @override
  String get maximize => 'Agrandir';
  @override
  String get restore => 'Restaurer';

  // --- Zeit & Zahlen ---
  @override
  String hours(int h) => '$h h';
  @override
  String minutes(int m) => '$m min';
  @override
  String remaining(String duration) => 'encore $duration';
  @override
  String endsAt(String time) => 'Fin à $time';
  @override
  String timeOfDay(int hour) => '$hour h';
  @override
  String get midnight => 'Minuit';
  @override
  List<String> get months => const [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  @override
  List<String> get weekdays => const ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  @override
  String date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
  @override
  String weekdayDate(DateTime d) => '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  @override
  String? languageName(String code) => const {
    'de': 'Allemand',
    'en': 'Anglais',
    'ja': 'Japonais',
    'fr': 'Français',
    'es': 'Espagnol',
    'it': 'Italien',
    'tr': 'Turc',
    'ko': 'Coréen',
    'ru': 'Russe',
    'pt': 'Portugais',
    'nl': 'Néerlandais',
    'pl': 'Polonais',
    'zh': 'Chinois',
  }[code];
  @override
  String decimal(double value, int digits) => value.toStringAsFixed(digits).replaceAll('.', ',');
  @override
  String channels(int n) => '$n canaux';
  @override
  String get original => 'Original';
  @override
  String get version => 'Version';

  // --- Startseite ---
  @override
  String get continueWatching => 'Reprendre';
  @override
  String get nextUp => 'À suivre';
  @override
  String newIn(String library) => 'Nouveautés : $library';
  @override
  String get yourFavorites => 'Vos favoris';
  @override
  String get collections => 'Collections';
  @override
  String becauseYouWatched(String name) => 'Parce que vous avez regardé « $name »';
  @override
  String becauseYouLike(String name) => 'Parce que vous aimez « $name »';
  @override
  String moreFrom(String name) => 'Plus de $name';
  @override
  String withPerson(String name) => 'Avec $name';
  @override
  String get recommendations => 'Recommandations';

  // --- Einstellungen ---
  @override
  String get settings => 'Réglages';
  @override
  String get language => 'Langue';
  @override
  String get appLanguage => 'Langue de l’app';
  @override
  String get appLanguageHint => 'Menus, boutons et textes.';
  @override
  String get playback => 'Lecture';
  @override
  String get preferredAudio => 'Piste audio préférée';
  @override
  String get preferredAudioHint => 'Choisie au démarrage si disponible.';
  @override
  String get preferredSubtitles => 'Sous-titres préférés';
  @override
  String get preferredSubtitlesHint => 'Les sous-titres complets passent avant les sous-titres forcés.';
  @override
  String get asInJellyfin => 'Comme dans Jellyfin';
  @override
  String get quality => 'Qualité';
  @override
  String get qualityHint =>
      'Original lit le fichier directement. Les niveaux inférieurs le font convertir par le serveur – utile pour les connexions lentes.';
  @override
  String get ambilight => 'Halo Ambilight';
  @override
  String get ambilightHint => 'Les couleurs de l’image brillent doucement dans les bandes noires autour de la vidéo.';
  @override
  String get onlyInWindow => 'Seulement en fenêtre';
  @override
  String get always => 'Toujours';
  @override
  String get alwaysInclFullscreen => 'Toujours (aussi en plein écran)';
  @override
  String get autoSkipIntro => 'Passer automatiquement intro et résumé';
  @override
  String get autoSkipIntroHint => 'Désactivé : seul le bouton « Passer l’intro » apparaît.';
  @override
  String get autoplayNext => 'Lire l’épisode suivant automatiquement';
  @override
  String get autoplayNextHint => 'Avec un compte à rebours à la fin de l’épisode.';
  @override
  String get subtitleAppearance => 'Apparence des sous-titres';
  @override
  String get size => 'Taille';
  @override
  String get background => 'Fond';
  @override
  String get subtitleBackgroundHint => 'Cadre semi-transparent derrière le texte.';
  @override
  String get subtitlePreview => 'Voici à quoi ressemblent vos sous-titres.';
  @override
  String get home => 'Accueil';
  @override
  String get search => 'Rechercher';
  @override
  String get more => 'Plus';
  @override
  String get goodMorning => 'Bonjour';
  @override
  String get goodAfternoon => 'Bon après-midi';
  @override
  String get goodEvening => 'Bonsoir';
  @override
  String get coverStory => 'À la une';
  @override
  String get layout => 'Disposition';
  @override
  String get layoutHint =>
      'Change toute la structure de l’app – navigation, bannière, cartes, police. Les couleurs restent celles choisies plus bas.';
  @override
  String layoutName(String id, String en, String de) => switch (id) {
    'cinema' => 'Cinéma',
    'couch' => 'Canapé',
    'library' => 'Bibliothèque',
    'magazine' => 'Magazine',
    'minimal' => 'Minimal',
    'retro' => 'Rétro VHS',
    _ => en,
  };
  @override
  String layoutDescription(String id, String en, String de) => switch (id) {
    'cinema' => 'Grande bannière, barre flottante, affiches qui s’agrandissent.',
    'couch' => 'Grandes tuiles et onglets pour la TV et la manette.',
    'library' => 'Barre latérale avec toutes les bibliothèques, rangées compactes.',
    'magazine' => 'Éditorial : titres à empattements, article de une, angles nets.',
    'minimal' => 'Pas de bannière, rien de superflu – vos titres et de l’espace.',
    'retro' => 'Lueur de tube cathodique, lignes de balayage et machine à écrire.',
    _ => en,
  };
  @override
  String get profilePin => 'Code PIN du profil';
  @override
  String get profilePinHint => 'Facultatif : demande un code PIN avant d’ouvrir ce profil sur cet ordinateur.';
  @override
  String get profilePinOnHint => 'Activé – ce profil ne s’ouvre qu’avec son code PIN.';
  @override
  String get pinSet => 'Définir un PIN';
  @override
  String get pinChange => 'Changer le PIN';
  @override
  String get pinRemove => 'Supprimer';
  @override
  String get pinSaved => 'PIN enregistré';
  @override
  String get pinRemoved => 'PIN supprimé';
  @override
  String get pinCurrent => 'PIN actuel';
  @override
  String get pinChoose => 'Choisissez un PIN';
  @override
  String get pinChooseHint => '4 à 6 chiffres';
  @override
  String get pinRepeat => 'Répétez le PIN';
  @override
  String get pinFormat => 'Saisissez 4 à 6 chiffres';
  @override
  String get pinWrong => 'PIN incorrect';
  @override
  String pinLocked(int s) => 'Trop d’essais – patientez $s s';
  @override
  String pinFor(String name) => 'PIN de $name';
  @override
  String pinDigits(int n) => '$n chiffres saisis';
  @override
  String get pinDelete => 'Effacer un chiffre';
  @override
  String get pinConfirm => 'Confirmer';
  @override
  String get pinProtected => 'Protégé par PIN';
  @override
  String downloadFinished(String name) => '« $name » est téléchargé';
  @override
  String downloadsFinished(int n) => '$n téléchargements terminés';
  @override
  String get themeMusic => 'Musique du titre';
  @override
  String get themeMusicHint => 'Joue doucement la musique du titre sur sa page (si votre serveur en a une).';
  @override
  String get select => 'Sélectionner';
  @override
  String get selected => 'sélectionné';
  @override
  String get notSelected => 'non sélectionné';
  @override
  String selectedCount(int n) => '$n sélectionné(s)';
  @override
  String get selectAll => 'Tout sélectionner';
  @override
  String get endSelection => 'Terminer la sélection (Échap)';
  @override
  String get favorite => 'Favori';
  @override
  String get selectionMarkedWatched => 'Marqué comme vu';
  @override
  String get selectionMarkedUnwatched => 'Marqué comme non vu';
  @override
  String get selectionAddedToFavorites => 'Ajouté aux favoris';
  @override
  String get selectionDownloading => 'Téléchargements lancés';
  @override
  String get recentSearches => 'Recherches récentes';
  @override
  String get clearHistory => 'Effacer l’historique';
  @override
  String get filterAll => 'Tout';
  @override
  String get people => 'Personnes';
  @override
  String get onlyUnwatched => 'Non vus seulement';
  @override
  String removeSearch(String term) => 'Retirer « $term »';
  @override
  String get recapOnlyYou => 'Seul votre profil compte';
  @override
  String recapMarkedNote(int n) => '$n titre(s) seulement marqué(s) comme vu(s) (non compté(s))';
  @override
  String get watched => 'Vu';
  @override
  String get chapters => 'Chapitres';
  @override
  String get chaptersKey => 'Chapitres (C)';
  @override
  String chapterN(int n) => 'Chapitre $n';
  @override
  String get screenshotSaved => 'Capture enregistrée dans Images';
  @override
  String get screenshotFailed => 'Impossible de faire une capture';
  @override
  String get statsTitle => 'Infos de lecture (I)';
  @override
  String get statsPlayback => 'Lecture';
  @override
  String get statsDecoder => 'Décodage';
  @override
  String get statsSoftware => 'Logiciel (CPU)';
  @override
  String get statsHardware => 'Matériel';
  @override
  String get statsBuffer => 'Tampon';
  @override
  String get statsDropped => 'Images perdues';
  @override
  String get statsDirectPlay => 'Directe (fichier original)';
  @override
  String get statsTranscoding => 'Converti par le serveur';
  @override
  String get statsLocalFile => 'Fichier téléchargé';
  @override
  String episodesWatchedOf(int n, int total) => '$n sur $total vus';
  @override
  String downloadedOf(int n, int total) => '$n sur $total téléchargés';
  @override
  String get markSeasonWatched => 'Marquer la saison comme vue';
  @override
  String get markSeasonUnwatched => 'Marquer la saison comme non vue';
  @override
  String markSeasonWatchedQuestion(String season) => 'Marquer « $season » comme vue ?';
  @override
  String markSeasonWatchedDetail(int n) =>
      'Les $n épisodes seront marqués comme vus. Votre bilan de l’année ne les comptera pas comme temps regardé.';
  @override
  String seasonMarkedWatched(String season) => '$season marquée comme vue';
  @override
  String seasonMarkedUnwatched(String season) => '$season marquée comme non vue';
  @override
  String get bannerTrailers => 'Bandes-annonces dans la bannière';
  @override
  String get bannerTrailersHint => 'Après quelques secondes, lit la bande-annonce sans le son (si disponible).';
  @override
  String get screensaver => 'Économiseur d’écran';
  @override
  String get screensaverHint =>
      'Après un moment sans action, montre des images de vos films et séries avec une horloge. Jamais pendant la lecture.';
  @override
  String get showNow => 'Afficher';
  @override
  String afterMinutes(int m) => 'Après $m min';
  @override
  String get seasonalThemes => 'Touches de saison';
  @override
  String get seasonalThemesHint =>
      'Pour Halloween, Noël, le Nouvel An et la Saint-Valentin : une rangée assortie et de petits effets sur l’accueil.';
  @override
  String get episodeImages => 'Images d’épisode dans « Reprendre »';
  @override
  String get episodeImagesHint => 'Désactivé : image de la série au lieu de celle de l’épisode.';
  @override
  String get personalize => 'Personnaliser';
  @override
  String get appName => 'Nom de l’app';
  @override
  String get appNameHint => 'Affiché dans la barre de titre, le titre de la fenêtre et à la connexion.';
  @override
  String get logo => 'Logo';
  @override
  String get logoHint => 'Une image (PNG, JPG …) – affichée devant le nom et comme icône de la barre des tâches.';
  @override
  String get sounds => 'Sons';
  @override
  String get soundsHint => 'Tic-tac et jingle dans « Surprends-moi ».';
  @override
  String get theme => 'Thème';
  @override
  String get themeHint => 'Couleurs de toute l’app – change immédiatement.';
  @override
  String themeName(String id) => switch (id) {
    'midnight' => 'Minuit',
    'oled' => 'Noir OLED',
    'cinema' => 'Rouge cinéma',
    'frost' => 'Givre nordique',
    'sunset' => 'Coucher de soleil',
    'synthwave' => 'Synthwave',
    'emerald' => 'Émeraude',
    'noir' => 'Noir et or',
    _ => id,
  };
  @override
  String get images => 'Images';
  @override
  String get loading => 'Chargement …';
  @override
  String get chooseImage => 'Choisir une image …';
  @override
  String get removeLogo => 'Retirer le logo';
  @override
  String get imageUnreadable => 'Cette image n’a pas pu être lue.';
  @override
  String get resetToJellyflex => 'Revenir à Jellyflex';
  @override
  String get account => 'Compte';
  @override
  String get signOut => 'Se déconnecter';
  @override
  String basedOn(String name, String version) => '$name · basé sur Jellyflex $version';

  // --- Detailseite ---
  @override
  String contentCouldNotLoad(Object e) => 'Le contenu n’a pas pu être chargé.\n$e';
  @override
  String get moreEpisodes => 'Autres épisodes';
  @override
  String seasonN(int n) => 'Saison $n';
  @override
  String episodeN(int n) => 'Épisode $n';
  @override
  String seasonsCount(int n) => n == 1 ? '1 saison' : '$n saisons';
  @override
  String get fromStart => 'Depuis le début';
  @override
  String versionLabel(String v) => 'Version : $v';
  @override
  String audioLabel(String v) => 'Audio : $v';
  @override
  String subtitlesLabel(String v) => 'Sous-titres : $v';
  @override
  String get imdbRating => 'Note IMDb (public)';
  @override
  String get tmdbRating => 'Note TMDB (public)';
  @override
  String get audienceRating => 'Note du public';
  @override
  String get rottenTomatoesRating => 'Rotten Tomatoes (critiques)';
  @override
  String get markUnplayed => 'Marquer comme non vu';
  @override
  String get markPlayed => 'Marquer comme vu';
  @override
  String get removeFavorite => 'Retirer des favoris';
  @override
  String get addFavorite => 'Ajouter aux favoris';
  @override
  String get mediaInfoTooltip => 'Infos média (résolution, audio, sous-titres …)';
  @override
  String get downloadOffline => 'Télécharger (regarder hors ligne)';
  @override
  String get downloadedClickToDelete => 'Téléchargé – cliquer pour supprimer';
  @override
  String get pauseDownload => 'Mettre en pause';
  @override
  String get resumeDownload => 'Reprendre le téléchargement';
  @override
  String get seasonAlreadyDownloaded => 'Tous les épisodes de cette saison sont déjà téléchargés';
  @override
  String episodesDownloading(int n) =>
      n == 1 ? '1 épisode en cours de téléchargement' : '$n épisodes en cours de téléchargement';
  @override
  String get downloadSeason => 'Télécharger la saison';
  @override
  String get thisEpisode => 'Cet épisode';
  @override
  String get cast => 'Distribution';
  @override
  String get youMightLike => 'Vous aimerez peut-être';
  @override
  String get inThisCollection => 'Dans cette collection';
  @override
  String get mediaInfo => 'Infos média';
  @override
  String get format => 'Format';
  @override
  String get totalBitrate => 'Débit total';
  @override
  String get runtime => 'Durée';
  @override
  String get fileName => 'Nom du fichier';
  @override
  String get video => 'Vidéo';
  @override
  String get resolution => 'Résolution';
  @override
  String get codec => 'Codec';
  @override
  String get dynamicRange => 'Plage dynamique';
  @override
  String get bitDepth => 'Profondeur de couleur';
  @override
  String get frameRate => 'Images par seconde';
  @override
  String get bitrate => 'Débit';
  @override
  String audioCount(int n) => 'Audio ($n)';
  @override
  String subtitlesCount(int n) => 'Sous-titres ($n)';
  @override
  String get defaultTrack => 'Par défaut';
  @override
  String get forced => 'Forcés';

  // --- Kontextmenü ---
  @override
  String get playFromStart => 'Lire depuis le début';
  @override
  String get goToSeries => 'Aller à la série';
  @override
  String get alreadyWatched => 'Déjà vu';
  @override
  String get forget => 'Retirer de « Reprendre »';
  @override
  String get download => 'Télécharger';
  @override
  String get deleteDownload => 'Supprimer le téléchargement';
  @override
  String markedWatched(String name) => '« $name » marqué comme vu';
  @override
  String markedUnwatched(String name) => '« $name » marqué comme non vu';
  @override
  String get addedToFavorites => 'Ajouté aux favoris';
  @override
  String get removedFromFavorites => 'Retiré des favoris';
  @override
  String downloadStarted(String name) => 'Téléchargement lancé : $name';
  @override
  String get downloadDeleted => 'Téléchargement supprimé';
  @override
  String get removedFromContinue => 'Retiré de « Reprendre »';

  // --- Downloads ---
  @override
  String get downloads => 'Téléchargements';
  @override
  String get savedForOffline => 'Enregistré sur ce PC pour regarder hors ligne';
  @override
  String downloadsSummary(int count, String size) => '$count titre(s) · $size utilisés';
  @override
  String get openFolder => 'Ouvrir le dossier';
  @override
  String get noDownloadsYet => 'Aucun téléchargement pour l’instant.';
  @override
  String get noDownloadsHint => 'Cliquez sur « Télécharger » sur une page de détails ou via le clic droit.';
  @override
  String get downloading => 'En cours';
  @override
  String get readyOffline => 'Prêt hors ligne';
  @override
  String get deleteDownloadQuestion => 'Supprimer le téléchargement ?';
  @override
  String deleteDownloadText(String name) => '« $name » sera supprimé de ce PC. Tout reste sur le serveur.';
  @override
  String get waiting => 'En attente …';
  @override
  String receivedOf(String received, String total) => '$received sur $total';
  @override
  String get starting => 'Démarrage …';
  @override
  String paused(String? reason) => 'En pause${reason != null ? ' – $reason' : ''}';
  @override
  String failed(String? reason) => 'Échec : ${reason ?? 'inconnu'}';
  @override
  String get done => 'Terminé';
  @override
  String get cancelAndDelete => 'Annuler et supprimer';

  // --- Anmeldung ---
  @override
  String get noServerAtAddress => 'Aucun serveur Jellyfin trouvé à cette adresse.';
  @override
  String get wrongCredentials => 'Nom d’utilisateur ou mot de passe incorrect.';
  @override
  String signInFailedCode(String code) => 'Échec de la connexion ($code).';
  @override
  String signInFailed(Object e) => 'Échec de la connexion : $e';
  @override
  String get quickConnectExpired => 'Quick Connect a expiré. Réessayez.';
  @override
  String get quickConnectFailed => 'Quick Connect n’a pas pu démarrer.';
  @override
  String get tagline => 'Votre cinéma. Sur votre ordinateur.';
  @override
  String get whoIsWatching => 'Qui regarde ?';
  @override
  String get addAccount => 'Ajouter un compte';
  @override
  String get toProfileSelection => 'Retour aux profils';
  @override
  String get connectServer => 'Se connecter au serveur';
  @override
  String get enterServerAddress => 'Saisissez l’adresse de votre serveur Jellyfin.';
  @override
  String get serverAddress => 'Adresse du serveur';
  @override
  String get connect => 'Connexion';
  @override
  String get quickConnectHint =>
      'Ouvrez Jellyfin sur un appareil connecté → Profil → Quick Connect et saisissez ce code :';
  @override
  String get otherServer => 'Autre serveur';
  @override
  String get certificateInvalid =>
      'Le certificat de sécurité du serveur n’est pas valide. Pour votre sécurité, Jellyflex ne se connecte pas.';
  @override
  String get unencryptedWarning =>
      'Connexion non chiffrée : mot de passe et données sont lisibles sur le réseau. À utiliser seulement à la maison.';
  @override
  String get signIn => 'Se connecter';
  @override
  String get username => 'Nom d’utilisateur';
  @override
  String get password => 'Mot de passe';
  @override
  String get signInWithQuickConnect => 'Se connecter avec Quick Connect';
  @override
  String get removeAccount => 'Retirer le compte';

  // --- Bibliothek ---
  @override
  String get sortTitle => 'Titre';
  @override
  String get sortAdded => 'Ajouts récents';
  @override
  String get sortReleased => 'Date de sortie';
  @override
  String get sortRating => 'Note';
  @override
  String get sortRandom => 'Aléatoire';
  @override
  String get unwatched => 'Non vus';
  @override
  String get favorites => 'Favoris';
  @override
  String get genre => 'Genre';
  @override
  String get allGenres => 'Tous les genres';
  @override
  String get decade => 'Décennie';
  @override
  String decadeLabel(int d) => 'Années ${d >= 2000 ? d : d % 100}';
  @override
  String get allYears => 'Toutes les années';
  @override
  String get resetFilters => 'Réinitialiser les filtres';
  @override
  String titlesCount(int n) => n == 1 ? '1 titre' : '$n titres';
  @override
  String libraryCouldNotLoad(Object e) => 'La bibliothèque n’a pas pu être chargée.\n$e';
  @override
  String get noTitlesMatch => 'Aucun titre ne correspond à ces filtres.';
  @override
  String homeCouldNotLoad(Object e) => 'La page d’accueil n’a pas pu être chargée.\n$e';
  @override
  String get viewDownloads => 'Voir les téléchargements';
  @override
  String get libraries => 'Bibliothèques';
  @override
  String get surpriseMe => 'Surprends-moi';
  @override
  String get searchCtrlF => _isMac ? 'Rechercher (⌘F)' : 'Rechercher (Ctrl+F)';
  @override
  String get profile => 'Profil';
  @override
  String get switchUser => 'Changer d’utilisateur';
  @override
  String get yearlyRecap => 'Bilan de l’année';
  @override
  String get soundOn => 'Son activé';
  @override
  String get soundOff => 'Son coupé';
  @override
  String get watch => 'Regarder';
  @override
  String get moreInfo => 'Plus d’infos';

  // --- Suche ---
  @override
  String get searchHint => 'Rechercher titres, épisodes ou acteurs …';
  @override
  String get clear => 'Effacer';
  @override
  String searchFailed(Object e) => 'Échec de la recherche : $e';
  @override
  String get whatDoYouFeelLike => 'Qu’avez-vous envie de voir ?';
  @override
  String nothingFoundFor(String term) => 'Rien trouvé pour « $term ».';
  @override
  String get movies => 'Films';
  @override
  String get shows => 'Séries';
  @override
  String get episodes => 'Épisodes';

  // --- Personen ---
  @override
  String personCouldNotLoad(Object e) => 'La personne n’a pas pu être chargée.\n$e';
  @override
  String get noTitlesWithPerson => 'Aucun film ni série avec cette personne sur votre serveur.';
  @override
  String get onYourServer => 'Sur votre serveur';
  @override
  String allCount(int n) => 'Tout ($n)';
  @override
  String moviesCount(int n) => 'Films ($n)';
  @override
  String showsCount(int n) => 'Séries ($n)';
  @override
  String get guestAppearances => 'Apparitions dans des épisodes';
  @override
  String bornOn(String date, int? age, String? place) =>
      'Né(e) le $date${age != null ? ' ($age ans)' : ''}${place != null ? ' à $place' : ''}';
  @override
  String bornIn(String place) => 'Né(e) à $place';
  @override
  String diedOn(String date, int? age) => 'Décédé(e) le $date${age != null ? ' ($age ans)' : ''}';
  @override
  String movieCount(int n) => n == 1 ? '1 film' : '$n films';
  @override
  String showCount(int n) => n == 1 ? '1 série' : '$n séries';
  @override
  String episodeCount(int n) => n == 1 ? '1 épisode' : '$n épisodes';
  @override
  String onYourServerCounts(String counts) => '$counts sur votre serveur';
  @override
  String get showLess => 'Moins';
  @override
  String get showMore => 'Plus';

  // --- Saisonales ---
  @override
  String get halloween => 'Saison frissons';
  @override
  String get christmas => 'Temps de Noël';
  @override
  String get newYearsEve => 'Nouvel An';
  @override
  String get valentinesDay => 'Saint-Valentin';

  // --- Roulette ---
  @override
  String get nothingFoundLoosen => 'Rien trouvé – assouplissez un peu les filtres.';
  @override
  String get letChanceDecide => 'Laissez le hasard choisir le programme de ce soir.';
  @override
  String get spinning => 'Ça tourne …';
  @override
  String get spin => 'Lancer';
  @override
  String get spinAgain => 'Relancer';
  @override
  String get anyTime => 'Peu importe la durée';
  @override
  String get both => 'Les deux';
  @override
  String get unwatchedOnly => 'Non vus seulement';
  @override
  String get all => 'Tout';
  @override
  String genreLabel(String g) => 'Genre : $g';
  @override
  String finishedBy(String time) => 'Terminé vers : $time';
  @override
  String get startSeries => 'Commencer la série';

  @override
  String get next => 'Suivant';

  // --- Jahresrückblick ---
  @override
  String recapFileName(String app, int year) => '$app Bilan $year';
  @override
  String savedToPictures(String name) => 'Enregistré dans Images : $name';
  @override
  String get show => 'Afficher';
  @override
  String get imageNotSaved => 'L’image n’a pas pu être enregistrée.';
  @override
  String get calculatingYear => 'Calcul de votre année …';
  @override
  String get saveAsImage => 'Enregistrer en image';
  @override
  String get watchAgain => 'Revoir';
  @override
  String yourYear(int y) => 'Votre $y';
  @override
  String get nothingThisYear => 'Vous n’avez encore rien terminé cette année.';
  @override
  String get letsLookBack => 'Retour sur l’année.';
  @override
  String get youWatched => 'Vous avez regardé';
  @override
  String get hoursSuffix => ' heures';
  @override
  String get thatWas => 'Soit';
  @override
  String get movieWord => 'film';
  @override
  String get moviesWord => 'films';
  @override
  String get episodeWord => 'épisode';
  @override
  String get episodesWord => 'épisodes';
  @override
  String get showWord => 'série';
  @override
  String get showsWord => 'séries';
  @override
  String longestMovie(String name, String runtime) => 'Film le plus long : $name ($runtime)';
  @override
  String get favoriteGenre => 'Votre genre préféré';
  @override
  String get showOfTheYear => 'Votre série de l’année';
  @override
  String episodesWatched(int n) => n == 1 ? '1 épisode regardé' : '$n épisodes regardés';
  @override
  String get seenMostOften => 'Vu(e) le plus souvent';
  @override
  String inTitles(int n) => n == 1 ? 'dans 1 titre' : 'dans $n titres';
  @override
  String get biggestMarathon => 'Votre plus gros marathon';
  @override
  String inOneDay(String duration) => '$duration en une journée 🍿';
  @override
  String favoriteHourText(int hour) => 'Vous regardez volontiers vers ${timeOfDay(hour)}.';
  @override
  String daysInARow(String days) => 'Soit $days jours d’affilée.';
  @override
  String asLongAsTitanic(String times) => 'Aussi long que $times× « Titanic ».';
  @override
  String get nightOwl => 'Oiseau de nuit 🦉';
  @override
  String get earlyBird => 'Lève-tôt ☀️';
  @override
  String get eveningWatcher => 'Spectateur du soir 🛋️';
  @override
  String get afternoonWatcher => 'Spectateur de l’après-midi ☕';
  @override
  String recapTitle(String app, int year) => '$app · Bilan $year';
  @override
  String get hoursWord => 'Heures';
  @override
  String get moviesTitle => 'Films';
  @override
  String get episodesTitle => 'Épisodes';
  @override
  String get showsTitle => 'Séries';
  @override
  String get favoriteGenreShort => 'Genre préféré';
  @override
  String get showOfTheYearShort => 'Série de l’année';
  @override
  String get favoriteTime => 'Heure préférée';

  // --- Player ---
  @override
  String get sleepTimer => 'Minuterie de mise en veille';
  @override
  String get endOfThisEpisode => 'À la fin de cet épisode';
  @override
  String get endOfThisMovie => 'À la fin du film';
  @override
  String inMinutes(int m) => 'Dans $m minutes';
  @override
  String get atTheEnd => 'à la fin';
  @override
  String seconds(int sec) => '$sec s';
  @override
  String get noPlayableFile => 'Aucun fichier lisible trouvé.';
  @override
  String get noTranscodeFromServer => 'Le serveur n’a pas fourni de version convertie.';
  @override
  String fileCouldNotLoad(String message) => 'Le fichier n’a pas pu être chargé.\n$message';
  @override
  String get playbackNotPossible => 'Lecture impossible';
  @override
  String get bigWindow => 'Grande fenêtre (P)';
  @override
  String get backEsc => 'Retour (Échap)';
  @override
  String get pauseSpace => 'Pause (Espace)';
  @override
  String get playSpace => 'Lecture (Espace)';
  @override
  String get rewind10 => 'Reculer de 10 s (←)';
  @override
  String get forward10 => 'Avancer de 10 s (→)';
  @override
  String get audioAndSubtitles => 'Audio et sous-titres';
  @override
  String get playbackOptions => 'Lecture : vitesse, qualité, synchro';
  @override
  String get miniPlayer => 'Mini lecteur (P)';
  @override
  String get exitFullscreen => 'Quitter le plein écran (F)';
  @override
  String get fullscreen => 'Plein écran (F)';
  @override
  String get mute => 'Couper le son (M)';
  @override
  String get audio => 'Audio';
  @override
  String get subtitles => 'Sous-titres';
  @override
  String get noAudioTracks => 'Aucune piste audio trouvée';
  @override
  String get noSubtitles => 'Aucun sous-titre disponible';
  @override
  String get file => 'Fichier';
  @override
  String get goodNight => 'Bonne nuit';
  @override
  String get sleepTimerPaused => 'La minuterie a mis la lecture en pause.';
  @override
  String get keepWatching => 'Continuer';
  @override
  String get closePlayer => 'Fermer le lecteur';
  @override
  String get skipIntro => 'Passer l’intro';
  @override
  String get skipRecap => 'Passer le résumé';
  @override
  String get skipPreview => 'Passer l’aperçu';
  @override
  String get skipCommercial => 'Passer la pub';
  @override
  String get skip => 'Passer';
  @override
  String get nextEpisodeCaps => 'ÉPISODE SUIVANT';
  @override
  String get watchCredits => 'Voir le générique';
  @override
  String get watchNow => 'Regarder';
  @override
  String get speed => 'Vitesse';
  @override
  String get sync => 'Synchro';
  @override
  String get sound => 'Son';
  @override
  String get withoutConversion => 'sans conversion';
  @override
  String get reset => 'Réinitialiser';

  // --- Fehler & Verbindung ---
  @override
  String get notAJellyfinServer => 'Pas un serveur Jellyfin';
  @override
  String get serverNotReachable => 'Serveur injoignable';
  @override
  String get otherAccountSignedIn => 'Un autre compte est connecté';
  @override
  String get noFileFound => 'Aucun fichier trouvé';
  @override
  String connectionInterrupted(String received, String total) => 'Connexion interrompue ($received sur $total)';
  @override
  String get unexpectedServerAddress => 'Le serveur a envoyé une adresse qui ne lui appartient pas – bloquée.';
  @override
  String get noConnectionToServer => 'Pas de connexion au serveur';
  @override
  String get serverOffline => 'Serveur injoignable';
  @override
  String get offlineHint => 'Vos téléchargements fonctionnent toujours.';
  @override
  String get backOnline => 'De nouveau connecté au serveur';
  @override
  String serverError(int? code) => 'Erreur du serveur $code';
  @override
  String get encryptionFailed => 'Échec du chiffrement';

  // --- Listen, Startseite, Tastenkürzel ---
  @override
  String get watchlist => 'Ma liste';
  @override
  String get myLists => 'Mes listes';
  @override
  String get addToWatchlist => 'Ajouter à ma liste';
  @override
  String get removeFromWatchlist => 'Retirer de ma liste';
  @override
  String addedToWatchlist(String name) => '« $name » est dans votre liste';
  @override
  String removedFromWatchlist(String name) => '« $name » retiré de votre liste';
  @override
  String get addToList => 'Ajouter à une liste';
  @override
  String get addToListMenu => 'Ajouter à une liste …';
  @override
  String addedToList(String list) => 'Ajouté à « $list »';
  @override
  String get newList => 'Nouvelle liste';
  @override
  String get listNameHint => 'Nom, par ex. « Soirée ciné »';
  @override
  String get listsHint => 'Listes privées sur votre serveur Jellyfin – disponibles sur tous vos appareils.';
  @override
  String get noListsYet =>
      'Aucune liste pour l’instant. Utilisez le marque-page d’un titre ou « Ajouter à une liste ».';
  @override
  String get listEmpty => 'Cette liste est vide.';
  @override
  String get deleteList => 'Supprimer la liste';
  @override
  String deleteListQuestion(String name) => 'Supprimer « $name » ?';
  @override
  String get deleteListText => 'La liste est supprimée sur votre serveur. Les titres eux-mêmes restent.';
  @override
  String removeFromList(String name) => 'Retirer « $name » de la liste';
  @override
  String get homeRows => 'Rangées de l’accueil';
  @override
  String get homeRowsHint =>
      'Glissez pour réordonner, désactivez le superflu. Les changements s’appliquent tout de suite.';
  @override
  String get homeRowsSettingsHint => 'Ordre et visibilité des rangées de la page d’accueil.';
  @override
  String get customize => 'Personnaliser';
  @override
  String get moveUp => 'Monter';
  @override
  String get moveDown => 'Descendre';
  @override
  String get resetToDefault => 'Rétablir par défaut';
  @override
  String homeRowName(String id) => switch (id) {
    'seasonal' => 'Rangée de saison',
    'latest' => 'Nouveautés de vos bibliothèques',
    'genres' => 'Rangées par genre',
    _ => super.homeRowName(id),
  };
  @override
  String get shortcuts => 'Raccourcis clavier';
  @override
  String get shortcutsEverywhere => 'Partout';
  @override
  String get shortcutsPlayer => 'Lecteur';
  @override
  String get shortcutsController => 'Manette';
  @override
  String get shortcutMoveFocus => 'Déplacer la sélection';
  @override
  String get shortcutOpen => 'Ouvrir / choisir';
  @override
  String get shortcutSeek => '10 s en arrière / en avant';
  @override
  String get shortcutVolume => 'Volume';
  @override
  String get shortcutScreenshot => 'Capture d’écran';
  @override
  String get shortcutMenu => 'Menu (comme le clic droit)';
  @override
  String get keySpace => 'Espace';
  @override
  String get ok => 'OK';
  @override
  String get standard => 'Par défaut';
  @override
  String notEnoughSpace(String needed, String free) => 'Il faut environ $needed, mais seulement $free sont libres.';
  @override
  String get notEnoughSpaceTitle => 'Espace insuffisant';
  @override
  String get diskAlmostFull => 'Disque presque plein – téléchargement arrêté';
  @override
  String get downloadAnyway => 'Télécharger quand même';
  @override
  String get downloadWaitsForWifi =>
      'Connexion limitée – le téléchargement démarrera dès que tu seras en Wi-Fi ou en réseau filaire.';
  @override
  String get chooseFolder => 'Choisir le dossier';
  @override
  String get folderNotAllowed => _isMac
      ? 'Les téléchargements ne peuvent pas aller dans les dossiers système (System, Applications, Library). Choisis un autre dossier.'
      : 'Les téléchargements ne peuvent pas aller dans les dossiers système (Windows, Program Files, AppData). Choisis un autre dossier.';
  @override
  String folderNotWritable(String error) => 'Jellyflex ne peut pas écrire dans ce dossier ($error).';
  @override
  String get folderProblem => 'Dossier inutilisable';
  @override
  String get downloadFolderQuestion => 'Où enregistrer les téléchargements ?';
  @override
  String get downloadFolderQuestionText =>
      'Jellyflex enregistre les téléchargements dans ce dossier. Tu peux le changer à tout moment dans les réglages.';
  @override
  String freeSpace(String size) => '$size libres';
  @override
  String get changeFolder => 'Changer de dossier…';
  @override
  String get useThisFolder => 'Utiliser ce dossier';
  @override
  String get downloadOptionsTitle => 'Télécharger';
  @override
  String downloadEpisodesTitle(int count) => 'Télécharger $count épisodes';
  @override
  String get downloadOriginalHint =>
      'Fichier d’origine avec toutes les pistes audio et sous-titres – meilleure qualité, fichier le plus gros.';
  @override
  String get downloadConvertedHint =>
      'Le serveur crée une version plus légère : une piste audio, sous-titres en fichiers séparés. Peut prendre plus de temps que l’original.';
  @override
  String downloadSizeAbout(String size) => 'Environ $size';
  @override
  String get downloadDontAskAgain => 'Ne plus demander';
  @override
  String get downloadDontAskAgainHint => 'Utilise désormais cette qualité – modifiable dans les réglages.';
  @override
  String get downloadFolder => 'Dossier de téléchargement';
  @override
  String downloadFolderHint(String path) => '$path · Les téléchargements existants restent où ils sont.';
  @override
  String get unmeteredOnly => 'Uniquement en Wi-Fi ou filaire';
  @override
  String get unmeteredOnlyHint => _isMac
      ? 'Pas de téléchargement via partage de connexion ou réseaux en mode données réduites.'
      : 'Pas de téléchargement via données mobiles, partage de connexion ou réseaux que Windows marque comme limités.';
  @override
  String get speedLimit => 'Limite de vitesse';
  @override
  String get speedLimitHint => 'Pour que les téléchargements ne ralentissent pas le reste de ta connexion.';
  @override
  String get unlimited => 'Illimitée';
  @override
  String get downloadQuality => 'Qualité des téléchargements';
  @override
  String get downloadQualityHint => 'Les versions plus légères économisent de la place – le serveur les convertit.';
  @override
  String get askBeforeDownload => 'Demander avant chaque téléchargement';
  @override
  String get askBeforeDownloadHint => 'Choisir à chaque fois la qualité, l’audio et les sous-titres.';
  @override
  String get smartDownloads => 'Téléchargements intelligents';
  @override
  String get smartDownloadsHint => 'Supprime les épisodes vus et télécharge les suivants automatiquement.';
  @override
  String get smartEpisodes => 'Épisodes à garder prêts';
  @override
  String get smartEpisodesHint => 'Nombre d’épisodes non vus gardés téléchargés par série.';
  @override
  String get smartMaxSpace => 'Espace pour les téléchargements intelligents';
  @override
  String get smartMaxSpaceHint => 'Les téléchargements intelligents n’utilisent jamais plus.';
  @override
  String get noLimit => 'Sans limite';
  @override
  String get downloadStorage => 'Espace de stockage';
  @override
  String downloadStorageHint(String used, String free) =>
      'Les téléchargements utilisent $used · $free libres sur le disque';
  @override
  String get deleteWatchedDownloads => 'Supprimer les vus';
  @override
  String deleteWatchedQuestion(int count) => 'Supprimer les téléchargements vus ($count) ?';
  @override
  String get deleteWatchedText => 'Ils seront supprimés de ce PC. Tout reste sur le serveur.';
  @override
  String watchedDownloadsDeleted(int count) => 'Téléchargements vus supprimés ($count)';
  @override
  String get noWatchedDownloads => 'Aucun téléchargement vu';
  @override
  String get waitingForWifi => 'En attente du Wi-Fi ou du réseau filaire';
  @override
  String get waitingForWifiHint =>
      'Connexion limitée (données mobiles ou partage de connexion). Les téléchargements reprendront tout seuls.';
  @override
  String get allowMetered => 'Autoriser quand même';
  @override
  String get smartBadge => 'Auto';
  @override
  String get cancelDownload => 'Annuler le téléchargement';
  @override
  String get cancelDownloadQuestion => 'Annuler le téléchargement ?';
  @override
  String cancelDownloadText(String name) => 'Ce qui a déjà été téléchargé de « $name » sera supprimé.';
  @override
  String get cancelDownloads => 'Annuler les téléchargements';
  @override
  String downloadsCancelled(int count) => 'Téléchargements annulés ($count)';
  @override
  String get keepDownloading => 'Continuer';
  @override
  String get scenes => 'Scènes';
  @override
  String get updateVerifiedHint =>
      'Jellyflex télécharge l’installateur et vérifie d’abord sa signature numérique – un fichier modifié ou endommagé n’est jamais lancé.';
  @override
  String get updateVerifyFailed =>
      'La mise à jour n’a pas pu être téléchargée ou sa signature est incorrecte – rien n’a été installé.';
  @override
  String get updateReleasePage => 'Page des versions';
  @override
  String get profileLocked => 'Verrouillé – saisis ton code PIN pour continuer';
  @override
  String get unlock => 'Déverrouiller';
  @override
  String get switchProfile => 'Changer de profil';
  @override
  String get pinLock => 'Verrouiller en cas d’absence';
  @override
  String get pinLockHint => 'Redemande le code PIN après ce délai sans action (pas pendant la lecture d’une vidéo).';
  @override
  String get update => 'Mettre à jour';
  @override
  String updateToVersion(String version) => 'Mise à jour vers la version $version';
  @override
  String get updateDownloading => 'Téléchargement et vérification de la mise à jour …';
  @override
  String get updateInstalling => 'Installation – Jellyflex redémarre tout seul.';
  @override
  String updateReady(String version) =>
      'La version $version est prête – elle s’installera à la fermeture de Jellyflex.';
  @override
  String get restartNow => 'Redémarrer maintenant';
  @override
  String get autoUpdate => 'Installer les mises à jour automatiquement';
  @override
  String get autoUpdateHint =>
      'Les nouvelles versions sont téléchargées et vérifiées en arrière-plan, puis installées à la fermeture de Jellyflex.';
  @override
  String whatsNewTitle(String version) => 'Nouveautés de Jellyflex $version';
  @override
  String versionLabelShort(String version) => 'Version $version';
  @override
  String get allReleaseNotes => 'Toutes les notes de version';
  @override
  String get gotIt => 'Compris';

  // --- Ersteinrichtung und Heimnetz-Suche ---
  @override
  String get welcomeTitle => 'Bienvenue dans Jellyflex';
  @override
  String get welcomeHint => 'Quelques choix rapides, et c’est parti. Tout se modifie plus tard dans les paramètres.';
  @override
  String get setupLookTitle => 'Quel style pour Jellyflex ?';
  @override
  String get setupLookHint => 'Cliquez pour essayer – le changement est immédiat.';
  @override
  String get setupOptionsTitle => 'Encore quelques questions';
  @override
  String get setupOptionsHint => 'Activez ce qui vous plaît – rien n’est obligatoire.';
  @override
  String get setupLater => 'Plus tard';
  @override
  String get setupFinish => 'C’est parti';
  @override
  String stepOf(int step, int count) => 'Étape $step sur $count';
  @override
  String get searchNetwork => 'Chercher sur le réseau local';
  @override
  String get searchingNetwork => 'Recherche sur le réseau local …';
  @override
  String get searchNetworkHint =>
      'Seulement après votre clic : demande une fois sur le réseau local si un serveur Jellyfin répond. Rien ne part sur Internet.';
  @override
  String get noServerFound =>
      'Aucun serveur n’a répondu. Saisissez l’adresse vous-même – elle figure dans le tableau de bord Jellyfin.';
  @override
  String get serversFound => 'Trouvé sur le réseau local';
  @override
  String get searchAgain => 'Chercher à nouveau';

  // --- Player: Lautstärke, Schaust du noch?, Zufällig ---
  @override
  String get stillWatching => 'Vous regardez toujours ?';
  @override
  String stillWatchingHint(String next) => 'Plusieurs épisodes à la suite. Ensuite : $next';
  @override
  String get shuffle => 'Aléatoire';
  @override
  String get shufflePlay => 'Lecture aléatoire';
  @override
  String get nothingToShuffle => 'Rien à lire ici';
  @override
  String get upNextCaps => 'À SUIVRE';

  // --- Szenen-Vorschau auf Karten ---
  @override
  String get hoverPreview => 'Aperçu des scènes sur les cartes';
  @override
  String get hoverPreviewHint =>
      'Quand vous vous arrêtez sur un titre, la carte fait défiler des scènes (images de votre serveur, pas de vidéo).';

  // --- Lizenz ---
  @override
  String get licenseTitle => 'Licence';
  @override
  String get licenseHint =>
      'Jellyflex est un logiciel libre sous GNU GPL v3.0. Affiche les licences de tous les composants.';
  @override
  String get licenses => 'Licences';
  @override
  String get licenseLegalese => 'Logiciel libre sous GNU General Public License v3.0.';

  // --- Heimnetz-Suche: Hinweise ---
  @override
  String answeredBy(String ip) => 'Réponse de $ip';
  @override
  String get outsideHomeNetwork =>
      'Cette adresse mène hors de votre réseau local – ne la choisissez que si vous la connaissez.';
  @override
  String get onlyKnownServers =>
      'Tout appareil du réseau peut répondre – ne choisissez que des serveurs que vous connaissez.';

  // --- Fensterleiste im Vollbild ---
  @override
  String get leaveFullscreen => 'Quitter le plein écran (F11)';

  // --- Player: Bildausschnitt (Zoom) ---
  @override
  String get zoomTooltip => 'Taille de l’image (Z)';
  @override
  String get zoomFit => 'Ajuster – image entière';
  @override
  String get zoomFill => 'Remplir – sans bandes noires';
  @override
  String zoomPercent(int percent) => 'Zoom $percent %';
  @override
  String get shortcutZoom => 'Ajuster / remplir l’image';
  @override
  String get shortcutZoomWheel => 'Zoom libre';
  @override
  String get keyCtrlWheel => 'Ctrl + molette';

  // --- Anmeldung abgelaufen ---
  @override
  String get sessionExpired => 'Votre connexion a expiré – veuillez saisir à nouveau votre mot de passe.';
  @override
  String get signInAgain => 'Se reconnecter';
  @override
  String get perfTest => 'Test de performance';
  @override
  String get perfTestHint =>
      'Mesure la rapidité de votre serveur et de Jellyflex (environ 2 minutes) et enregistre un rapport sans données personnelles.';
  @override
  String get perfTestIntro =>
      'Jellyflex vérifie le serveur, les bibliothèques, la recherche, les images, le débit réseau, le défilement et la mémoire. Il ouvre lui-même votre plus grande bibliothèque – ne cliquez sur rien pendant ce temps. Rien n’est envoyé : le rapport est enregistré en JSON dans votre dossier Téléchargements.';
  @override
  String get perfTestPlayback => 'Tester aussi la lecture (lit un film sans le son pendant 20 secondes)';
  @override
  String get perfTestStart => 'Lancer le test';
  @override
  String get perfTestDone => 'Terminé – le rapport est enregistré.';
  @override
  String get perfTestFailed => 'Le test n’a pas pu être terminé.';
  @override
  String get perfServer => 'Réponse du serveur';
  @override
  String get perfNetwork => 'Débit réseau';
  @override
  String get perfImages => 'Chargement d’une image';
  @override
  String get perfScrolling => 'Défilement fluide';
  @override
  String get perfPlayback => 'Démarrage de la lecture';
  @override
  String get showInFolder => 'Afficher dans le dossier';
  @override
  String perfTestStep(int n, int total) => 'Étape $n sur $total – veuillez patienter';
}
