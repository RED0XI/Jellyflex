// Kleiner Jellyfin-Attrappen-Server zum Testen der Oberfläche ohne echten Server.
//
// Start:   dart run tool/mock_server.dart
// In der App als Server-Adresse eingeben:  http://localhost:8097
// Beliebiger Benutzername/Passwort funktioniert.
//
// Liefert fiktive Filme/Serien und erzeugt farbige Platzhalterbilder. Als Video
// dient für alle Titel %TEMP%\jellyflex_test.mkv (siehe lib/dev/player_harness.dart).
//
// Testschnittstellen (nur hier, nicht bei Jellyfin):
//   POST /debug/send       {"MessageType": …, "Data": …} an alle Live-Verbindungen
//   POST /debug/throttle?bps=200000   Videos langsam ausliefern (0 = normal)
//   POST /debug/offline?on=1          Server "nicht erreichbar" spielen (503)
//   GET  /debug/userdata/{id}         Benutzerdaten eines Titels ansehen

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const port = 8097;

/// Offene Live-Verbindungen (WebSocket).
final _sockets = <WebSocket>{};

/// Bytes pro Sekunde beim Ausliefern von Videos (0 = so schnell wie möglich).
var _throttleBps = 0;

/// Simuliert einen nicht erreichbaren Server.
var _offline = false;

/// Testvideo für alle Streams (siehe lib/dev/player_harness.dart).
final _videoFile = File(
  Platform.environment['JELLYFLEX_TEST_VIDEO'] ?? '${Directory.systemTemp.path}\\jellyflex_test.mkv',
);

/// Liefert das Testvideo aus – mit Range-Unterstützung, damit Spulen klappt.
Future<void> _serveVideo(HttpRequest req) async {
  final res = req.response;
  if (!_videoFile.existsSync()) {
    res.statusCode = 404;
    await res.close();
    return;
  }
  final length = _videoFile.lengthSync();
  res.headers.set('Accept-Ranges', 'bytes');
  res.headers.contentType = ContentType('video', 'x-matroska');
  var start = 0;
  var end = length - 1;
  final range = req.headers.value('range');
  final match = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
  if (match != null) {
    start = int.tryParse(match.group(1)!) ?? 0;
    end = match.group(2)!.isEmpty ? length - 1 : int.parse(match.group(2)!);
    res.statusCode = HttpStatus.partialContent;
    res.headers.set('Content-Range', 'bytes $start-$end/$length');
  }
  res.contentLength = end - start + 1;
  try {
    if (_throttleBps <= 0) {
      await res.addStream(_videoFile.openRead(start, end + 1));
    } else {
      // In kleinen Stücken mit Pausen – zum Testen von Pause/Fortschritt beim Download.
      final file = await _videoFile.open();
      try {
        await file.setPosition(start);
        final step = math.max(1024, _throttleBps ~/ 10);
        var pos = start;
        while (pos <= end) {
          final chunk = await file.read(math.min(step, end - pos + 1));
          if (chunk.isEmpty) break;
          res.add(chunk);
          await res.flush();
          pos += chunk.length;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } finally {
        await file.close();
      }
    }
  } catch (_) {
    // Abbruch durch den Player (z. B. beim Spulen) – normal.
  }
  await res.close();
}

final _rand = math.Random(7);

const _genres = ['Action', 'Drama', 'Sci-Fi', 'Komödie', 'Thriller', 'Abenteuer', 'Fantasy', 'Krimi', 'Animation'];
const _movieNames = [
  'Das Echo der Sterne',
  'Nachtfalter',
  'Kalte Brandung',
  'Der letzte Sommer',
  'Projekt Aurora',
  'Stadt aus Glas',
  'Die Uhrmacherin',
  'Sturmwarnung',
  'Unter Null',
  'Grenzgänger',
  'Morgenrot',
  'Die stille Insel',
  'Funkenflug',
  'Atlas',
];
const _seriesNames = ['Nordlicht', 'Die Akademie', 'Signal', 'Blaue Stunde', 'Hafenviertel', 'Orbit'];
const _overview =
    'Eine fesselnde Geschichte über Mut, Freundschaft und die Frage, was uns wirklich zusammenhält. '
    'Als ein unerwartetes Ereignis alles auf den Kopf stellt, müssen die Figuren über sich hinauswachsen – '
    'und entdecken dabei, dass nichts so ist, wie es scheint.';

final movies = <Map<String, dynamic>>[];
final series = <Map<String, dynamic>>[];
final seasons = <String, List<Map<String, dynamic>>>{};
final episodes = <String, List<Map<String, dynamic>>>{};
final byId = <String, Map<String, dynamic>>{};

Map<String, dynamic> _userData({int position = 0, bool played = false, bool favorite = false, int? unplayed}) => {
  'PlaybackPositionTicks': position,
  'Played': played,
  'IsFavorite': favorite,
  'UnplayedItemCount': ?unplayed,
};

List<Map<String, dynamic>> _people() => [
  for (var i = 0; i < 8; i++)
    {
      'Id': 'person$i',
      'Name': [
        'Lena Brandt',
        'Jonas Weber',
        'Mira Okafor',
        'Tom Hendriks',
        'Sara Lindqvist',
        'Ali Demir',
        'Nora Kim',
        'Paul Roth',
      ][i],
      'Role': ['Hauptrolle', 'Kommissar', 'Wissenschaftlerin', 'Pilot', 'Mutter', 'Hacker', 'Agentin', 'Erzähler'][i],
      'Type': 'Actor',
      'PrimaryImageTag': 'p$i',
    },
];

void _seed() {
  byId['boxset0'] = {
    'Id': 'boxset0',
    'Name': 'Die Sterne-Trilogie',
    'Type': 'BoxSet',
    'Overview': 'Alle drei Teile der gefeierten Reihe in einer Sammlung.',
    'ProductionYear': 2012,
    'ImageTags': {'Primary': 'p'},
    'BackdropImageTags': ['b0'],
    'ChildCount': 3,
    'UserData': _userData(),
  };
  for (var i = 0; i < _movieNames.length; i++) {
    final id = 'movie$i';
    final runtime = (85 + _rand.nextInt(70)) * 60 * 10000000;
    final m = <String, dynamic>{
      'Id': id,
      'Name': _movieNames[i],
      'Type': 'Movie',
      'ProductionYear': 2010 + _rand.nextInt(15),
      'CommunityRating': 5.5 + _rand.nextDouble() * 3.5,
      'CriticRating': 40 + _rand.nextInt(60),
      'OfficialRating': ['FSK-6', 'FSK-12', 'FSK-16'][i % 3],
      'RunTimeTicks': runtime,
      'Overview': _overview,
      'Taglines': i.isEven ? ['Manche Geheimnisse sollten verborgen bleiben.'] : [],
      'Genres': [_genres[i % _genres.length], _genres[(i + 3) % _genres.length]],
      'ImageTags': {'Primary': 'p', if (i % 3 == 0) 'Logo': 'l', if (i % 2 == 0) 'Thumb': 't'},
      'BackdropImageTags': i % 4 == 0 ? ['b0', 'b1', 'b2'] : ['b0'],
      'PrimaryImageAspectRatio': 0.6667,
      'People': _people(),
      'UserData': _userData(
        position: i < 3 ? (runtime * (0.2 + i * 0.25)).round() : 0,
        played: i == 5,
        favorite: i % 5 == 1,
      ),
      'MediaSources': [
        {
          'Id': id,
          'Container': 'mkv',
          'MediaStreams': [
            {'Type': 'Video', 'Index': 0, 'Codec': 'hevc'},
            {'Type': 'Audio', 'Index': 1, 'Language': 'ger', 'DisplayTitle': 'Deutsch - EAC3 - 5.1 - Standard'},
            {'Type': 'Audio', 'Index': 2, 'Language': 'eng', 'DisplayTitle': 'Englisch - TrueHD - 7.1'},
            if (i == 0)
              {
                'Type': 'Subtitle',
                'Index': 3,
                'Language': 'ger',
                'Codec': 'srt',
                'IsExternal': true,
                'DisplayTitle': 'Deutsch - SRT - Extern',
              },
          ],
        },
      ],
    };
    movies.add(m);
    byId[id] = m;
  }

  for (var s = 0; s < _seriesNames.length; s++) {
    final seriesId = 'series$s';
    final ser = <String, dynamic>{
      'Id': seriesId,
      'Name': _seriesNames[s],
      'Type': 'Series',
      'ProductionYear': 2015 + s,
      'EndDate': s.isEven ? '${2019 + s}-01-01T00:00:00Z' : null,
      'Status': s.isEven ? 'Ended' : 'Continuing',
      'CommunityRating': 7.0 + _rand.nextDouble() * 2,
      'OfficialRating': 'FSK-12',
      'Overview': _overview,
      'Genres': [_genres[(s + 2) % _genres.length], 'Drama'],
      'ChildCount': 2,
      'ImageTags': {'Primary': 'p', 'Logo': 'l', 'Thumb': 't'},
      'BackdropImageTags': ['b0', 'b1'],
      'People': _people(),
      'UserData': _userData(unplayed: 10 + s, favorite: s == 2),
    };
    series.add(ser);
    byId[seriesId] = ser;
    seasons[seriesId] = [];

    for (var n = 1; n <= 2; n++) {
      final seasonId = '${seriesId}_s$n';
      final season = <String, dynamic>{
        'Id': seasonId,
        'Name': 'Staffel $n',
        'Type': 'Season',
        'IndexNumber': n,
        'SeriesId': seriesId,
        'SeriesName': ser['Name'],
        'ImageTags': {'Primary': 'p'},
        'ParentBackdropItemId': seriesId,
        'ParentBackdropImageTags': ['b0', 'b1'],
        'UserData': _userData(),
      };
      seasons[seriesId]!.add(season);
      byId[seasonId] = season;
      episodes[seasonId] = [];

      for (var e = 1; e <= 8; e++) {
        final epId = '${seasonId}_e$e';
        final runtime = (42 + _rand.nextInt(15)) * 60 * 10000000;
        final ep = <String, dynamic>{
          'Id': epId,
          'Name': [
            'Der Anfang',
            'Spuren im Schnee',
            'Funkstille',
            'Gegenwind',
            'Die Wahrheit',
            'Zwischenzeit',
            'Lichtjahre',
            'Finale',
          ][e - 1],
          'Type': 'Episode',
          'IndexNumber': e,
          'ParentIndexNumber': n,
          'SeriesId': seriesId,
          'SeriesName': ser['Name'],
          'SeasonId': seasonId,
          'SeasonName': 'Staffel $n',
          'RunTimeTicks': runtime,
          'Overview': 'In dieser Folge spitzt sich die Lage zu – und eine alte Entscheidung holt alle wieder ein.',
          'ImageTags': {'Primary': 'p'},
          'SeriesPrimaryImageTag': 'p',
          'SeriesThumbImageTag': 't',
          'ParentPrimaryImageItemId': seasonId,
          'ParentPrimaryImageTag': 'p',
          'ParentBackdropItemId': seriesId,
          'ParentBackdropImageTags': ['b0', 'b1'],
          'ParentLogoItemId': seriesId,
          'ParentLogoImageTag': 'l',
          'ParentThumbItemId': seriesId,
          'ParentThumbImageTag': 't',
          'UserData': _userData(
            played: s < 2 && n == 1 && e < 4,
            position: s < 2 && n == 1 && e == 4 ? runtime ~/ 3 : 0,
          ),
        };
        episodes[seasonId]!.add(ep);
        byId[epId] = ep;
      }
    }
  }
}

// --- Bilder: farbige Verläufe als PNG -------------------------------------------

final _imageCache = <String, List<int>>{};

List<int> _png(int w, int h, int seed, {bool logo = false}) {
  final r = math.Random(seed);
  final c1 = [40 + r.nextInt(150), 30 + r.nextInt(120), 60 + r.nextInt(170)];
  final c2 = [r.nextInt(60), r.nextInt(60), 20 + r.nextInt(80)];
  final channels = logo ? 4 : 3;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    final row = Uint8List(w * channels);
    for (var x = 0; x < w; x++) {
      final t = (x / w) * 0.55 + (y / h) * 0.45;
      final i = x * channels;
      if (logo) {
        // Weißer "Schriftzug"-Balken auf transparentem Grund.
        final inBar = y > h * 0.3 && y < h * 0.7 && x > w * 0.05 && x < w * 0.95;
        row[i] = 255;
        row[i + 1] = 255;
        row[i + 2] = 255;
        row[i + 3] = inBar ? 230 : 0;
      } else {
        for (var c = 0; c < 3; c++) {
          row[i + c] = (c1[c] + (c2[c] - c1[c]) * t).round().clamp(0, 255);
        }
      }
    }
    raw.add(row);
  }
  final idat = ZLibEncoder().convert(raw.toBytes());
  final out = BytesBuilder()..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = ascii.encode(type);
    out.add(_u32(data.length));
    out.add(typeBytes);
    out.add(data);
    out.add(_u32(_crc32([...typeBytes, ...data])));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, logo ? 6 : 2, 0, 0, 0]);
  chunk('IDAT', idat);
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

// --- HTTP ----------------------------------------------------------------------

Map<String, dynamic> _page(List<Map<String, dynamic>> items, Map<String, String> q) {
  final start = int.tryParse(q['startIndex'] ?? '') ?? 0;
  final limit = int.tryParse(q['limit'] ?? '') ?? items.length;
  return {'Items': items.skip(start).take(limit).toList(), 'TotalRecordCount': items.length, 'StartIndex': start};
}

Object? _handle(HttpRequest req) {
  final path = req.uri.path;
  final q = req.uri.queryParameters;
  final seg = path.split('/').where((s) => s.isNotEmpty).toList();

  if (path == '/System/Info/Public') {
    return {'ServerName': 'Demo-Server', 'Version': '12.2.0', 'Id': 'mock-server', 'ProductName': 'Jellyfin Server'};
  }
  if (path == '/Users/AuthenticateByName') {
    return {
      'AccessToken': 'mock-token',
      'User': {'Id': 'user1', 'Name': 'Demo'},
    };
  }
  if (path == '/QuickConnect/Enabled') return false;
  if (path == '/Sessions/Logout' || path.startsWith('/Sessions/Playing') || path.startsWith('/Sessions/Capabilities')) {
    return '';
  }
  if (path == '/UserViews') {
    return {
      'Items': [
        {
          'Id': 'lib-movies',
          'Name': 'Filme',
          'Type': 'CollectionFolder',
          'CollectionType': 'movies',
          'ImageTags': {'Primary': 'p'},
        },
        {
          'Id': 'lib-shows',
          'Name': 'Serien',
          'Type': 'CollectionFolder',
          'CollectionType': 'tvshows',
          'ImageTags': {'Primary': 'p'},
        },
      ],
    };
  }
  if (path == '/UserItems/Resume') {
    final all = [
      ...movies,
      for (final e in episodes.values) ...e,
    ].where((i) => (i['UserData']['PlaybackPositionTicks'] as int) > 0).toList();
    return _page(all, q);
  }
  if (path == '/Shows/NextUp') {
    final sid = q['seriesId'];
    final list = <Map<String, dynamic>>[];
    for (final ser in series) {
      if (sid != null && ser['Id'] != sid) continue;
      final eps = [for (final s in seasons[ser['Id']]!) ...episodes[s['Id']]!];
      final next = eps.where((e) => e['UserData']['Played'] != true).firstOrNull;
      if (next != null && eps.any((e) => e['UserData']['Played'] == true)) list.add(next);
    }
    return _page(list, q);
  }
  if (path == '/Items/Latest') {
    return q['parentId'] == 'lib-shows' ? series.reversed.toList() : movies.reversed.toList();
  }
  if (path == '/Genres')
    return {
      'Items': [
        for (final g in _genres) {'Name': g, 'Id': 'genre-$g'},
      ],
    };
  if (path == '/Movies/Recommendations') {
    return [
      {
        'RecommendationType': 'SimilarToRecentlyPlayed',
        'BaselineItemName': movies[0]['Name'],
        'Items': movies.skip(3).take(8).toList(),
      },
      {
        'RecommendationType': 'SimilarToLikedItem',
        'BaselineItemName': movies[1]['Name'],
        'Items': movies.skip(6).take(8).toList(),
      },
    ];
  }
  if (path == '/Items' && q['parentId'] == 'boxset0') return _page(movies.take(3).toList(), q);
  if (path == '/Items') {
    var list = <Map<String, dynamic>>[];
    final types = (q['includeItemTypes'] ?? 'Movie,Series').split(',');
    if (types.contains('BoxSet')) list.add(byId['boxset0']!);
    final genre = q['genres'];
    if (genre != null) {
      return _page([...movies, ...series].where((i) => (i['Genres'] as List).contains(genre)).toList(), q);
    }
    if (types.contains('Movie') && q['parentId'] != 'lib-shows') list.addAll(movies);
    if (types.contains('Series') && q['parentId'] != 'lib-movies') list.addAll(series);
    if (types.contains('Episode')) list.addAll([for (final e in episodes.values) ...e]);
    final term = q['searchTerm']?.toLowerCase();
    if (term != null) list = list.where((i) => (i['Name'] as String).toLowerCase().contains(term)).toList();
    if (q['filters'] == 'IsFavorite') list = list.where((i) => i['UserData']['IsFavorite'] == true).toList();
    if (q['sortBy'] == 'Random') list.shuffle(_rand);
    if (q['sortBy']?.startsWith('SortName') ?? false) {
      list.sort((a, b) => (a['Name'] as String).compareTo(b['Name'] as String));
    }
    return _page(list, q);
  }
  if (seg.length == 3 && seg[0] == 'Shows' && seg[2] == 'Seasons') return {'Items': seasons[seg[1]] ?? []};
  if (seg.length == 3 && seg[0] == 'Shows' && seg[2] == 'Episodes') {
    final seasonId = q['seasonId'];
    var list = seasonId != null
        ? episodes[seasonId] ?? <Map<String, dynamic>>[]
        : [for (final s in seasons[seg[1]] ?? <Map<String, dynamic>>[]) ...episodes[s['Id']]!];
    final startId = q['startItemId'];
    if (startId != null) list = list.skipWhile((e) => e['Id'] != startId).toList();
    return _page(list, q);
  }
  if (seg.length == 3 && seg[0] == 'Items' && seg[2] == 'Similar') {
    return {'Items': movies.where((m) => m['Id'] != seg[1]).take(10).toList()};
  }
  if (seg.length == 3 && seg[0] == 'Items' && seg[2] == 'PlaybackInfo') {
    final item = byId[seg[1]];
    return {'PlaySessionId': 'mock-session', 'MediaSources': item?['MediaSources'] ?? []};
  }
  if (seg.length == 2 && seg[0] == 'MediaSegments') return {'Items': []};
  if (seg.length == 3 && seg[0] == 'Items' && seg[2] == 'LocalTrailers') {
    if (!(byId[seg[1]]?['Type'] == 'Movie')) return [];
    final id = 'trailer-${seg[1]}';
    return [
      {
        'Id': id,
        'Name': 'Trailer',
        'Type': 'Trailer',
        'MediaSources': [
          {'Id': id},
        ],
      },
    ];
  }
  if (seg.length == 3 && seg[0] == 'Items' && seg[2] == 'ThemeVideos') return {'Items': []};
  if (seg.length == 2 && seg[0] == 'Items') return byId[seg[1]];
  if (seg.length >= 2 && (seg[0] == 'UserFavoriteItems' || seg[0] == 'UserPlayedItems')) {
    final item = byId[seg[1]];
    if (item != null) {
      final key = seg[0] == 'UserFavoriteItems' ? 'IsFavorite' : 'Played';
      item['UserData'][key] = req.method == 'POST';
    }
    return item?['UserData'] ?? {};
  }
  return null;
}

Future<void> main() async {
  _seed();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Jellyfin-Demo-Server läuft auf http://localhost:$port');

  await for (final req in server) {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments;
      // Live-Verbindung wie bei Jellyfin (/socket).
      if (req.uri.path == '/socket' && WebSocketTransformer.isUpgradeRequest(req)) {
        final socket = await WebSocketTransformer.upgrade(req);
        _sockets.add(socket);
        socket.add(jsonEncode({'MessageType': 'ForceKeepAlive', 'Data': 60}));
        socket.listen((_) {}, onDone: () => _sockets.remove(socket));
        stdout.writeln('Live-Verbindung geöffnet (${_sockets.length})');
        continue;
      }
      // Testschnittstelle: POST /debug/send mit {"MessageType": …, "Data": …} an alle Clients.
      if (req.uri.path == '/debug/throttle') {
        _throttleBps = int.tryParse(req.uri.queryParameters['bps'] ?? '') ?? 0;
        res.write('{"bps": $_throttleBps}');
        await res.close();
        continue;
      }
      if (req.uri.path == '/debug/offline') {
        _offline = req.uri.queryParameters['on'] == '1';
        res.write('{"offline": $_offline}');
        await res.close();
        continue;
      }
      if (seg.length == 3 && seg[0] == 'debug' && seg[1] == 'userdata') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(byId[seg[2]]?['UserData']));
        await res.close();
        continue;
      }
      if (_offline) {
        res.statusCode = HttpStatus.serviceUnavailable;
        await res.close();
        continue;
      }
      // Benutzerdaten setzen (Fortschritt, gesehen, zuletzt geschaut).
      if (seg.length == 3 && seg[0] == 'UserItems' && seg[2] == 'UserData' && req.method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        final data = byId[seg[1]]?['UserData'] as Map<String, dynamic>?;
        data?.addAll(body);
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(data ?? {}));
        await res.close();
        continue;
      }
      if (seg.length == 6 && seg[0] == 'Videos' && seg[3] == 'Subtitles') {
        res.headers.contentType = ContentType('application', 'x-subrip', charset: 'utf-8');
        res.write('1\n00:00:01,000 --> 00:00:04,000\nExterner Untertitel (Demo)\n');
        await res.close();
        continue;
      }
      if (req.uri.path == '/debug/send' && req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        for (final s in _sockets) {
          s.add(body);
        }
        res.write('{"sent": ${_sockets.length}}');
        await res.close();
        continue;
      }
      if (seg.length == 3 && seg[0] == 'Videos' && seg[2] == 'stream') {
        // Nicht abwarten: Streams laufen parallel zu anderen Anfragen.
        unawaited(_serveVideo(req));
        continue;
      }
      if (seg.length >= 4 && seg[0] == 'Items' && seg[2] == 'Images') {
        final q = req.uri.queryParameters;
        final type = seg[3];
        final isLogo = type == 'Logo';
        int? parse(String k) => int.tryParse(q[k] ?? '');
        var w = parse('fillWidth') ?? parse('maxWidth') ?? (type == 'Primary' ? 400 : 1280);
        var h =
            parse('fillHeight') ??
            parse('maxHeight') ??
            (type == 'Primary' && !seg[1].contains('_e') && !seg[1].startsWith('lib')
                ? (w * 1.5).round()
                : (w * 9 / 16).round());
        if (isLogo) {
          w = 600;
          h = 180;
        }
        // Für die Geschwindigkeit verkleinern – die App skaliert ohnehin.
        final scale = math.min(1.0, 640 / w);
        w = math.max(8, (w * scale).round());
        h = math.max(8, (h * scale).round());
        final key = '${seg.join('/')}-$w-$h';
        final bytes = _imageCache.putIfAbsent(key, () => _png(w, h, key.hashCode, logo: isLogo));
        res.headers.contentType = ContentType('image', 'png');
        res.add(bytes);
      } else {
        final body = _handle(req);
        if (body == null) {
          res.statusCode = 404;
        } else {
          res.headers.contentType = ContentType.json;
          res.write(body is String ? body : jsonEncode(body));
        }
      }
    } catch (e) {
      res.statusCode = 500;
      res.write('$e');
    }
    await res.close();
  }
}
