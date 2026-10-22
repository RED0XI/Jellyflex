import 'dart:io';

import 'package:dio/dio.dart';

import 'images.dart';
import 'models.dart';

class ServerInfo {
  const ServerInfo({required this.url, required this.name, required this.version});

  final String url;
  final String name;
  final String version;
}

class AuthResult {
  const AuthResult({required this.token, required this.userId, required this.userName});

  final String token;
  final String userId;
  final String userName;

  factory AuthResult.fromJson(Json json) {
    final user = (json['User'] as Map).cast<String, dynamic>();
    return AuthResult(
      token: json['AccessToken'] as String,
      userId: user['Id'] as String,
      userName: (user['Name'] as String?) ?? '',
    );
  }
}

class QuickConnectState {
  const QuickConnectState({required this.secret, required this.code, required this.authenticated});

  final String secret;
  final String code;
  final bool authenticated;

  factory QuickConnectState.fromJson(Json json) => QuickConnectState(
    secret: json['Secret'] as String,
    code: (json['Code'] as String?) ?? '',
    authenticated: json['Authenticated'] == true,
  );
}

class LibraryPage {
  const LibraryPage(this.items, this.totalCount);

  final List<BaseItem> items;
  final int totalCount;
}

/// Zugriff auf die Jellyfin-REST-API.
class JellyfinApi {
  JellyfinApi({required this.baseUrl, required this.deviceId, this.token, this.userId})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    dio.options.headers['Authorization'] = authorizationHeader;
  }

  static const clientName = 'Jellyflex';
  static const clientVersion = '0.2.0';

  /// Felder, die für Karten und Detailansichten gebraucht werden.
  static const _fields = 'Overview,PrimaryImageAspectRatio,Genres,ChildCount,Taglines';
  static const _imageTypes = 'Primary,Backdrop,Thumb,Logo';

  final String baseUrl;
  final String deviceId;
  final String? token;
  final String? userId;
  final Dio dio;

  static String get deviceName {
    final host = Platform.localHostname.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '');
    return host.isEmpty ? 'Windows' : host;
  }

  String get authorizationHeader {
    final parts = [
      'Client="$clientName"',
      'Device="$deviceName"',
      'DeviceId="$deviceId"',
      'Version="$clientVersion"',
      if (token != null) 'Token="$token"',
    ];
    return 'MediaBrowser ${parts.join(', ')}';
  }

  // --- Server & Anmeldung ----------------------------------------------------

  /// Macht aus einer Eingabe wie "server.local:8096/jellyfin/" eine saubere URL.
  static String normalizeUrl(String input) {
    var url = input.trim();
    if (!url.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Prüft, ob unter der Adresse ein Jellyfin-Server antwortet.
  /// Ohne angegebenes Schema wird erst https, dann http probiert.
  static Future<ServerInfo> probe(String input) async {
    final trimmed = input.trim();
    final hasScheme = trimmed.startsWith(RegExp(r'https?://', caseSensitive: false));
    final candidates = <String>[normalizeUrl(trimmed), if (!hasScheme) normalizeUrl('http://$trimmed')];

    Object? lastError;
    for (final url in candidates) {
      try {
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 6), receiveTimeout: const Duration(seconds: 6)),
        );
        final res = await dio.get('$url/System/Info/Public');
        final data = (res.data as Map).cast<String, dynamic>();
        if (data['Id'] == null) throw const FormatException('Kein Jellyfin-Server');
        return ServerInfo(
          url: url,
          name: (data['ServerName'] as String?) ?? 'Jellyfin',
          version: (data['Version'] as String?) ?? '',
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Server nicht erreichbar');
  }

  Future<AuthResult> authenticate(String username, String password) async {
    final res = await dio.post('/Users/AuthenticateByName', data: {'Username': username, 'Pw': password});
    return AuthResult.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<bool> isQuickConnectEnabled() async {
    try {
      final res = await dio.get('/QuickConnect/Enabled');
      return res.data == true;
    } catch (_) {
      return false;
    }
  }

  Future<QuickConnectState> initiateQuickConnect() async {
    final res = await dio.post('/QuickConnect/Initiate');
    return QuickConnectState.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<QuickConnectState> checkQuickConnect(String secret) async {
    final res = await dio.get('/QuickConnect/Connect', queryParameters: {'secret': secret});
    return QuickConnectState.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<AuthResult> authenticateWithQuickConnect(String secret) async {
    final res = await dio.post('/Users/AuthenticateWithQuickConnect', data: {'Secret': secret});
    return AuthResult.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    await dio.post('/Sessions/Logout');
  }

  // --- Inhalte ---------------------------------------------------------------

  Map<String, dynamic> get _common => {
    'userId': userId,
    'fields': _fields,
    'enableImageTypes': _imageTypes,
    'imageTypeLimit': 1,
    'enableUserData': true,
  };

  Future<List<BaseItem>> _getItems(String path, Map<String, dynamic> query) async {
    final res = await dio.get(path, queryParameters: query);
    final data = res.data;
    final list = data is List ? data : ((data as Map)['Items'] as List? ?? const []);
    return list.whereType<Map>().map((e) => BaseItem(e.cast<String, dynamic>())).toList();
  }

  Future<List<BaseItem>> getUserViews() => _getItems('/UserViews', {'userId': userId});

  Future<List<BaseItem>> getResume({int limit = 20}) =>
      _getItems('/UserItems/Resume', {..._common, 'limit': limit, 'mediaTypes': 'Video'});

  Future<List<BaseItem>> getNextUp({String? seriesId, int limit = 20}) =>
      _getItems('/Shows/NextUp', {..._common, 'limit': limit, 'seriesId': ?seriesId, 'enableResumable': false});

  Future<List<BaseItem>> getLatest(String parentId, {int limit = 24}) =>
      _getItems('/Items/Latest', {..._common, 'parentId': parentId, 'limit': limit});

  /// Zufällige Filme/Serien mit Hintergrundbild für das große Banner.
  Future<List<BaseItem>> getFeatured({int limit = 8}) => _getItems('/Items', {
    ..._common,
    'includeItemTypes': 'Movie,Series',
    'recursive': true,
    'sortBy': 'Random',
    'imageTypes': 'Backdrop',
    'hasOverview': true,
    'limit': limit,
  });

  Future<List<BaseItem>> search(String term, {int limit = 60}) => _getItems('/Items', {
    ..._common,
    'searchTerm': term,
    'includeItemTypes': 'Movie,Series,Episode',
    'recursive': true,
    'limit': limit,
  });

  Future<List<BaseItem>> getFavorites({int limit = 30}) => _getItems('/Items', {
    ..._common,
    'filters': 'IsFavorite',
    'includeItemTypes': 'Movie,Series',
    'recursive': true,
    'sortBy': 'SortName',
    'limit': limit,
  });

  Future<BaseItem> getItem(String id) async {
    final res = await dio.get('/Items/$id', queryParameters: {'userId': userId});
    return BaseItem((res.data as Map).cast<String, dynamic>());
  }

  Future<LibraryPage> getLibraryPage({
    required String parentId,
    required String includeItemTypes,
    required String sortBy,
    required String sortOrder,
    int startIndex = 0,
    int limit = 100,
  }) async {
    final res = await dio.get(
      '/Items',
      queryParameters: {
        ..._common,
        'parentId': parentId,
        'includeItemTypes': includeItemTypes,
        'recursive': true,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'startIndex': startIndex,
        'limit': limit,
        'enableTotalRecordCount': true,
      },
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final items = ((data['Items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => BaseItem(e.cast<String, dynamic>()))
        .toList();
    return LibraryPage(items, (data['TotalRecordCount'] as num?)?.toInt() ?? items.length);
  }

  Future<List<BaseItem>> getSeasons(String seriesId) => _getItems('/Shows/$seriesId/Seasons', {..._common});

  Future<List<BaseItem>> getEpisodes(String seriesId, String seasonId) =>
      _getItems('/Shows/$seriesId/Episodes', {..._common, 'seasonId': seasonId});

  Future<List<BaseItem>> getSimilar(String id, {int limit = 16}) =>
      _getItems('/Items/$id/Similar', {'userId': userId, 'fields': _fields, 'limit': limit});

  Future<void> setFavorite(String id, bool favorite) => favorite
      ? dio.post('/UserFavoriteItems/$id', queryParameters: {'userId': userId})
      : dio.delete('/UserFavoriteItems/$id', queryParameters: {'userId': userId});

  Future<void> setPlayed(String id, bool played) => played
      ? dio.post('/UserPlayedItems/$id', queryParameters: {'userId': userId})
      : dio.delete('/UserPlayedItems/$id', queryParameters: {'userId': userId});

  // --- Wiedergabe ------------------------------------------------------------

  Future<PlaybackInfo> getPlaybackInfo(String id) async {
    final res = await dio.get('/Items/$id/PlaybackInfo', queryParameters: {'userId': userId});
    return PlaybackInfo((res.data as Map).cast<String, dynamic>());
  }

  /// Originaldatei ohne Umwandlung ("Direct Play") – mpv kann praktisch alles abspielen.
  String streamUrl(String itemId, {required String mediaSourceId, String? playSessionId}) {
    final query = Uri(
      queryParameters: {
        'static': 'true',
        'mediaSourceId': mediaSourceId,
        'deviceId': deviceId,
        'playSessionId': ?playSessionId,
      },
    ).query;
    return '$baseUrl/Videos/$itemId/stream?$query';
  }

  /// Externe Untertiteldatei (z. B. "Film.de.srt" neben dem Film) als Stream.
  String subtitleUrl(String itemId, String mediaSourceId, MediaStream stream) {
    final format = switch (stream.codec?.toLowerCase()) {
      'subrip' || 'srt' || null => 'srt',
      final codec => codec,
    };
    return '$baseUrl/Videos/$itemId/$mediaSourceId/Subtitles/${stream.index}/Stream.$format';
  }

  /// Intro, Abspann, Rückblick … (vom Server oder Plugins wie Intro Skipper erkannt).
  ///
  /// Zuerst die offizielle MediaSegments-API; liefert die nichts, direkt das
  /// Intro-Skipper-Plugin (`/Episode/{id}/Segments`, Zeiten in Sekunden).
  Future<List<MediaSegment>> getMediaSegments(String itemId) async {
    try {
      // Ohne Typ-Filter: Der Server erwartet hier wiederholte Parameter statt einer
      // Kommaliste – eine Kommaliste führt zu einem Fehler und damit zu "keine Intros".
      final res = await dio.get('/MediaSegments/$itemId');
      final items = ((res.data as Map)['Items'] as List?) ?? const [];
      final segments = items.whereType<Map>().map((e) => MediaSegment(e.cast<String, dynamic>())).toList();
      if (segments.isNotEmpty) return segments;
    } catch (_) {}

    try {
      final res = await dio.get('/Episode/$itemId/Segments');
      final list = res.data is List ? res.data as List : const [];
      return [
        for (final s in list.whereType<Map>())
          if (s['Suppressed'] != true && (s['End'] as num? ?? 0) > (s['Start'] as num? ?? 0))
            MediaSegment({
              'Type': switch (s['Type']) {
                'Introduction' => 'Intro',
                'Credits' => 'Outro',
                final String t => t,
                _ => 'Unknown',
              },
              'StartTicks': ((s['Start'] as num) * 10000000).round(),
              'EndTicks': ((s['End'] as num) * 10000000).round(),
            }),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Profil des angemeldeten Benutzers (für das Profilbild).
  Future<Json> getCurrentUser() async {
    final res = await dio.get('/Users/Me');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Profilbild eines Benutzers, oder `null` ohne Bild.
  String? userImageUrl(String userId, String? tag) {
    if (tag == null) return null;
    return '$baseUrl/UserImage?${Uri(queryParameters: {'userId': userId, 'tag': tag}).query}';
  }

  /// Fortschritt zurücksetzen → verschwindet aus "Weiterschauen".
  Future<void> clearResumePosition(String itemId) =>
      dio.post('/UserItems/$itemId/UserData', queryParameters: {'userId': userId}, data: {'PlaybackPositionTicks': 0});

  /// Die Folge nach [episode] (auch über Staffelgrenzen hinweg), sonst `null`.
  Future<BaseItem?> getNextEpisode(BaseItem episode) async {
    final seriesId = episode.seriesId;
    if (seriesId == null) return null;
    try {
      final items = await _getItems('/Shows/$seriesId/Episodes', {..._common, 'startItemId': episode.id, 'limit': 2});
      final index = items.indexWhere((e) => e.id == episode.id);
      return index >= 0 && index + 1 < items.length ? items[index + 1] : null;
    } catch (_) {
      return null;
    }
  }

  /// Kachelbild mit Vorschaubildern für die Spulleiste.
  String trickplayTileUrl(String itemId, String mediaSourceId, int width, int tileIndex) =>
      '$baseUrl/Videos/$itemId/Trickplay/$width/$tileIndex.jpg?mediaSourceId=$mediaSourceId';

  Future<void> reportPlaybackStart(Json body) => dio.post('/Sessions/Playing', data: body);
  Future<void> reportPlaybackProgress(Json body) => dio.post('/Sessions/Playing/Progress', data: body);
  Future<void> reportPlaybackStopped(Json body) => dio.post('/Sessions/Playing/Stopped', data: body);

  // --- Bilder ----------------------------------------------------------------

  /// URL für ein Bild. Mit [fillWidth] + [fillHeight] schneidet der Server
  /// passend zu (wie jellyfin-web für Karten), mit [maxWidth]/[maxHeight]
  /// wird nur verkleinert (für Hintergründe und Logos).
  String imageUrl(ImageRef ref, {int? fillWidth, int? fillHeight, int? maxWidth, int? maxHeight, int quality = 96}) {
    final query = Uri(
      queryParameters: {
        'tag': ref.tag,
        if (fillWidth != null) 'fillWidth': '$fillWidth',
        if (fillHeight != null) 'fillHeight': '$fillHeight',
        if (maxWidth != null) 'maxWidth': '$maxWidth',
        if (maxHeight != null) 'maxHeight': '$maxHeight',
        'quality': '$quality',
      },
    ).query;
    final idx = ref.index != null ? '/${ref.index}' : '';
    return '$baseUrl/Items/${ref.itemId}/Images/${ref.type}$idx?$query';
  }

  /// Wie [imageUrl], aber `null`-tolerant.
  String? imageUrlOrNull(
    ImageRef? ref, {
    int? fillWidth,
    int? fillHeight,
    int? maxWidth,
    int? maxHeight,
    int quality = 96,
  }) => ref == null
      ? null
      : imageUrl(
          ref,
          fillWidth: fillWidth,
          fillHeight: fillHeight,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        );
}
