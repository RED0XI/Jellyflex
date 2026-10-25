part of 'strings.dart';

// Türkçe. Was hier fehlt, erscheint auf Englisch.

final class _Tr extends S {
  const _Tr() : super._(false);

  // --- Allgemein ---
  @override
  String get retry => 'Tekrar dene';
  @override
  String get back => 'Geri';
  @override
  String get close => 'Kapat';
  @override
  String get cancel => 'İptal';
  @override
  String get delete => 'Sil';
  @override
  String get details => 'Ayrıntılar';
  @override
  String get play => 'Oynat';
  @override
  String get resume => 'Devam et';
  @override
  String get pause => 'Duraklat';
  @override
  String get off => 'Kapalı';
  @override
  String get storage => 'Depolama';
  @override
  String get about => 'Jellyflex hakkında';
  @override
  String get appVersionLabel => 'Uygulama sürümü';
  @override
  String get updateCheck => 'Güncellemeleri denetle';
  @override
  String get updateCheckHint =>
      'Açılışta GitHub’a yalnızca en yeni sürüm numarasını sorar – senin ya da sunucun hakkında hiçbir şey göndermez. Varsayılan olarak kapalı.';
  @override
  String get checkNow => 'Şimdi denetle';
  @override
  String updateAvailable(String v) => '$v sürümü çıktı';
  @override
  String get upToDate => 'En yeni sürümü kullanıyorsun';
  @override
  String get updateCheckFailed => 'Güncellemeler denetlenemedi';
  @override
  String get errorReport => 'Hata raporu';
  @override
  String get errorReportHint =>
      'Sürüm, ayarlar ve son mesajlar bir metin dosyasında – bir sorun olursa paylaşmak için.';
  @override
  String get errorReportPrivacy =>
      'Hiçbir şey gönderilmez. Parolalar, belirteçler, sunucu adresi, adlar ve kullanıcı klasörün çıkarılır.';
  @override
  String get create => 'Oluştur';
  @override
  String get copy => 'Kopyala';
  @override
  String get copied => 'Kopyalandı';
  @override
  String get saveAs => 'Farklı kaydet …';
  @override
  String get imageCache => 'Görsel önbelleği';
  @override
  String imageCacheHint(String used) => 'Afişler ve arka planlar diskte saklanır ve anında görünür. Kullanılan: $used';
  @override
  String get clearCache => 'Temizle';
  @override
  String get cacheCleared => 'Görsel önbelleği temizlendi';
  @override
  String get unknown => 'Bilinmiyor';
  @override
  String get library => 'Kitaplık';
  @override
  String get serverUnreachable => 'Sunucuya şu anda ulaşılamıyor.';
  @override
  String get didNotWork => 'Üzgünüz, bu olmadı.';
  @override
  String get minimize => 'Simge durumuna küçült';
  @override
  String get maximize => 'Ekranı kapla';
  @override
  String get restore => 'Önceki boyut';

  // --- Zeit & Zahlen ---
  @override
  String hours(int h) => '$h sa';
  @override
  String minutes(int m) => '$m dk';
  @override
  String remaining(String duration) => '$duration kaldı';
  @override
  String endsAt(String time) => '$time’da biter';
  @override
  String timeOfDay(int hour) => '$hour:00';
  @override
  String get midnight => 'Gece yarısı';
  @override
  List<String> get months => const [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  @override
  List<String> get weekdays => const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  @override
  String date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
  @override
  String weekdayDate(DateTime d) => '${d.day} ${months[d.month - 1]}, ${weekdays[d.weekday - 1]}';
  @override
  String? languageName(String code) => const {
    'de': 'Almanca',
    'en': 'İngilizce',
    'ja': 'Japonca',
    'fr': 'Fransızca',
    'es': 'İspanyolca',
    'it': 'İtalyanca',
    'tr': 'Türkçe',
    'ko': 'Korece',
    'ru': 'Rusça',
    'pt': 'Portekizce',
    'nl': 'Felemenkçe',
    'pl': 'Lehçe',
    'zh': 'Çince',
  }[code];
  @override
  String decimal(double value, int digits) => value.toStringAsFixed(digits).replaceAll('.', ',');
  @override
  String channels(int n) => '$n kanal';
  @override
  String get original => 'Orijinal';
  @override
  String get version => 'Sürüm';

  // --- Startseite ---
  @override
  String get continueWatching => 'İzlemeye devam et';
  @override
  String get nextUp => 'Sıradaki';
  @override
  String newIn(String library) => '$library içinde yeni';
  @override
  String get yourFavorites => 'Favorilerin';
  @override
  String get collections => 'Koleksiyonlar';
  @override
  String becauseYouWatched(String name) => '“$name” izlediğin için';
  @override
  String becauseYouLike(String name) => '“$name” sevdiğin için';
  @override
  String moreFrom(String name) => '$name’dan daha fazlası';
  @override
  String withPerson(String name) => '$name ile';
  @override
  String get recommendations => 'Öneriler';

  // --- Einstellungen ---
  @override
  String get settings => 'Ayarlar';
  @override
  String get language => 'Dil';
  @override
  String get appLanguage => 'Uygulama dili';
  @override
  String get appLanguageHint => 'Menüler, düğmeler ve metinler.';
  @override
  String get playback => 'Oynatma';
  @override
  String get preferredAudio => 'Tercih edilen ses parçası';
  @override
  String get preferredAudioHint => 'Varsa başlangıçta seçilir.';
  @override
  String get preferredSubtitles => 'Tercih edilen altyazı';
  @override
  String get preferredSubtitlesHint => 'Tam altyazılar zorunlu altyazılardan önce gelir.';
  @override
  String get asInJellyfin => 'Jellyfin’deki gibi';
  @override
  String get quality => 'Kalite';
  @override
  String get qualityHint =>
      'Orijinal, dosyayı doğrudan oynatır. Daha düşük seviyelerde sunucu dönüştürür – yavaş bağlantılar için iyi.';
  @override
  String get ambilight => 'Ambilight ışıltısı';
  @override
  String get ambilightHint =>
      'Görüntünün renkleri videonun yanındaki ya da üstündeki siyah şeritlerde yumuşakça parlar.';
  @override
  String get onlyInWindow => 'Yalnızca pencerede';
  @override
  String get always => 'Her zaman';
  @override
  String get alwaysInclFullscreen => 'Her zaman (tam ekranda da)';
  @override
  String get autoSkipIntro => 'Giriş ve özeti otomatik atla';
  @override
  String get autoSkipIntroHint => 'Kapalı: yalnızca “Girişi atla” düğmesi görünür.';
  @override
  String get autoplayNext => 'Sonraki bölümü otomatik oynat';
  @override
  String get autoplayNextHint => 'Bölümün sonunda geri sayımla.';
  @override
  String get subtitleAppearance => 'Altyazı görünümü';
  @override
  String get size => 'Boyut';
  @override
  String get background => 'Arka plan';
  @override
  String get subtitleBackgroundHint => 'Metnin arkasında yarı saydam bir kutu.';
  @override
  String get subtitlePreview => 'Altyazıların böyle görünüyor.';
  @override
  String get home => 'Ana sayfa';
  @override
  String get search => 'Ara';
  @override
  String get more => 'Daha fazla';
  @override
  String get goodMorning => 'Günaydın';
  @override
  String get goodAfternoon => 'İyi günler';
  @override
  String get goodEvening => 'İyi akşamlar';
  @override
  String get coverStory => 'Kapak konusu';
  @override
  String get layout => 'Düzen';
  @override
  String get layoutHint =>
      'Uygulamanın tüm yapısını değiştirir – gezinme, afiş, kartlar, yazı tipi. Renkler aşağıda seçtiğin gibi kalır.';
  @override
  String layoutName(String id, String en, String de) => switch (id) {
    'cinema' => 'Sinema',
    'couch' => 'Kanepe',
    'library' => 'Kitaplık',
    'magazine' => 'Dergi',
    'minimal' => 'Sade',
    'retro' => 'Retro VHS',
    _ => en,
  };
  @override
  String layoutDescription(String id, String en, String de) => switch (id) {
    'cinema' => 'Büyük afiş, yüzen çubuk, büyüyen posterler.',
    'couch' => 'Televizyon ve oyun kumandası için büyük kutucuklar ve sekmeler.',
    'library' => 'Tüm kitaplıkların olduğu kenar çubuğu, sıkı sıralar.',
    'magazine' => 'Dergi gibi: tırnaklı başlıklar, kapak konusu, keskin köşeler.',
    'minimal' => 'Afiş yok, kalabalık yok – yalnızca başlıkların ve bolca boşluk.',
    'retro' => 'Tüplü TV ışıltısı, tarama çizgileri ve daktilo yazısı.',
    _ => en,
  };
  @override
  String get profilePin => 'Profil PIN’i';
  @override
  String get profilePinHint => 'İsteğe bağlı: bu profil bu bilgisayarda açılmadan önce PIN sorar.';
  @override
  String get profilePinOnHint => 'Açık – bu profil yalnızca PIN’iyle açılır.';
  @override
  String get pinSet => 'PIN belirle';
  @override
  String get pinChange => 'PIN’i değiştir';
  @override
  String get pinRemove => 'Kaldır';
  @override
  String get pinSaved => 'PIN kaydedildi';
  @override
  String get pinRemoved => 'PIN kaldırıldı';
  @override
  String get pinCurrent => 'Mevcut PIN';
  @override
  String get pinChoose => 'Bir PIN seç';
  @override
  String get pinChooseHint => '4 ila 6 rakam';
  @override
  String get pinRepeat => 'PIN’i tekrarla';
  @override
  String get pinFormat => 'Lütfen 4 ila 6 rakam gir';
  @override
  String get pinWrong => 'Yanlış PIN';
  @override
  String pinLocked(int s) => 'Çok fazla deneme – $s sn bekle';
  @override
  String pinFor(String name) => '$name için PIN';
  @override
  String pinDigits(int n) => '$n rakam girildi';
  @override
  String get pinDelete => 'Rakamı sil';
  @override
  String get pinConfirm => 'Onayla';
  @override
  String get pinProtected => 'PIN ile korunuyor';
  @override
  String downloadFinished(String name) => '“$name” indirildi';
  @override
  String downloadsFinished(int n) => '$n indirme tamamlandı';
  @override
  String get themeMusic => 'Tema müziği';
  @override
  String get themeMusicHint => 'Ayrıntı sayfasında başlığın tema müziğini kısık sesle çalar (sunucunda varsa).';
  @override
  String get select => 'Seç';
  @override
  String get selected => 'seçili';
  @override
  String get notSelected => 'seçili değil';
  @override
  String selectedCount(int n) => '$n seçili';
  @override
  String get selectAll => 'Tümünü seç';
  @override
  String get endSelection => 'Seçimi bitir (Esc)';
  @override
  String get favorite => 'Favori';
  @override
  String get selectionMarkedWatched => 'İzlendi olarak işaretlendi';
  @override
  String get selectionMarkedUnwatched => 'İzlenmedi olarak işaretlendi';
  @override
  String get selectionAddedToFavorites => 'Favorilere eklendi';
  @override
  String get selectionDownloading => 'İndirmeler başladı';
  @override
  String get recentSearches => 'Son aramalar';
  @override
  String get clearHistory => 'Geçmişi temizle';
  @override
  String get filterAll => 'Tümü';
  @override
  String get people => 'Kişiler';
  @override
  String get onlyUnwatched => 'Yalnızca izlenmeyenler';
  @override
  String removeSearch(String term) => '“$term” kaldır';
  @override
  String get recapOnlyYou => 'Yalnızca senin profilin sayılır';
  @override
  String recapMarkedNote(int n) => '$n başlık yalnızca izlendi olarak işaretlendi (sayılmadı)';
  @override
  String get watched => 'İzlendi';
  @override
  String get chapters => 'Bölümler';
  @override
  String get chaptersKey => 'Bölümler (C)';
  @override
  String chapterN(int n) => 'Bölüm $n';
  @override
  String get screenshotSaved => 'Ekran görüntüsü Resimler’e kaydedildi';
  @override
  String get screenshotFailed => 'Ekran görüntüsü alınamadı';
  @override
  String get statsTitle => 'Oynatma bilgisi (I)';
  @override
  String get statsPlayback => 'Oynatma';
  @override
  String get statsDecoder => 'Kod çözme';
  @override
  String get statsSoftware => 'Yazılım (CPU)';
  @override
  String get statsHardware => 'Donanım';
  @override
  String get statsBuffer => 'Arabellek';
  @override
  String get statsDropped => 'Atlanan kareler';
  @override
  String get statsDirectPlay => 'Doğrudan (orijinal dosya)';
  @override
  String get statsTranscoding => 'Sunucu tarafından dönüştürülüyor';
  @override
  String get statsLocalFile => 'İndirilmiş dosya';
  @override
  String episodesWatchedOf(int n, int total) => '$total bölümden $n tanesi izlendi';
  @override
  String downloadedOf(int n, int total) => '$total bölümden $n tanesi indirildi';
  @override
  String get markSeasonWatched => 'Sezonu izlendi işaretle';
  @override
  String get markSeasonUnwatched => 'Sezonu izlenmedi işaretle';
  @override
  String markSeasonWatchedQuestion(String season) => '“$season” izlendi olarak işaretlensin mi?';
  @override
  String markSeasonWatchedDetail(int n) =>
      '$n bölümün tümü izlendi olarak işaretlenecek. Yıllık özetin bunları izleme süresi olarak saymaz.';
  @override
  String seasonMarkedWatched(String season) => '$season izlendi olarak işaretlendi';
  @override
  String seasonMarkedUnwatched(String season) => '$season izlenmedi olarak işaretlendi';
  @override
  String get bannerTrailers => 'Afişte fragmanlar';
  @override
  String get bannerTrailersHint => 'Birkaç saniye sonra fragmanı sessiz oynatır (varsa).';
  @override
  String get screensaver => 'Ekran koruyucu';
  @override
  String get screensaverHint =>
      'Bir süre işlem yapılmazsa film ve dizilerinden görselleri saatle gösterir. Oynatma sırasında asla.';
  @override
  String get showNow => 'Şimdi göster';
  @override
  String afterMinutes(int m) => '$m dk sonra';
  @override
  String get seasonalThemes => 'Mevsimsel dokunuşlar';
  @override
  String get seasonalThemesHint =>
      'Cadılar Bayramı, Noel, Yılbaşı ve Sevgililer Günü için: ana sayfada uygun bir sıra ve küçük efektler.';
  @override
  String get episodeImages => '“İzlemeye devam et”te bölüm görselleri';
  @override
  String get episodeImagesHint => 'Kapalı: bölüm karesi yerine dizi görseli gösterilir.';
  @override
  String get personalize => 'Kişiselleştir';
  @override
  String get appName => 'Uygulama adı';
  @override
  String get appNameHint => 'Başlık çubuğunda, pencere başlığında ve girişte gösterilir.';
  @override
  String get logo => 'Logo';
  @override
  String get logoHint => 'Bir görsel (PNG, JPG …) – adın önünde ve görev çubuğu simgesi olarak gösterilir.';
  @override
  String get sounds => 'Sesler';
  @override
  String get soundsHint => '“Şaşırt beni” ve film testinde tık sesleri ve müzikler.';
  @override
  String get theme => 'Tema';
  @override
  String get themeHint => 'Tüm uygulamanın renkleri – anında değişir.';
  @override
  String themeName(String id) => switch (id) {
    'midnight' => 'Gece yarısı',
    'oled' => 'OLED Siyahı',
    'cinema' => 'Sinema Kırmızısı',
    'frost' => 'Kuzey Ayazı',
    'sunset' => 'Gün batımı',
    'synthwave' => 'Synthwave',
    'emerald' => 'Zümrüt',
    'noir' => 'Siyah ve Altın',
    _ => id,
  };
  @override
  String get images => 'Görseller';
  @override
  String get loading => 'Yükleniyor …';
  @override
  String get chooseImage => 'Görsel seç …';
  @override
  String get removeLogo => 'Logoyu kaldır';
  @override
  String get imageUnreadable => 'Bu görsel okunamadı.';
  @override
  String get resetToJellyflex => 'Jellyflex’e sıfırla';
  @override
  String get account => 'Hesap';
  @override
  String get signOut => 'Çıkış yap';
  @override
  String basedOn(String name, String version) => '$name · Jellyflex $version tabanlı';

  // --- Detailseite ---
  @override
  String contentCouldNotLoad(Object e) => 'İçerik yüklenemedi.\n$e';
  @override
  String get moreEpisodes => 'Diğer bölümler';
  @override
  String seasonN(int n) => '$n. Sezon';
  @override
  String episodeN(int n) => '$n. Bölüm';
  @override
  String seasonsCount(int n) => '$n sezon';
  @override
  String get fromStart => 'Baştan';
  @override
  String versionLabel(String v) => 'Sürüm: $v';
  @override
  String get markUnplayed => 'İzlenmedi işaretle';
  @override
  String get markPlayed => 'İzlendi işaretle';
  @override
  String get removeFavorite => 'Favorilerden çıkar';
  @override
  String get addFavorite => 'Favorilere ekle';
  @override
  String get mediaInfoTooltip => 'Medya bilgisi (çözünürlük, ses, altyazı …)';
  @override
  String get downloadOffline => 'İndir (çevrimdışı izle)';
  @override
  String get downloadedClickToDelete => 'İndirildi – silmek için tıkla';
  @override
  String get pauseDownload => 'İndirmeyi duraklat';
  @override
  String get resumeDownload => 'İndirmeye devam et';
  @override
  String get seasonAlreadyDownloaded => 'Bu sezonun tüm bölümleri zaten indirildi';
  @override
  String episodesDownloading(int n) => '$n bölüm indiriliyor';
  @override
  String get downloadSeason => 'Sezonu indir';
  @override
  String get thisEpisode => 'Bu bölüm';
  @override
  String get cast => 'Oyuncular';
  @override
  String get youMightLike => 'Bunlar da hoşuna gidebilir';
  @override
  String get inThisCollection => 'Bu koleksiyonda';
  @override
  String get mediaInfo => 'Medya bilgisi';
  @override
  String get format => 'Biçim';
  @override
  String get totalBitrate => 'Toplam bit hızı';
  @override
  String get runtime => 'Süre';
  @override
  String get fileName => 'Dosya adı';
  @override
  String get video => 'Video';
  @override
  String get resolution => 'Çözünürlük';
  @override
  String get codec => 'Kodek';
  @override
  String get dynamicRange => 'Dinamik aralık';
  @override
  String get bitDepth => 'Bit derinliği';
  @override
  String get frameRate => 'Kare hızı';
  @override
  String get bitrate => 'Bit hızı';
  @override
  String audioCount(int n) => 'Ses ($n)';
  @override
  String subtitlesCount(int n) => 'Altyazılar ($n)';
  @override
  String get defaultTrack => 'Varsayılan';
  @override
  String get forced => 'Zorunlu';

  // --- Kontextmenü ---
  @override
  String get playFromStart => 'Baştan oynat';
  @override
  String get goToSeries => 'Diziye git';
  @override
  String get alreadyWatched => 'Zaten izlendi';
  @override
  String get forget => 'İzlemeye devam et’ten kaldır';
  @override
  String get download => 'İndir';
  @override
  String get deleteDownload => 'İndirmeyi sil';
  @override
  String markedWatched(String name) => '“$name” izlendi olarak işaretlendi';
  @override
  String markedUnwatched(String name) => '“$name” izlenmedi olarak işaretlendi';
  @override
  String get addedToFavorites => 'Favorilere eklendi';
  @override
  String get removedFromFavorites => 'Favorilerden çıkarıldı';
  @override
  String downloadStarted(String name) => 'İndirme başladı: $name';
  @override
  String get downloadDeleted => 'İndirme silindi';
  @override
  String get removedFromContinue => '“İzlemeye devam et”ten kaldırıldı';

  // --- Downloads ---
  @override
  String get downloads => 'İndirilenler';
  @override
  String get savedForOffline => 'Çevrimdışı izlemek için bu bilgisayara kaydedildi';
  @override
  String downloadsSummary(int count, String size) => '$count başlık · $size kullanılıyor';
  @override
  String get openFolder => 'Klasörü aç';
  @override
  String get noDownloadsYet => 'Henüz indirme yok.';
  @override
  String get noDownloadsHint => 'Bir ayrıntı sayfasında ya da sağ tıklayarak “İndir”e tıkla.';
  @override
  String get downloading => 'İndiriliyor';
  @override
  String get readyOffline => 'Çevrimdışı izlemeye hazır';
  @override
  String get deleteDownloadQuestion => 'İndirme silinsin mi?';
  @override
  String deleteDownloadText(String name) => '“$name” bu bilgisayardan silinecek. Sunucudaki her şey yerinde kalır.';
  @override
  String get waiting => 'Bekliyor …';
  @override
  String receivedOf(String received, String total) => '$received / $total';
  @override
  String get starting => 'Başlıyor …';
  @override
  String paused(String? reason) => 'Duraklatıldı${reason != null ? ' – $reason' : ''}';
  @override
  String failed(String? reason) => 'Başarısız: ${reason ?? 'bilinmiyor'}';
  @override
  String get done => 'Bitti';
  @override
  String get cancelAndDelete => 'İptal et ve sil';

  // --- Anmeldung ---
  @override
  String get noServerAtAddress => 'Bu adreste Jellyfin sunucusu bulunamadı.';
  @override
  String get wrongCredentials => 'Kullanıcı adı ya da parola yanlış.';
  @override
  String signInFailedCode(String code) => 'Giriş başarısız ($code).';
  @override
  String signInFailed(Object e) => 'Giriş başarısız: $e';
  @override
  String get quickConnectExpired => 'Quick Connect süresi doldu. Lütfen tekrar dene.';
  @override
  String get quickConnectFailed => 'Quick Connect başlatılamadı.';
  @override
  String get tagline => 'Sinema salonun. Bilgisayarında.';
  @override
  String get whoIsWatching => 'Kim izliyor?';
  @override
  String get addAccount => 'Hesap ekle';
  @override
  String get toProfileSelection => 'Profillere dön';
  @override
  String get connectServer => 'Sunucuya bağlan';
  @override
  String get enterServerAddress => 'Jellyfin sunucunun adresini gir.';
  @override
  String get serverAddress => 'Sunucu adresi';
  @override
  String get connect => 'Bağlan';
  @override
  String get quickConnectHint => 'Oturum açık bir cihazda Jellyfin’i aç → Profil → Quick Connect ve bu kodu gir:';
  @override
  String get otherServer => 'Başka sunucu';
  @override
  String get certificateInvalid => 'Sunucunun güvenlik sertifikası geçersiz. Güvenliğin için Jellyflex bağlanmıyor.';
  @override
  String get unencryptedWarning => 'Şifresiz bağlantı: parolan ve verilerin ağda okunabilir. Yalnızca evde kullan.';
  @override
  String get signIn => 'Giriş yap';
  @override
  String get username => 'Kullanıcı adı';
  @override
  String get password => 'Parola';
  @override
  String get signInWithQuickConnect => 'Quick Connect ile giriş yap';
  @override
  String get removeAccount => 'Hesabı kaldır';

  // --- Bibliothek ---
  @override
  String get sortTitle => 'Başlık';
  @override
  String get sortAdded => 'Son eklenenler';
  @override
  String get sortReleased => 'Çıkış tarihi';
  @override
  String get sortRating => 'Puan';
  @override
  String get sortRandom => 'Rastgele';
  @override
  String get unwatched => 'İzlenmeyenler';
  @override
  String get favorites => 'Favoriler';
  @override
  String get genre => 'Tür';
  @override
  String get allGenres => 'Tüm türler';
  @override
  String get decade => 'On yıl';
  @override
  String decadeLabel(int d) => '${d >= 2000 ? d : d % 100}’ler';
  @override
  String get allYears => 'Tüm yıllar';
  @override
  String get resetFilters => 'Filtreleri sıfırla';
  @override
  String titlesCount(int n) => '$n başlık';
  @override
  String libraryCouldNotLoad(Object e) => 'Kitaplık yüklenemedi.\n$e';
  @override
  String get noTitlesMatch => 'Bu filtrelere uyan başlık yok.';
  @override
  String homeCouldNotLoad(Object e) => 'Ana sayfa yüklenemedi.\n$e';
  @override
  String get viewDownloads => 'İndirilenleri göster';
  @override
  String get libraries => 'Kitaplıklar';
  @override
  String get movieQuiz => 'Film testi';
  @override
  String get surpriseMe => 'Şaşırt beni';
  @override
  String get searchCtrlF => _isMac ? 'Ara (⌘F)' : 'Ara (Ctrl+F)';
  @override
  String get profile => 'Profil';
  @override
  String get switchUser => 'Kullanıcı değiştir';
  @override
  String get yearlyRecap => 'Yılın özeti';
  @override
  String get soundOn => 'Ses açık';
  @override
  String get soundOff => 'Ses kapalı';
  @override
  String get watch => 'İzle';
  @override
  String get moreInfo => 'Daha fazla bilgi';

  // --- Suche ---
  @override
  String get searchHint => 'Başlık, bölüm ya da oyuncu ara …';
  @override
  String get clear => 'Temizle';
  @override
  String searchFailed(Object e) => 'Arama başarısız: $e';
  @override
  String get whatDoYouFeelLike => 'Canın ne izlemek istiyor?';
  @override
  String nothingFoundFor(String term) => '“$term” için bir şey bulunamadı.';
  @override
  String get movies => 'Filmler';
  @override
  String get shows => 'Diziler';
  @override
  String get episodes => 'Bölümler';

  // --- Personen ---
  @override
  String personCouldNotLoad(Object e) => 'Kişi yüklenemedi.\n$e';
  @override
  String get noTitlesWithPerson => 'Sunucunda bu kişinin olduğu film ya da dizi yok.';
  @override
  String get onYourServer => 'Sunucunda';
  @override
  String allCount(int n) => 'Tümü ($n)';
  @override
  String moviesCount(int n) => 'Filmler ($n)';
  @override
  String showsCount(int n) => 'Diziler ($n)';
  @override
  String get guestAppearances => 'Tek bölümlük görünmeler';
  @override
  String bornOn(String date, int? age, String? place) =>
      'Doğum: $date${age != null ? ' ($age yaşında)' : ''}${place != null ? ', $place' : ''}';
  @override
  String bornIn(String place) => 'Doğum yeri: $place';
  @override
  String diedOn(String date, int? age) => 'Ölüm: $date${age != null ? ' ($age yaşında)' : ''}';
  @override
  String movieCount(int n) => '$n film';
  @override
  String showCount(int n) => '$n dizi';
  @override
  String episodeCount(int n) => '$n bölüm';
  @override
  String onYourServerCounts(String counts) => 'Sunucunda $counts';
  @override
  String get showLess => 'Daha az göster';
  @override
  String get showMore => 'Daha fazla göster';

  // --- Saisonales ---
  @override
  String get halloween => 'Korku mevsimi';
  @override
  String get christmas => 'Noel zamanı';
  @override
  String get newYearsEve => 'Yılbaşı';
  @override
  String get valentinesDay => 'Sevgililer Günü';

  // --- Roulette ---
  @override
  String get nothingFoundLoosen => 'Bir şey bulunamadı – filtreleri biraz gevşet.';
  @override
  String get letChanceDecide => 'Bu akşam ne izleneceğine şans karar versin.';
  @override
  String get spinning => 'Dönüyor …';
  @override
  String get spin => 'Çevir';
  @override
  String get spinAgain => 'Tekrar çevir';
  @override
  String get anyTime => 'Süre fark etmez';
  @override
  String get both => 'İkisi de';
  @override
  String get unwatchedOnly => 'Yalnızca izlenmeyenler';
  @override
  String get all => 'Tümü';
  @override
  String genreLabel(String g) => 'Tür: $g';
  @override
  String finishedBy(String time) => 'Bitiş: $time';
  @override
  String get startSeries => 'Diziye başla';

  // --- Quiz ---
  @override
  String get quizNeedsTitles => 'Test için arka plan görseli olan en az 4 film ya da dizi gerekir.';
  @override
  String roundOf(int n, int total) => 'Tur $n / $total';
  @override
  String points(int n) => '$n puan';
  @override
  String correctPlus(int n) => 'Doğru! +$n';
  @override
  String get notQuite => 'Tam değil';
  @override
  String get result => 'Sonuç';
  @override
  String get next => 'Sonraki';
  @override
  String get verdictPro => 'Film ustası! 🍿';
  @override
  String get verdictStrong => 'Harika iş! 🎬';
  @override
  String get verdictNotBad => 'Fena değil! 🎞️';
  @override
  String get verdictMore => 'Gelişmeye açık … 📼';
  @override
  String get newRecord => 'Yeni rekor!';
  @override
  String correctOf(int correct, int rounds, int record) => '$rounds sorudan $correct doğru  ·  Rekor: $record';
  @override
  String get playAgain => 'Tekrar oyna';

  // --- Jahresrückblick ---
  @override
  String recapFileName(String app, int year) => '$app Yılın özeti $year';
  @override
  String savedToPictures(String name) => 'Resimler’e kaydedildi: $name';
  @override
  String get show => 'Göster';
  @override
  String get imageNotSaved => 'Görsel kaydedilemedi.';
  @override
  String get calculatingYear => 'Yılın hesaplanıyor …';
  @override
  String get saveAsImage => 'Görsel olarak kaydet';
  @override
  String get watchAgain => 'Tekrar izle';
  @override
  String yourYear(int y) => 'Senin $y yılın';
  @override
  String get nothingThisYear => 'Bu yıl henüz hiçbir şeyi bitirmedin.';
  @override
  String get letsLookBack => 'Hadi geriye bakalım.';
  @override
  String get youWatched => 'İzlediğin süre';
  @override
  String get hoursSuffix => ' saat';
  @override
  String get thatWas => 'Bu da';
  @override
  String get movieWord => 'film';
  @override
  String get moviesWord => 'film';
  @override
  String get episodeWord => 'bölüm';
  @override
  String get episodesWord => 'bölüm';
  @override
  String get showWord => 'dizi';
  @override
  String get showsWord => 'dizi';
  @override
  String longestMovie(String name, String runtime) => 'En uzun film: $name ($runtime)';
  @override
  String get favoriteGenre => 'En sevdiğin tür';
  @override
  String get showOfTheYear => 'Yılın dizin';
  @override
  String episodesWatched(int n) => '$n bölüm izlendi';
  @override
  String get seenMostOften => 'En sık görülen';
  @override
  String inTitles(int n) => '$n başlıkta';
  @override
  String get biggestMarathon => 'En büyük maratonun';
  @override
  String inOneDay(String duration) => 'Bir günde $duration 🍿';
  @override
  String favoriteHourText(int hour) => 'En çok ${timeOfDay(hour)} civarında izliyorsun.';
  @override
  String daysInARow(String days) => 'Bu, art arda $days gün demek.';
  @override
  String asLongAsTitanic(String times) => '$times× “Titanic” kadar uzun.';
  @override
  String get nightOwl => 'Gece kuşu 🦉';
  @override
  String get earlyBird => 'Erkenci kuş ☀️';
  @override
  String get eveningWatcher => 'İş sonrası izleyicisi 🛋️';
  @override
  String get afternoonWatcher => 'Öğleden sonra izleyicisi ☕';
  @override
  String recapTitle(String app, int year) => '$app · Yılın özeti $year';
  @override
  String get hoursWord => 'Saat';
  @override
  String get moviesTitle => 'Filmler';
  @override
  String get episodesTitle => 'Bölümler';
  @override
  String get showsTitle => 'Diziler';
  @override
  String get favoriteGenreShort => 'Favori tür';
  @override
  String get showOfTheYearShort => 'Yılın dizisi';
  @override
  String get favoriteTime => 'Favori saat';

  // --- Player ---
  @override
  String get sleepTimer => 'Uyku zamanlayıcısı';
  @override
  String get endOfThisEpisode => 'Bu bölümün sonunda';
  @override
  String get endOfThisMovie => 'Filmin sonunda';
  @override
  String inMinutes(int m) => '$m dakika içinde';
  @override
  String get atTheEnd => 'sonunda';
  @override
  String seconds(int sec) => '$sec sn';
  @override
  String get noPlayableFile => 'Oynatılabilir dosya bulunamadı.';
  @override
  String get noTranscodeFromServer => 'Sunucu dönüştürülmüş bir sürüm sağlamadı.';
  @override
  String fileCouldNotLoad(String message) => 'Dosya yüklenemedi.\n$message';
  @override
  String get playbackNotPossible => 'Oynatma mümkün değil';
  @override
  String get bigWindow => 'Büyük pencere (P)';
  @override
  String get backEsc => 'Geri (Esc)';
  @override
  String get pauseSpace => 'Duraklat (Boşluk)';
  @override
  String get playSpace => 'Oynat (Boşluk)';
  @override
  String get rewind10 => '10 sn geri (←)';
  @override
  String get forward10 => '10 sn ileri (→)';
  @override
  String get audioAndSubtitles => 'Ses ve altyazılar';
  @override
  String get playbackOptions => 'Oynatma: hız, kalite, eşitleme';
  @override
  String get miniPlayer => 'Mini oynatıcı (P)';
  @override
  String get exitFullscreen => 'Tam ekrandan çık (F)';
  @override
  String get fullscreen => 'Tam ekran (F)';
  @override
  String get mute => 'Sesi kapat (M)';
  @override
  String get audio => 'Ses';
  @override
  String get subtitles => 'Altyazılar';
  @override
  String get noAudioTracks => 'Ses parçası bulunamadı';
  @override
  String get noSubtitles => 'Altyazı yok';
  @override
  String get file => 'Dosya';
  @override
  String get goodNight => 'İyi geceler';
  @override
  String get sleepTimerPaused => 'Uyku zamanlayıcısı oynatmayı duraklattı.';
  @override
  String get keepWatching => 'İzlemeye devam et';
  @override
  String get closePlayer => 'Oynatıcıyı kapat';
  @override
  String get skipIntro => 'Girişi atla';
  @override
  String get skipRecap => 'Özeti atla';
  @override
  String get skipPreview => 'Önizlemeyi atla';
  @override
  String get skipCommercial => 'Reklamı atla';
  @override
  String get skip => 'Atla';
  @override
  String get nextEpisodeCaps => 'SONRAKİ BÖLÜM';
  @override
  String get watchCredits => 'Jeneriği izle';
  @override
  String get watchNow => 'Şimdi izle';
  @override
  String get speed => 'Hız';
  @override
  String get sync => 'Eşitleme';
  @override
  String get sound => 'Ses';
  @override
  String get withoutConversion => 'dönüştürmesiz';
  @override
  String get reset => 'Sıfırla';

  // --- Fehler & Verbindung ---
  @override
  String get notAJellyfinServer => 'Jellyfin sunucusu değil';
  @override
  String get serverNotReachable => 'Sunucuya ulaşılamıyor';
  @override
  String get otherAccountSignedIn => 'Başka bir hesap oturum açmış';
  @override
  String get noFileFound => 'Dosya bulunamadı';
  @override
  String connectionInterrupted(String received, String total) => 'Bağlantı kesildi ($received / $total)';
  @override
  String get unexpectedServerAddress => 'Sunucu kendisine ait olmayan bir adres gönderdi – engellendi.';
  @override
  String get noConnectionToServer => 'Sunucuyla bağlantı yok';
  @override
  String get serverOffline => 'Sunucuya ulaşılamıyor';
  @override
  String get offlineHint => 'İndirdiklerin çalışmaya devam ediyor.';
  @override
  String get backOnline => 'Sunucuya yeniden bağlanıldı';
  @override
  String serverError(int? code) => 'Sunucu hatası $code';
  @override
  String get encryptionFailed => 'Şifreleme başarısız';

  // --- Listen, Startseite, Tastenkürzel ---
  @override
  String get watchlist => 'İzleme listesi';
  @override
  String get myLists => 'Listelerim';
  @override
  String get addToWatchlist => 'İzleme listesine ekle';
  @override
  String get removeFromWatchlist => 'İzleme listesinden çıkar';
  @override
  String addedToWatchlist(String name) => '“$name” izleme listende';
  @override
  String removedFromWatchlist(String name) => '“$name” izleme listenden çıkarıldı';
  @override
  String get addToList => 'Listeye ekle';
  @override
  String get addToListMenu => 'Listeye ekle …';
  @override
  String addedToList(String list) => '“$list” listesine eklendi';
  @override
  String get newList => 'Yeni liste';
  @override
  String get listNameHint => 'Ad, ör. “Film gecesi”';
  @override
  String get listsHint => 'Jellyfin sunucundaki özel listeler – tüm cihazlarında kullanılabilir.';
  @override
  String get noListsYet => 'Henüz liste yok. Bir başlıktaki yer imini ya da “Listeye ekle”yi kullan.';
  @override
  String get listEmpty => 'Bu liste boş.';
  @override
  String get deleteList => 'Listeyi sil';
  @override
  String deleteListQuestion(String name) => '“$name” silinsin mi?';
  @override
  String get deleteListText => 'Liste sunucunda silinir. Başlıkların kendisi kalır.';
  @override
  String removeFromList(String name) => '“$name” listeden çıkar';
  @override
  String get homeRows => 'Ana sayfa sıraları';
  @override
  String get homeRowsHint => 'Sıralamak için sürükle, gerekmeyenleri kapat. Değişiklikler hemen uygulanır.';
  @override
  String get homeRowsSettingsHint => 'Ana sayfadaki sıraların düzeni ve görünürlüğü.';
  @override
  String get customize => 'Özelleştir';
  @override
  String get moveUp => 'Yukarı taşı';
  @override
  String get moveDown => 'Aşağı taşı';
  @override
  String get resetToDefault => 'Varsayılana dön';
  @override
  String homeRowName(String id) => switch (id) {
    'seasonal' => 'Mevsim sırası',
    'latest' => 'Kitaplıklarındaki yenilikler',
    'genres' => 'Tür sıraları',
    _ => super.homeRowName(id),
  };
  @override
  String get shortcuts => 'Klavye kısayolları';
  @override
  String get shortcutsEverywhere => 'Her yerde';
  @override
  String get shortcutsPlayer => 'Oynatıcı';
  @override
  String get shortcutsController => 'Oyun kumandası';
  @override
  String get shortcutMoveFocus => 'Seçimi taşı';
  @override
  String get shortcutOpen => 'Aç / seç';
  @override
  String get shortcutSeek => '10 sn geri / ileri';
  @override
  String get shortcutVolume => 'Ses düzeyi';
  @override
  String get shortcutScreenshot => 'Ekran görüntüsü';
  @override
  String get shortcutMenu => 'Menü (sağ tık gibi)';
  @override
  String get keySpace => 'Boşluk';
  @override
  String get ok => 'Tamam';
  @override
  String get standard => 'Varsayılan';
  @override
  String notEnoughSpace(String needed, String free) => 'Yaklaşık $needed gerekiyor, ancak yalnızca $free boş.';
  @override
  String get notEnoughSpaceTitle => 'Yeterli alan yok';
  @override
  String get diskAlmostFull => 'Sürücü neredeyse dolu – indirme durduruldu';
  @override
  String get downloadAnyway => 'Yine de indir';
  @override
  String get downloadWaitsForWifi => 'Ölçülü bir bağlantıdasın – Wi-Fi veya LAN’a geçince indirme başlar.';
  @override
  String get chooseFolder => 'Klasör seç';
  @override
  String get folderNotAllowed => _isMac
      ? 'İndirmeler sistem klasörlerine (System, Uygulamalar, Library) kaydedilemez. Lütfen başka bir klasör seç.'
      : 'İndirmeler sistem klasörlerine (Windows, Program Files, AppData) kaydedilemez. Lütfen başka bir klasör seç.';
  @override
  String folderNotWritable(String error) => 'Jellyflex bu klasöre yazamıyor ($error).';
  @override
  String get folderProblem => 'Klasör kullanılamıyor';
  @override
  String get downloadFolderQuestion => 'İndirmeler nereye kaydedilsin?';
  @override
  String get downloadFolderQuestionText =>
      'Jellyflex indirmeleri bu klasöre kaydeder. Ayarlardan istediğin zaman değiştirebilirsin.';
  @override
  String freeSpace(String size) => '$size boş';
  @override
  String get changeFolder => 'Klasörü değiştir…';
  @override
  String get useThisFolder => 'Bu klasörü kullan';
  @override
  String get downloadOptionsTitle => 'İndir';
  @override
  String downloadEpisodesTitle(int count) => '$count bölümü indir';
  @override
  String get downloadOriginalHint =>
      'Tüm ses parçaları ve altyazılarla orijinal dosya – en iyi kalite, en büyük dosya.';
  @override
  String get downloadConvertedHint =>
      'Sunucu daha küçük bir sürüm oluşturur: tek ses parçası, altyazılar ayrı dosyalar. Orijinalden uzun sürebilir.';
  @override
  String downloadSizeAbout(String size) => 'Yaklaşık $size';
  @override
  String get downloadDontAskAgain => 'Bir daha sorma';
  @override
  String get downloadDontAskAgainHint => 'Bundan sonra bu kalite kullanılır – ayarlardan değiştirilebilir.';
  @override
  String get downloadFolder => 'İndirme klasörü';
  @override
  String downloadFolderHint(String path) => '$path · Mevcut indirmeler oldukları yerde kalır.';
  @override
  String get unmeteredOnly => 'Yalnızca Wi-Fi veya LAN’da';
  @override
  String get unmeteredOnlyHint => _isMac
      ? 'Telefon erişim noktası veya Düşük Veri Modu’ndaki ağlar üzerinden indirme yapılmaz.'
      : 'Mobil veri, telefon erişim noktası veya Windows’un ölçülü olarak işaretlediği ağlar üzerinden indirme yapılmaz.';
  @override
  String get speedLimit => 'Hız sınırı';
  @override
  String get speedLimitHint => 'İndirmeler internetinin geri kalanını yavaşlatmasın diye.';
  @override
  String get unlimited => 'Sınırsız';
  @override
  String get downloadQuality => 'İndirme kalitesi';
  @override
  String get downloadQualityHint => 'Küçük sürümler yer kazandırır – sunucu onları dönüştürür.';
  @override
  String get askBeforeDownload => 'Her indirmeden önce sor';
  @override
  String get askBeforeDownloadHint => 'Her seferinde kalite, ses ve altyazı seç.';
  @override
  String get smartDownloads => 'Akıllı indirmeler';
  @override
  String get smartDownloadsHint => 'İzlenen bölümleri siler ve sonrakileri kendiliğinden indirir.';
  @override
  String get smartEpisodes => 'Hazır tutulacak bölümler';
  @override
  String get smartEpisodesHint => 'Dizi başına indirilmiş kalacak izlenmemiş bölüm sayısı.';
  @override
  String get smartMaxSpace => 'Akıllı indirmeler için alan';
  @override
  String get smartMaxSpaceHint => 'Akıllı indirmeler bundan fazlasını asla kullanmaz.';
  @override
  String get noLimit => 'Sınır yok';
  @override
  String get downloadStorage => 'Depolama';
  @override
  String downloadStorageHint(String used, String free) => 'İndirmeler $used kullanıyor · sürücüde $free boş';
  @override
  String get deleteWatchedDownloads => 'İzlenenleri sil';
  @override
  String deleteWatchedQuestion(int count) => 'İzlenen indirmeler silinsin mi ($count)?';
  @override
  String get deleteWatchedText => 'Bu bilgisayardan silinecekler. Sunucudaki her şey yerinde kalır.';
  @override
  String watchedDownloadsDeleted(int count) => 'İzlenen indirmeler silindi ($count)';
  @override
  String get noWatchedDownloads => 'İzlenmiş indirme yok';
  @override
  String get waitingForWifi => 'Wi-Fi veya LAN bekleniyor';
  @override
  String get waitingForWifiHint =>
      'Ölçülü bir bağlantıdasın (mobil veri veya erişim noktası). İndirmeler kendiliğinden devam eder.';
  @override
  String get allowMetered => 'Yine de izin ver';
  @override
  String get smartBadge => 'Akıllı';
  @override
  String get cancelDownload => 'İndirmeyi iptal et';
  @override
  String get cancelDownloadQuestion => 'İndirme iptal edilsin mi?';
  @override
  String cancelDownloadText(String name) => '“$name” için şimdiye kadar indirilenler silinecek.';
  @override
  String get cancelDownloads => 'İndirmeleri iptal et';
  @override
  String downloadsCancelled(int count) => 'İndirmeler iptal edildi ($count)';
  @override
  String get keepDownloading => 'İndirmeye devam et';
  @override
  String get scenes => 'Sahneler';
  @override
  String get updateVerifiedHint =>
      'Jellyflex yükleyiciyi indirir ve önce dijital imzasını kontrol eder – değiştirilmiş veya bozuk bir dosya asla başlatılmaz.';
  @override
  String get updateVerifyFailed => 'Güncelleme indirilemedi veya imzası yanlış – hiçbir şey yüklenmedi.';
  @override
  String get updateReleasePage => 'Sürüm sayfası';
  @override
  String get profileLocked => 'Kilitli – devam etmek için PIN’ini gir';
  @override
  String get unlock => 'Kilidi aç';
  @override
  String get switchProfile => 'Profil değiştir';
  @override
  String get pinLock => 'Uzaktayken kilitle';
  @override
  String get pinLockHint => 'Bu süre boyunca giriş olmazsa PIN’i yeniden ister (video oynarken değil).';
  @override
  String get update => 'Güncelle';
  @override
  String updateToVersion(String version) => '$version sürümüne güncelleniyor';
  @override
  String get updateDownloading => 'Güncelleme indiriliyor ve kontrol ediliyor …';
  @override
  String get updateInstalling => 'Yükleniyor – Jellyflex kendiliğinden yeniden başlar.';
  @override
  String updateReady(String version) => '$version sürümü hazır – Jellyflex kapatılınca yüklenecek.';
  @override
  String get restartNow => 'Şimdi yeniden başlat';
  @override
  String get autoUpdate => 'Güncellemeleri otomatik yükle';
  @override
  String get autoUpdateHint => 'Yeni sürümler arka planda indirilir, kontrol edilir ve Jellyflex kapatılınca yüklenir.';
  @override
  String whatsNewTitle(String version) => 'Jellyflex $version sürümündeki yenilikler';
  @override
  String versionLabelShort(String version) => 'Sürüm $version';
  @override
  String get allReleaseNotes => 'Tüm sürüm notları';
  @override
  String get gotIt => 'Anladım';

  // --- Ersteinrichtung und Heimnetz-Suche ---
  @override
  String get welcomeTitle => 'Jellyflex’e hoş geldin';
  @override
  String get welcomeHint => 'Birkaç kısa seçim, sonra başlıyoruz. Her şeyi daha sonra ayarlardan değiştirebilirsin.';
  @override
  String get setupLookTitle => 'Jellyflex nasıl görünsün?';
  @override
  String get setupLookHint => 'Denemek için tıkla – değişiklik hemen görünür.';
  @override
  String get setupOptionsTitle => 'Birkaç soru daha';
  @override
  String get setupOptionsHint => 'Beğendiklerini aç – hiçbiri zorunlu değil.';
  @override
  String get setupLater => 'Sonra ayarla';
  @override
  String get setupFinish => 'Başlayalım';
  @override
  String stepOf(int step, int count) => 'Adım $step / $count';
  @override
  String get searchNetwork => 'Ev ağında ara';
  @override
  String get searchingNetwork => 'Ev ağında aranıyor …';
  @override
  String get searchNetworkHint =>
      'Yalnızca tıkladığında: ev ağında bir kez Jellyfin sunucusu olup olmadığını sorar. İnternete hiçbir şey gitmez.';
  @override
  String get noServerFound => 'Hiçbir sunucu yanıt vermedi. Adresi kendin gir – Jellyfin kontrol panelinde yazar.';
  @override
  String get serversFound => 'Ev ağında bulundu';
  @override
  String get searchAgain => 'Tekrar ara';

  // --- Player: Lautstärke, Schaust du noch?, Zufällig ---
  @override
  String get stillWatching => 'Hâlâ izliyor musun?';
  @override
  String stillWatchingHint(String next) => 'Art arda birkaç bölüm oynatıldı. Sıradaki: $next';
  @override
  String get shuffle => 'Karışık';
  @override
  String get shufflePlay => 'Karışık oynat';
  @override
  String get nothingToShuffle => 'Burada oynatılacak bir şey yok';
  @override
  String get upNextCaps => 'SIRADAKİ';

  // --- Szenen-Vorschau auf Karten ---
  @override
  String get hoverPreview => 'Kartlarda sahne önizlemesi';
  @override
  String get hoverPreviewHint =>
      'Bir başlıkta durduğunda kart sahneler arasında geçiş yapar (sunucundan resimler, video yok).';

  // --- Lizenz ---
  @override
  String get licenseTitle => 'Lisans';
  @override
  String get licenseHint => 'Jellyflex, GNU GPL v3.0 altında özgür yazılımdır. Tüm bileşenlerin lisanslarını gösterir.';
  @override
  String get licenses => 'Lisanslar';
  @override
  String get licenseLegalese => 'GNU General Public License v3.0 altında özgür yazılım.';

  // --- Heimnetz-Suche: Hinweise ---
  @override
  String answeredBy(String ip) => 'Yanıt veren: $ip';
  @override
  String get outsideHomeNetwork => 'Bu adres ev ağının dışına işaret ediyor – yalnızca tanıyorsan seç.';
  @override
  String get onlyKnownServers => 'Ağdaki her cihaz yanıt verebilir – yalnızca tanıdığın sunucuları seç.';

  // --- Fensterleiste im Vollbild ---
  @override
  String get leaveFullscreen => 'Tam ekrandan çık (F11)';

  // --- Player: Bildausschnitt (Zoom) ---
  @override
  String get zoomTooltip => 'Görüntü boyutu (Z)';
  @override
  String get zoomFit => 'Sığdır – tüm görüntü';
  @override
  String get zoomFill => 'Doldur – siyah şerit yok';
  @override
  String zoomPercent(int percent) => 'Yakınlaştırma %$percent';
  @override
  String get shortcutZoom => 'Görüntüyü sığdır / doldur';
  @override
  String get shortcutZoomWheel => 'Serbest yakınlaştırma';
  @override
  String get keyCtrlWheel => 'Ctrl + fare tekerleği';
}
