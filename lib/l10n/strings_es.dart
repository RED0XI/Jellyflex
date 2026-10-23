part of 'strings.dart';

// Español. Was hier fehlt, erscheint auf Englisch.

final class _Es extends S {
  const _Es() : super._(false);

  // --- Allgemein ---
  @override
  String get retry => 'Reintentar';
  @override
  String get back => 'Atrás';
  @override
  String get close => 'Cerrar';
  @override
  String get cancel => 'Cancelar';
  @override
  String get delete => 'Eliminar';
  @override
  String get details => 'Detalles';
  @override
  String get play => 'Reproducir';
  @override
  String get resume => 'Continuar';
  @override
  String get pause => 'Pausa';
  @override
  String get off => 'Desactivado';
  @override
  String get storage => 'Almacenamiento';
  @override
  String get about => 'Acerca de Jellyflex';
  @override
  String get appVersionLabel => 'Versión de la app';
  @override
  String get updateCheck => 'Buscar actualizaciones';
  @override
  String get updateCheckHint =>
      'Al iniciar, solo pregunta a GitHub el número de la última versión – nada sobre ti ni tu servidor. Desactivado por defecto.';
  @override
  String get checkNow => 'Comprobar';
  @override
  String updateAvailable(String v) => 'La versión $v está disponible';
  @override
  String get upToDate => 'Tienes la versión más reciente';
  @override
  String get updateCheckFailed => 'No se pudo buscar actualizaciones';
  @override
  String get errorReport => 'Informe de errores';
  @override
  String get errorReportHint =>
      'Versión, ajustes y últimos mensajes en un archivo de texto – para compartir si algo falla.';
  @override
  String get errorReportPrivacy =>
      'No se envía nada. Se quitan contraseñas, tokens, dirección del servidor, nombres y tu carpeta de usuario.';
  @override
  String get create => 'Crear';
  @override
  String get copy => 'Copiar';
  @override
  String get copied => 'Copiado';
  @override
  String get saveAs => 'Guardar como …';
  @override
  String get imageCache => 'Caché de imágenes';
  @override
  String imageCacheHint(String used) =>
      'Pósteres y fondos se guardan en el disco y aparecen al instante. En uso: $used';
  @override
  String get clearCache => 'Vaciar';
  @override
  String get cacheCleared => 'Caché de imágenes vaciada';
  @override
  String get unknown => 'Desconocido';
  @override
  String get library => 'Biblioteca';
  @override
  String get serverUnreachable => 'Ahora mismo no se puede acceder al servidor.';
  @override
  String get didNotWork => 'Lo siento, no ha funcionado.';
  @override
  String get minimize => 'Minimizar';
  @override
  String get maximize => 'Maximizar';
  @override
  String get restore => 'Restaurar';

  // --- Zeit & Zahlen ---
  @override
  String hours(int h) => '$h h';
  @override
  String minutes(int m) => '$m min';
  @override
  String remaining(String duration) => 'quedan $duration';
  @override
  String endsAt(String time) => 'Termina a las $time';
  @override
  String timeOfDay(int hour) => '$hour:00';
  @override
  String get midnight => 'Medianoche';
  @override
  List<String> get months => const [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  @override
  List<String> get weekdays => const ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  @override
  String date(DateTime d) => '${d.day} de ${months[d.month - 1]} de ${d.year}';
  @override
  String weekdayDate(DateTime d) => '${weekdays[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]}';
  @override
  String? languageName(String code) => const {
    'de': 'Alemán',
    'en': 'Inglés',
    'ja': 'Japonés',
    'fr': 'Francés',
    'es': 'Español',
    'it': 'Italiano',
    'tr': 'Turco',
    'ko': 'Coreano',
    'ru': 'Ruso',
    'pt': 'Portugués',
    'nl': 'Neerlandés',
    'pl': 'Polaco',
    'zh': 'Chino',
  }[code];
  @override
  String decimal(double value, int digits) => value.toStringAsFixed(digits).replaceAll('.', ',');
  @override
  String channels(int n) => '$n canales';
  @override
  String get original => 'Original';
  @override
  String get version => 'Versión';

  // --- Startseite ---
  @override
  String get continueWatching => 'Seguir viendo';
  @override
  String get nextUp => 'A continuación';
  @override
  String newIn(String library) => 'Novedades en $library';
  @override
  String get yourFavorites => 'Tus favoritos';
  @override
  String get collections => 'Colecciones';
  @override
  String becauseYouWatched(String name) => 'Porque viste «$name»';
  @override
  String becauseYouLike(String name) => 'Porque te gusta «$name»';
  @override
  String moreFrom(String name) => 'Más de $name';
  @override
  String withPerson(String name) => 'Con $name';
  @override
  String get recommendations => 'Recomendaciones';

  // --- Einstellungen ---
  @override
  String get settings => 'Ajustes';
  @override
  String get language => 'Idioma';
  @override
  String get appLanguage => 'Idioma de la app';
  @override
  String get appLanguageHint => 'Menús, botones y textos.';
  @override
  String get playback => 'Reproducción';
  @override
  String get preferredAudio => 'Pista de audio preferida';
  @override
  String get preferredAudioHint => 'Se elige al empezar si está disponible.';
  @override
  String get preferredSubtitles => 'Subtítulos preferidos';
  @override
  String get preferredSubtitlesHint => 'Los subtítulos completos tienen prioridad sobre los forzados.';
  @override
  String get asInJellyfin => 'Como en Jellyfin';
  @override
  String get quality => 'Calidad';
  @override
  String get qualityHint =>
      'Original reproduce el archivo directamente. Los niveles inferiores hacen que el servidor lo convierta – útil con conexiones lentas.';
  @override
  String get ambilight => 'Brillo Ambilight';
  @override
  String get ambilightHint => 'Los colores de la imagen brillan suavemente en las franjas negras junto al vídeo.';
  @override
  String get onlyInWindow => 'Solo en ventana';
  @override
  String get always => 'Siempre';
  @override
  String get alwaysInclFullscreen => 'Siempre (también en pantalla completa)';
  @override
  String get autoSkipIntro => 'Saltar intro y resumen automáticamente';
  @override
  String get autoSkipIntroHint => 'Desactivado: solo aparece el botón «Saltar intro».';
  @override
  String get autoplayNext => 'Reproducir el siguiente episodio automáticamente';
  @override
  String get autoplayNextHint => 'Con una cuenta atrás al final del episodio.';
  @override
  String get subtitleAppearance => 'Aspecto de los subtítulos';
  @override
  String get size => 'Tamaño';
  @override
  String get background => 'Fondo';
  @override
  String get subtitleBackgroundHint => 'Recuadro semitransparente detrás del texto.';
  @override
  String get subtitlePreview => 'Así se ven tus subtítulos.';
  @override
  String get home => 'Inicio';
  @override
  String get search => 'Buscar';
  @override
  String get more => 'Más';
  @override
  String get goodMorning => 'Buenos días';
  @override
  String get goodAfternoon => 'Buenas tardes';
  @override
  String get goodEvening => 'Buenas noches';
  @override
  String get coverStory => 'Portada';
  @override
  String get layout => 'Diseño';
  @override
  String get layoutHint =>
      'Cambia toda la estructura de la app – navegación, banner, tarjetas, tipografía. Los colores siguen como los elijas abajo.';
  @override
  String layoutName(String id, String en, String de) => switch (id) {
    'cinema' => 'Cine',
    'couch' => 'Sofá',
    'library' => 'Biblioteca',
    'magazine' => 'Revista',
    'minimal' => 'Minimal',
    'retro' => 'Retro VHS',
    _ => en,
  };
  @override
  String layoutDescription(String id, String en, String de) => switch (id) {
    'cinema' => 'Gran banner, barra flotante, pósteres que se amplían.',
    'couch' => 'Mosaicos grandes y pestañas para la tele y el mando.',
    'library' => 'Barra lateral con todas las bibliotecas, filas compactas.',
    'magazine' => 'Editorial: titulares con serifa, reportaje de portada, esquinas rectas.',
    'minimal' => 'Sin banner ni adornos – tus títulos y mucho espacio.',
    'retro' => 'Brillo de tubo, líneas de barrido y letra de máquina de escribir.',
    _ => en,
  };
  @override
  String get profilePin => 'PIN del perfil';
  @override
  String get profilePinHint => 'Opcional: pide un PIN antes de abrir este perfil en este ordenador.';
  @override
  String get profilePinOnHint => 'Activado – este perfil solo se abre con su PIN.';
  @override
  String get pinSet => 'Establecer PIN';
  @override
  String get pinChange => 'Cambiar PIN';
  @override
  String get pinRemove => 'Quitar';
  @override
  String get pinSaved => 'PIN guardado';
  @override
  String get pinRemoved => 'PIN eliminado';
  @override
  String get pinCurrent => 'PIN actual';
  @override
  String get pinChoose => 'Elige un PIN';
  @override
  String get pinChooseHint => 'De 4 a 6 cifras';
  @override
  String get pinRepeat => 'Repite el PIN';
  @override
  String get pinFormat => 'Introduce de 4 a 6 cifras';
  @override
  String get pinWrong => 'PIN incorrecto';
  @override
  String pinLocked(int s) => 'Demasiados intentos – espera $s s';
  @override
  String pinFor(String name) => 'PIN de $name';
  @override
  String pinDigits(int n) => '$n cifras introducidas';
  @override
  String get pinDelete => 'Borrar cifra';
  @override
  String get pinConfirm => 'Confirmar';
  @override
  String get pinProtected => 'Protegido con PIN';
  @override
  String downloadFinished(String name) => '«$name» se ha descargado';
  @override
  String downloadsFinished(int n) => '$n descargas terminadas';
  @override
  String get themeMusic => 'Música del título';
  @override
  String get themeMusicHint => 'Reproduce suavemente la música del título en su página (si tu servidor la tiene).';
  @override
  String get select => 'Seleccionar';
  @override
  String get selected => 'seleccionado';
  @override
  String get notSelected => 'no seleccionado';
  @override
  String selectedCount(int n) => '$n seleccionados';
  @override
  String get selectAll => 'Seleccionar todo';
  @override
  String get endSelection => 'Terminar selección (Esc)';
  @override
  String get favorite => 'Favorito';
  @override
  String get selectionMarkedWatched => 'Marcado como visto';
  @override
  String get selectionMarkedUnwatched => 'Marcado como no visto';
  @override
  String get selectionAddedToFavorites => 'Añadido a favoritos';
  @override
  String get selectionDownloading => 'Descargas iniciadas';
  @override
  String get recentSearches => 'Búsquedas recientes';
  @override
  String get clearHistory => 'Borrar historial';
  @override
  String get filterAll => 'Todo';
  @override
  String get people => 'Personas';
  @override
  String get onlyUnwatched => 'Solo no vistos';
  @override
  String removeSearch(String term) => 'Quitar «$term»';
  @override
  String get recapOnlyYou => 'Solo cuenta tu perfil';
  @override
  String recapMarkedNote(int n) =>
      n == 1 ? '1 título solo marcado como visto (no cuenta)' : '$n títulos solo marcados como vistos (no cuentan)';
  @override
  String get watched => 'Visto';
  @override
  String get chapters => 'Capítulos';
  @override
  String get chaptersKey => 'Capítulos (C)';
  @override
  String chapterN(int n) => 'Capítulo $n';
  @override
  String get screenshotSaved => 'Captura guardada en Imágenes';
  @override
  String get screenshotFailed => 'No se pudo hacer la captura';
  @override
  String get statsTitle => 'Información de reproducción (I)';
  @override
  String get statsPlayback => 'Reproducción';
  @override
  String get statsDecoder => 'Decodificación';
  @override
  String get statsSoftware => 'Software (CPU)';
  @override
  String get statsHardware => 'Hardware';
  @override
  String get statsBuffer => 'Búfer';
  @override
  String get statsDropped => 'Fotogramas perdidos';
  @override
  String get statsDirectPlay => 'Directa (archivo original)';
  @override
  String get statsTranscoding => 'Convertido por el servidor';
  @override
  String get statsLocalFile => 'Archivo descargado';
  @override
  String episodesWatchedOf(int n, int total) => '$n de $total vistos';
  @override
  String downloadedOf(int n, int total) => '$n de $total descargados';
  @override
  String get markSeasonWatched => 'Marcar temporada como vista';
  @override
  String get markSeasonUnwatched => 'Marcar temporada como no vista';
  @override
  String markSeasonWatchedQuestion(String season) => '¿Marcar «$season» como vista?';
  @override
  String markSeasonWatchedDetail(int n) =>
      'Los $n episodios se marcarán como vistos. Tu resumen del año no los contará como tiempo visto.';
  @override
  String seasonMarkedWatched(String season) => '$season marcada como vista';
  @override
  String seasonMarkedUnwatched(String season) => '$season marcada como no vista';
  @override
  String get bannerTrailers => 'Tráileres en el banner';
  @override
  String get bannerTrailersHint => 'Tras unos segundos, reproduce el tráiler sin sonido (si existe).';
  @override
  String get screensaver => 'Salvapantallas';
  @override
  String get screensaverHint =>
      'Tras un rato sin actividad, muestra imágenes de tus películas y series con un reloj. Nunca durante la reproducción.';
  @override
  String get showNow => 'Mostrar ahora';
  @override
  String afterMinutes(int m) => 'Tras $m min';
  @override
  String get seasonalThemes => 'Toques de temporada';
  @override
  String get seasonalThemesHint =>
      'Para Halloween, Navidad, Nochevieja y San Valentín: una fila a juego y pequeños efectos en el inicio.';
  @override
  String get episodeImages => 'Imágenes de episodio en «Seguir viendo»';
  @override
  String get episodeImagesHint => 'Desactivado: muestra la imagen de la serie en lugar del episodio.';
  @override
  String get personalize => 'Personalizar';
  @override
  String get appName => 'Nombre de la app';
  @override
  String get appNameHint => 'Se muestra en la barra de título, el título de la ventana y al iniciar sesión.';
  @override
  String get logo => 'Logotipo';
  @override
  String get logoHint => 'Una imagen (PNG, JPG …) – se muestra antes del nombre y como icono de la barra de tareas.';
  @override
  String get sounds => 'Sonidos';
  @override
  String get soundsHint => 'Tics y melodías en «Sorpréndeme» y el quiz.';
  @override
  String get theme => 'Tema';
  @override
  String get themeHint => 'Colores de toda la app – cambia al instante.';
  @override
  String themeName(String id) => switch (id) {
    'midnight' => 'Medianoche',
    'oled' => 'Negro OLED',
    'cinema' => 'Rojo cine',
    'frost' => 'Escarcha nórdica',
    'sunset' => 'Atardecer',
    'synthwave' => 'Synthwave',
    'emerald' => 'Esmeralda',
    'noir' => 'Negro y oro',
    _ => id,
  };
  @override
  String get images => 'Imágenes';
  @override
  String get loading => 'Cargando …';
  @override
  String get chooseImage => 'Elegir imagen …';
  @override
  String get removeLogo => 'Quitar logotipo';
  @override
  String get imageUnreadable => 'No se pudo leer esta imagen.';
  @override
  String get resetToJellyflex => 'Volver a Jellyflex';
  @override
  String get account => 'Cuenta';
  @override
  String get signOut => 'Cerrar sesión';
  @override
  String basedOn(String name, String version) => '$name · basado en Jellyflex $version';

  // --- Detailseite ---
  @override
  String contentCouldNotLoad(Object e) => 'No se pudo cargar el contenido.\n$e';
  @override
  String get moreEpisodes => 'Más episodios';
  @override
  String seasonN(int n) => 'Temporada $n';
  @override
  String episodeN(int n) => 'Episodio $n';
  @override
  String seasonsCount(int n) => n == 1 ? '1 temporada' : '$n temporadas';
  @override
  String get fromStart => 'Desde el principio';
  @override
  String versionLabel(String v) => 'Versión: $v';
  @override
  String get markUnplayed => 'Marcar como no visto';
  @override
  String get markPlayed => 'Marcar como visto';
  @override
  String get removeFavorite => 'Quitar de favoritos';
  @override
  String get addFavorite => 'Añadir a favoritos';
  @override
  String get mediaInfoTooltip => 'Información del medio (resolución, audio, subtítulos …)';
  @override
  String get downloadOffline => 'Descargar (ver sin conexión)';
  @override
  String get downloadedClickToDelete => 'Descargado – haz clic para eliminar';
  @override
  String get pauseDownload => 'Pausar descarga';
  @override
  String get resumeDownload => 'Reanudar descarga';
  @override
  String get seasonAlreadyDownloaded => 'Todos los episodios de esta temporada ya están descargados';
  @override
  String episodesDownloading(int n) => n == 1 ? 'Se está descargando 1 episodio' : 'Se están descargando $n episodios';
  @override
  String get downloadSeason => 'Descargar temporada';
  @override
  String get thisEpisode => 'Este episodio';
  @override
  String get cast => 'Reparto';
  @override
  String get youMightLike => 'También te puede gustar';
  @override
  String get inThisCollection => 'En esta colección';
  @override
  String get mediaInfo => 'Información del medio';
  @override
  String get format => 'Formato';
  @override
  String get totalBitrate => 'Tasa de bits total';
  @override
  String get runtime => 'Duración';
  @override
  String get fileName => 'Nombre del archivo';
  @override
  String get video => 'Vídeo';
  @override
  String get resolution => 'Resolución';
  @override
  String get codec => 'Códec';
  @override
  String get dynamicRange => 'Rango dinámico';
  @override
  String get bitDepth => 'Profundidad de bits';
  @override
  String get frameRate => 'Fotogramas por segundo';
  @override
  String get bitrate => 'Tasa de bits';
  @override
  String audioCount(int n) => 'Audio ($n)';
  @override
  String subtitlesCount(int n) => 'Subtítulos ($n)';
  @override
  String get defaultTrack => 'Predeterminado';
  @override
  String get forced => 'Forzados';

  // --- Kontextmenü ---
  @override
  String get playFromStart => 'Reproducir desde el principio';
  @override
  String get goToSeries => 'Ir a la serie';
  @override
  String get alreadyWatched => 'Ya visto';
  @override
  String get forget => 'Olvidar';
  @override
  String get download => 'Descargar';
  @override
  String get deleteDownload => 'Eliminar descarga';
  @override
  String markedWatched(String name) => '«$name» marcado como visto';
  @override
  String markedUnwatched(String name) => '«$name» marcado como no visto';
  @override
  String get addedToFavorites => 'Añadido a favoritos';
  @override
  String get removedFromFavorites => 'Quitado de favoritos';
  @override
  String downloadStarted(String name) => 'Descarga iniciada: $name';
  @override
  String get downloadDeleted => 'Descarga eliminada';
  @override
  String get removedFromContinue => 'Quitado de «Seguir viendo»';

  // --- Downloads ---
  @override
  String get downloads => 'Descargas';
  @override
  String get savedForOffline => 'Guardado en este PC para ver sin conexión';
  @override
  String downloadsSummary(int count, String size) => '$count ${count == 1 ? 'título' : 'títulos'} · $size en uso';
  @override
  String get openFolder => 'Abrir carpeta';
  @override
  String get noDownloadsYet => 'Todavía no hay descargas.';
  @override
  String get noDownloadsHint => 'Haz clic en «Descargar» en una página de detalles o con el botón derecho.';
  @override
  String get downloading => 'Descargando';
  @override
  String get readyOffline => 'Listo sin conexión';
  @override
  String get deleteDownloadQuestion => '¿Eliminar la descarga?';
  @override
  String deleteDownloadText(String name) => '«$name» se eliminará de este PC. Todo sigue en el servidor.';
  @override
  String get waiting => 'En espera …';
  @override
  String receivedOf(String received, String total) => '$received de $total';
  @override
  String get starting => 'Iniciando …';
  @override
  String paused(String? reason) => 'En pausa${reason != null ? ' – $reason' : ''}';
  @override
  String failed(String? reason) => 'Error: ${reason ?? 'desconocido'}';
  @override
  String get done => 'Listo';
  @override
  String get cancelAndDelete => 'Cancelar y eliminar';

  // --- Anmeldung ---
  @override
  String get noServerAtAddress => 'No se encontró ningún servidor Jellyfin en esta dirección.';
  @override
  String get wrongCredentials => 'El usuario o la contraseña son incorrectos.';
  @override
  String signInFailedCode(String code) => 'Error al iniciar sesión ($code).';
  @override
  String signInFailed(Object e) => 'Error al iniciar sesión: $e';
  @override
  String get quickConnectExpired => 'Quick Connect ha caducado. Inténtalo de nuevo.';
  @override
  String get quickConnectFailed => 'No se pudo iniciar Quick Connect.';
  @override
  String get tagline => 'Tu cine. En tu escritorio.';
  @override
  String get whoIsWatching => '¿Quién está viendo?';
  @override
  String get addAccount => 'Añadir cuenta';
  @override
  String get toProfileSelection => 'Volver a los perfiles';
  @override
  String get connectServer => 'Conectar con el servidor';
  @override
  String get enterServerAddress => 'Introduce la dirección de tu servidor Jellyfin.';
  @override
  String get serverAddress => 'Dirección del servidor';
  @override
  String get connect => 'Conectar';
  @override
  String get quickConnectHint =>
      'Abre Jellyfin en un dispositivo con sesión iniciada → Perfil → Quick Connect e introduce este código:';
  @override
  String get otherServer => 'Otro servidor';
  @override
  String get certificateInvalid =>
      'El certificado de seguridad del servidor no es válido. Por tu seguridad, Jellyflex no se conecta.';
  @override
  String get unencryptedWarning =>
      'Conexión sin cifrar: tu contraseña y tus datos se pueden leer en la red. Úsala solo en casa.';
  @override
  String get signIn => 'Iniciar sesión';
  @override
  String get username => 'Usuario';
  @override
  String get password => 'Contraseña';
  @override
  String get signInWithQuickConnect => 'Iniciar sesión con Quick Connect';
  @override
  String get removeAccount => 'Quitar cuenta';

  // --- Bibliothek ---
  @override
  String get sortTitle => 'Título';
  @override
  String get sortAdded => 'Añadidos recientemente';
  @override
  String get sortReleased => 'Fecha de estreno';
  @override
  String get sortRating => 'Valoración';
  @override
  String get sortRandom => 'Aleatorio';
  @override
  String get unwatched => 'No vistos';
  @override
  String get favorites => 'Favoritos';
  @override
  String get genre => 'Género';
  @override
  String get allGenres => 'Todos los géneros';
  @override
  String get decade => 'Década';
  @override
  String decadeLabel(int d) => 'Años ${d >= 2000 ? d : d % 100}';
  @override
  String get allYears => 'Todos los años';
  @override
  String get resetFilters => 'Restablecer filtros';
  @override
  String titlesCount(int n) => n == 1 ? '1 título' : '$n títulos';
  @override
  String libraryCouldNotLoad(Object e) => 'No se pudo cargar la biblioteca.\n$e';
  @override
  String get noTitlesMatch => 'Ningún título coincide con estos filtros.';
  @override
  String homeCouldNotLoad(Object e) => 'No se pudo cargar la página de inicio.\n$e';
  @override
  String get viewDownloads => 'Ver descargas';
  @override
  String get libraries => 'Bibliotecas';
  @override
  String get movieQuiz => 'Quiz de cine';
  @override
  String get surpriseMe => 'Sorpréndeme';
  @override
  String get searchCtrlF => 'Buscar (Ctrl+F)';
  @override
  String get profile => 'Perfil';
  @override
  String get switchUser => 'Cambiar de usuario';
  @override
  String get yearlyRecap => 'Resumen del año';
  @override
  String get soundOn => 'Sonido activado';
  @override
  String get soundOff => 'Sonido desactivado';
  @override
  String get watch => 'Ver';
  @override
  String get moreInfo => 'Más información';

  // --- Suche ---
  @override
  String get searchHint => 'Buscar títulos, episodios o actores …';
  @override
  String get clear => 'Borrar';
  @override
  String searchFailed(Object e) => 'La búsqueda falló: $e';
  @override
  String get whatDoYouFeelLike => '¿Qué te apetece ver?';
  @override
  String nothingFoundFor(String term) => 'No se encontró nada para «$term».';
  @override
  String get movies => 'Películas';
  @override
  String get shows => 'Series';
  @override
  String get episodes => 'Episodios';

  // --- Personen ---
  @override
  String personCouldNotLoad(Object e) => 'No se pudo cargar la persona.\n$e';
  @override
  String get noTitlesWithPerson => 'No hay películas ni series con esta persona en tu servidor.';
  @override
  String get onYourServer => 'En tu servidor';
  @override
  String allCount(int n) => 'Todo ($n)';
  @override
  String moviesCount(int n) => 'Películas ($n)';
  @override
  String showsCount(int n) => 'Series ($n)';
  @override
  String get guestAppearances => 'Apariciones en episodios';
  @override
  String bornOn(String date, int? age, String? place) =>
      'Nació el $date${age != null ? ' ($age años)' : ''}${place != null ? ' en $place' : ''}';
  @override
  String bornIn(String place) => 'Nació en $place';
  @override
  String diedOn(String date, int? age) => 'Murió el $date${age != null ? ' ($age años)' : ''}';
  @override
  String movieCount(int n) => n == 1 ? '1 película' : '$n películas';
  @override
  String showCount(int n) => n == 1 ? '1 serie' : '$n series';
  @override
  String episodeCount(int n) => n == 1 ? '1 episodio' : '$n episodios';
  @override
  String onYourServerCounts(String counts) => '$counts en tu servidor';
  @override
  String get showLess => 'Ver menos';
  @override
  String get showMore => 'Ver más';

  // --- Saisonales ---
  @override
  String get halloween => 'Temporada de sustos';
  @override
  String get christmas => 'Época navideña';
  @override
  String get newYearsEve => 'Nochevieja';
  @override
  String get valentinesDay => 'San Valentín';

  // --- Roulette ---
  @override
  String get nothingFoundLoosen => 'No se encontró nada – relaja un poco los filtros.';
  @override
  String get letChanceDecide => 'Deja que el azar decida qué ver esta noche.';
  @override
  String get spinning => 'Girando …';
  @override
  String get spin => 'Girar';
  @override
  String get spinAgain => 'Girar otra vez';
  @override
  String get anyTime => 'Cualquier duración';
  @override
  String get both => 'Ambos';
  @override
  String get unwatchedOnly => 'Solo no vistos';
  @override
  String get all => 'Todo';
  @override
  String genreLabel(String g) => 'Género: $g';
  @override
  String finishedBy(String time) => 'Termina hacia: $time';
  @override
  String get startSeries => 'Empezar la serie';

  // --- Quiz ---
  @override
  String get quizNeedsTitles => 'El quiz necesita al menos 4 películas o series con imagen de fondo.';
  @override
  String roundOf(int n, int total) => 'Ronda $n de $total';
  @override
  String points(int n) => '$n puntos';
  @override
  String correctPlus(int n) => '¡Correcto! +$n';
  @override
  String get notQuite => 'Casi';
  @override
  String get result => 'Resultado';
  @override
  String get next => 'Siguiente';
  @override
  String get verdictPro => '¡Experto en cine! 🍿';
  @override
  String get verdictStrong => '¡Muy bien! 🎬';
  @override
  String get verdictNotBad => '¡Nada mal! 🎞️';
  @override
  String get verdictMore => 'Se puede mejorar … 📼';
  @override
  String get newRecord => '¡Nuevo récord!';
  @override
  String correctOf(int correct, int rounds, int record) => '$correct de $rounds correctas  ·  Récord: $record';
  @override
  String get playAgain => 'Jugar otra vez';

  // --- Jahresrückblick ---
  @override
  String recapFileName(String app, int year) => '$app Resumen $year';
  @override
  String savedToPictures(String name) => 'Guardado en Imágenes: $name';
  @override
  String get show => 'Mostrar';
  @override
  String get imageNotSaved => 'No se pudo guardar la imagen.';
  @override
  String get calculatingYear => 'Calculando tu año …';
  @override
  String get saveAsImage => 'Guardar como imagen';
  @override
  String get watchAgain => 'Ver de nuevo';
  @override
  String yourYear(int y) => 'Tu $y';
  @override
  String get nothingThisYear => 'Todavía no has terminado nada este año.';
  @override
  String get letsLookBack => 'Echemos la vista atrás.';
  @override
  String get youWatched => 'Has visto';
  @override
  String get hoursSuffix => ' horas';
  @override
  String get thatWas => 'Eso fueron';
  @override
  String get movieWord => 'película';
  @override
  String get moviesWord => 'películas';
  @override
  String get episodeWord => 'episodio';
  @override
  String get episodesWord => 'episodios';
  @override
  String get showWord => 'serie';
  @override
  String get showsWord => 'series';
  @override
  String longestMovie(String name, String runtime) => 'Película más larga: $name ($runtime)';
  @override
  String get favoriteGenre => 'Tu género favorito';
  @override
  String get showOfTheYear => 'Tu serie del año';
  @override
  String episodesWatched(int n) => n == 1 ? '1 episodio visto' : '$n episodios vistos';
  @override
  String get seenMostOften => 'Visto más a menudo';
  @override
  String inTitles(int n) => n == 1 ? 'en 1 título' : 'en $n títulos';
  @override
  String get biggestMarathon => 'Tu mayor maratón';
  @override
  String inOneDay(String duration) => '$duration en un día 🍿';
  @override
  String favoriteHourText(int hour) => 'Te gusta ver cosas hacia las ${timeOfDay(hour)}.';
  @override
  String daysInARow(String days) => 'Son $days días seguidos.';
  @override
  String asLongAsTitanic(String times) => 'Tanto como $times× «Titanic».';
  @override
  String get nightOwl => 'Búho nocturno 🦉';
  @override
  String get earlyBird => 'Madrugador ☀️';
  @override
  String get eveningWatcher => 'De después del trabajo 🛋️';
  @override
  String get afternoonWatcher => 'De sobremesa ☕';
  @override
  String recapTitle(String app, int year) => '$app · Resumen $year';
  @override
  String get hoursWord => 'Horas';
  @override
  String get moviesTitle => 'Películas';
  @override
  String get episodesTitle => 'Episodios';
  @override
  String get showsTitle => 'Series';
  @override
  String get favoriteGenreShort => 'Género favorito';
  @override
  String get showOfTheYearShort => 'Serie del año';
  @override
  String get favoriteTime => 'Hora favorita';

  // --- Player ---
  @override
  String get sleepTimer => 'Temporizador de apagado';
  @override
  String get endOfThisEpisode => 'Al final de este episodio';
  @override
  String get endOfThisMovie => 'Al final de la película';
  @override
  String inMinutes(int m) => 'En $m minutos';
  @override
  String get atTheEnd => 'al final';
  @override
  String seconds(int sec) => '$sec s';
  @override
  String get noPlayableFile => 'No se encontró ningún archivo reproducible.';
  @override
  String get noTranscodeFromServer => 'El servidor no ofreció una versión convertida.';
  @override
  String fileCouldNotLoad(String message) => 'No se pudo cargar el archivo.\n$message';
  @override
  String get playbackNotPossible => 'No se puede reproducir';
  @override
  String get bigWindow => 'Ventana grande (P)';
  @override
  String get backEsc => 'Atrás (Esc)';
  @override
  String get pauseSpace => 'Pausa (Espacio)';
  @override
  String get playSpace => 'Reproducir (Espacio)';
  @override
  String get rewind10 => 'Retroceder 10 s (←)';
  @override
  String get forward10 => 'Avanzar 10 s (→)';
  @override
  String get audioAndSubtitles => 'Audio y subtítulos';
  @override
  String get playbackOptions => 'Reproducción: velocidad, calidad, sincronía';
  @override
  String get miniPlayer => 'Minirreproductor (P)';
  @override
  String get exitFullscreen => 'Salir de pantalla completa (F)';
  @override
  String get fullscreen => 'Pantalla completa (F)';
  @override
  String get mute => 'Silenciar (M)';
  @override
  String get audio => 'Audio';
  @override
  String get subtitles => 'Subtítulos';
  @override
  String get noAudioTracks => 'No se encontraron pistas de audio';
  @override
  String get noSubtitles => 'No hay subtítulos disponibles';
  @override
  String get file => 'Archivo';
  @override
  String get goodNight => 'Buenas noches';
  @override
  String get sleepTimerPaused => 'El temporizador ha pausado la reproducción.';
  @override
  String get keepWatching => 'Seguir viendo';
  @override
  String get closePlayer => 'Cerrar reproductor';
  @override
  String get skipIntro => 'Saltar intro';
  @override
  String get skipRecap => 'Saltar resumen';
  @override
  String get skipPreview => 'Saltar avance';
  @override
  String get skipCommercial => 'Saltar anuncio';
  @override
  String get skip => 'Saltar';
  @override
  String get nextEpisodeCaps => 'SIGUIENTE EPISODIO';
  @override
  String get watchCredits => 'Ver créditos';
  @override
  String get watchNow => 'Ver ahora';
  @override
  String get speed => 'Velocidad';
  @override
  String get sync => 'Sincronía';
  @override
  String get sound => 'Sonido';
  @override
  String get withoutConversion => 'sin conversión';
  @override
  String get reset => 'Restablecer';

  // --- Fehler & Verbindung ---
  @override
  String get notAJellyfinServer => 'No es un servidor Jellyfin';
  @override
  String get serverNotReachable => 'Servidor inaccesible';
  @override
  String get otherAccountSignedIn => 'Hay otra cuenta con la sesión iniciada';
  @override
  String get noFileFound => 'No se encontró ningún archivo';
  @override
  String connectionInterrupted(String received, String total) => 'Conexión interrumpida ($received de $total)';
  @override
  String get unexpectedServerAddress => 'El servidor envió una dirección que no le pertenece – bloqueada.';
  @override
  String get noConnectionToServer => 'Sin conexión con el servidor';
  @override
  String get serverOffline => 'Servidor inaccesible';
  @override
  String get offlineHint => 'Tus descargas siguen funcionando.';
  @override
  String get backOnline => 'Conectado de nuevo al servidor';
  @override
  String serverError(int? code) => 'Error del servidor $code';
  @override
  String get encryptionFailed => 'Error de cifrado';

  // --- Listen, Startseite, Tastenkürzel ---
  @override
  String get watchlist => 'Mi lista';
  @override
  String get myLists => 'Mis listas';
  @override
  String get addToWatchlist => 'Añadir a mi lista';
  @override
  String get removeFromWatchlist => 'Quitar de mi lista';
  @override
  String addedToWatchlist(String name) => '«$name» está en tu lista';
  @override
  String removedFromWatchlist(String name) => '«$name» se quitó de tu lista';
  @override
  String get addToList => 'Añadir a una lista';
  @override
  String get addToListMenu => 'Añadir a una lista …';
  @override
  String addedToList(String list) => 'Añadido a «$list»';
  @override
  String get newList => 'Nueva lista';
  @override
  String get listNameHint => 'Nombre, p. ej. «Noche de cine»';
  @override
  String get listsHint => 'Listas privadas en tu servidor Jellyfin – disponibles en todos tus dispositivos.';
  @override
  String get noListsYet => 'Todavía no hay listas. Usa el marcador de un título o «Añadir a una lista».';
  @override
  String get listEmpty => 'Esta lista está vacía.';
  @override
  String get deleteList => 'Eliminar lista';
  @override
  String deleteListQuestion(String name) => '¿Eliminar «$name»?';
  @override
  String get deleteListText => 'La lista se elimina en tu servidor. Los títulos se mantienen.';
  @override
  String removeFromList(String name) => 'Quitar «$name» de la lista';
  @override
  String get homeRows => 'Filas de la página de inicio';
  @override
  String get homeRowsHint => 'Arrastra para reordenar y desactiva lo que no necesites. Se aplica al momento.';
  @override
  String get homeRowsSettingsHint => 'Orden y visibilidad de las filas en la página de inicio.';
  @override
  String get customize => 'Personalizar';
  @override
  String get moveUp => 'Subir';
  @override
  String get moveDown => 'Bajar';
  @override
  String get resetToDefault => 'Restablecer';
  @override
  String homeRowName(String id) => switch (id) {
    'seasonal' => 'Fila de temporada',
    'latest' => 'Novedades en tus bibliotecas',
    'genres' => 'Filas por género',
    _ => super.homeRowName(id),
  };
  @override
  String get shortcuts => 'Atajos de teclado';
  @override
  String get shortcutsEverywhere => 'En todas partes';
  @override
  String get shortcutsPlayer => 'Reproductor';
  @override
  String get shortcutsController => 'Mando';
  @override
  String get shortcutMoveFocus => 'Mover la selección';
  @override
  String get shortcutOpen => 'Abrir / elegir';
  @override
  String get shortcutSeek => '10 s atrás / adelante';
  @override
  String get shortcutVolume => 'Volumen';
  @override
  String get shortcutScreenshot => 'Captura de pantalla';
  @override
  String get shortcutMenu => 'Menú (como el clic derecho)';
  @override
  String get keySpace => 'Espacio';
  @override
  String get ok => 'Aceptar';
  @override
  String get standard => 'Predeterminado';
  @override
  String notEnoughSpace(String needed, String free) => 'Necesita unos $needed, pero solo hay $free libres.';
  @override
  String get notEnoughSpaceTitle => 'Espacio insuficiente';
  @override
  String get diskAlmostFull => 'Disco casi lleno – descarga detenida';
  @override
  String get downloadAnyway => 'Descargar de todos modos';
  @override
  String get downloadWaitsForWifi =>
      'Estás en una conexión de uso medido: la descarga empezará en cuanto estés en Wi-Fi o LAN.';
  @override
  String get chooseFolder => 'Elegir carpeta';
  @override
  String get folderNotAllowed =>
      'Las descargas no se pueden guardar en carpetas del sistema (Windows, Archivos de programa, AppData). Elige otra carpeta.';
  @override
  String folderNotWritable(String error) => 'Jellyflex no puede escribir en esta carpeta ($error).';
  @override
  String get folderProblem => 'No se puede usar la carpeta';
  @override
  String get downloadFolderQuestion => '¿Dónde guardar las descargas?';
  @override
  String get downloadFolderQuestionText =>
      'Jellyflex guarda las descargas en esta carpeta. Puedes cambiarla en cualquier momento en Ajustes.';
  @override
  String freeSpace(String size) => '$size libres';
  @override
  String get changeFolder => 'Cambiar carpeta…';
  @override
  String get useThisFolder => 'Usar esta carpeta';
  @override
  String get downloadOptionsTitle => 'Descargar';
  @override
  String downloadEpisodesTitle(int count) => 'Descargar $count episodios';
  @override
  String get downloadOriginalHint =>
      'Archivo original con todas las pistas de audio y subtítulos: mejor calidad, archivo más grande.';
  @override
  String get downloadConvertedHint =>
      'El servidor crea una versión más pequeña: una pista de audio y subtítulos en archivos aparte. Puede tardar más que el original.';
  @override
  String downloadSizeAbout(String size) => 'Unos $size';
  @override
  String get downloadDontAskAgain => 'No volver a preguntar';
  @override
  String get downloadDontAskAgainHint => 'Usará esta calidad a partir de ahora; se puede cambiar en Ajustes.';
  @override
  String get downloadFolder => 'Carpeta de descargas';
  @override
  String downloadFolderHint(String path) => '$path · Las descargas existentes se quedan donde están.';
  @override
  String get unmeteredOnly => 'Solo con Wi-Fi o LAN';
  @override
  String get unmeteredOnlyHint =>
      'Sin descargas con datos móviles, punto de acceso del móvil o redes que Windows marca como de uso medido.';
  @override
  String get speedLimit => 'Límite de velocidad';
  @override
  String get speedLimitHint => 'Para que las descargas no ralenticen el resto de tu conexión.';
  @override
  String get unlimited => 'Ilimitada';
  @override
  String get downloadQuality => 'Calidad de descarga';
  @override
  String get downloadQualityHint => 'Las versiones más pequeñas ahorran espacio; el servidor las convierte.';
  @override
  String get askBeforeDownload => 'Preguntar antes de cada descarga';
  @override
  String get askBeforeDownloadHint => 'Elegir calidad, audio y subtítulos cada vez.';
  @override
  String get smartDownloads => 'Descargas inteligentes';
  @override
  String get smartDownloadsHint => 'Borra los episodios vistos y descarga los siguientes automáticamente.';
  @override
  String get smartEpisodes => 'Episodios listos';
  @override
  String get smartEpisodesHint => 'Episodios sin ver por serie que se mantienen descargados.';
  @override
  String get smartMaxSpace => 'Espacio para descargas inteligentes';
  @override
  String get smartMaxSpaceHint => 'Las descargas inteligentes nunca usan más.';
  @override
  String get noLimit => 'Sin límite';
  @override
  String get downloadStorage => 'Almacenamiento';
  @override
  String downloadStorageHint(String used, String free) => 'Las descargas ocupan $used · $free libres en el disco';
  @override
  String get deleteWatchedDownloads => 'Borrar vistos';
  @override
  String deleteWatchedQuestion(int count) => '¿Borrar las descargas vistas ($count)?';
  @override
  String get deleteWatchedText => 'Se borrarán de este PC. Todo sigue en el servidor.';
  @override
  String watchedDownloadsDeleted(int count) => 'Descargas vistas borradas ($count)';
  @override
  String get noWatchedDownloads => 'No hay descargas vistas';
  @override
  String get waitingForWifi => 'Esperando Wi-Fi o LAN';
  @override
  String get waitingForWifiHint =>
      'Estás en una conexión de uso medido (datos móviles o punto de acceso). Las descargas seguirán solas.';
  @override
  String get allowMetered => 'Permitir igualmente';
  @override
  String get smartBadge => 'Auto';
  @override
  String get cancelDownload => 'Cancelar descarga';
  @override
  String get cancelDownloadQuestion => '¿Cancelar la descarga?';
  @override
  String cancelDownloadText(String name) => 'Se borrará lo que ya se haya descargado de «$name».';
  @override
  String get cancelDownloads => 'Cancelar descargas';
  @override
  String downloadsCancelled(int count) => 'Descargas canceladas ($count)';
  @override
  String get keepDownloading => 'Seguir descargando';
  @override
  String get scenes => 'Escenas';
  @override
  String get updateVerifiedHint =>
      'Jellyflex descarga el instalador y primero comprueba su firma digital: un archivo modificado o dañado nunca se ejecuta.';
  @override
  String get updateVerifyFailed =>
      'No se pudo descargar la actualización o su firma no es válida: no se ha instalado nada.';
  @override
  String get updateReleasePage => 'Página de versiones';
  @override
  String get updateInstall => 'Descargar e instalar';
}
