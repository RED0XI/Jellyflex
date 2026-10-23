/// Schlanke Wrapper um die JSON-Antworten von Jellyfin.
///
/// Statt jedes Feld vorab zu parsen, lesen die Getter direkt aus der Map.
/// So bleibt die App robust, wenn der Server Felder weglässt.
library;

typedef Json = Map<String, dynamic>;

Duration ticksToDuration(int ticks) => Duration(microseconds: ticks ~/ 10);
int durationToTicks(Duration d) => d.inMicroseconds * 10;

class BaseItem {
  BaseItem(this.raw);

  final Json raw;

  String get id => raw['Id'] as String;
  String get name => (raw['Name'] as String?) ?? '';
  String get type => (raw['Type'] as String?) ?? '';
  String? get overview => raw['Overview'] as String?;
  String? get collectionType => raw['CollectionType'] as String?;
  int? get productionYear => (raw['ProductionYear'] as num?)?.toInt();
  String? get officialRating => raw['OfficialRating'] as String?;
  double? get communityRating => (raw['CommunityRating'] as num?)?.toDouble();
  double? get criticRating => (raw['CriticRating'] as num?)?.toDouble();
  int? get runTimeTicks => (raw['RunTimeTicks'] as num?)?.toInt();
  String? get seriesId => raw['SeriesId'] as String?;
  String? get seriesName => raw['SeriesName'] as String?;
  String? get seasonId => raw['SeasonId'] as String?;
  String? get seasonName => raw['SeasonName'] as String?;
  int? get indexNumber => (raw['IndexNumber'] as num?)?.toInt();
  int? get parentIndexNumber => (raw['ParentIndexNumber'] as num?)?.toInt();
  int? get childCount => (raw['ChildCount'] as num?)?.toInt();
  String? get status => raw['Status'] as String?;
  List<String> get genres => _stringList(raw['Genres']);
  List<String> get taglines => _stringList(raw['Taglines']);

  /// Bei Personen: Geburtsort.
  List<String> get productionLocations => _stringList(raw['ProductionLocations']);

  bool get isMovie => type == 'Movie';
  bool get isSeries => type == 'Series';
  bool get isEpisode => type == 'Episode';
  bool get isSeason => type == 'Season';
  bool get isCollection => type == 'BoxSet';

  DateTime? get premiereDate => _date(raw['PremiereDate']);
  DateTime? get endDate => _date(raw['EndDate']);

  Duration? get runtime => runTimeTicks == null ? null : ticksToDuration(runTimeTicks!);

  /// z. B. "S1 E3"
  String? get episodeLabel {
    if (parentIndexNumber == null && indexNumber == null) return null;
    final s = parentIndexNumber != null ? 'S$parentIndexNumber' : '';
    final e = indexNumber != null ? 'E$indexNumber' : '';
    return [s, e].where((p) => p.isNotEmpty).join(' ');
  }

  // --- Bilder ---------------------------------------------------------------

  Map<String, String> get imageTags => _stringMap(raw['ImageTags']);
  List<String> get backdropImageTags => _stringList(raw['BackdropImageTags']);
  String? get parentBackdropItemId => raw['ParentBackdropItemId'] as String?;
  List<String> get parentBackdropImageTags => _stringList(raw['ParentBackdropImageTags']);
  String? get parentLogoItemId => raw['ParentLogoItemId'] as String?;
  String? get parentLogoImageTag => raw['ParentLogoImageTag'] as String?;
  String? get parentThumbItemId => raw['ParentThumbItemId'] as String?;
  String? get parentThumbImageTag => raw['ParentThumbImageTag'] as String?;
  String? get parentPrimaryImageItemId => raw['ParentPrimaryImageItemId'] as String?;
  String? get parentPrimaryImageTag => raw['ParentPrimaryImageTag'] as String?;
  String? get parentArtItemId => raw['ParentArtItemId'] as String?;
  String? get parentArtImageTag => raw['ParentArtImageTag'] as String?;
  String? get seriesPrimaryImageTag => raw['SeriesPrimaryImageTag'] as String?;
  String? get seriesThumbImageTag => raw['SeriesThumbImageTag'] as String?;
  double? get primaryImageAspectRatio => (raw['PrimaryImageAspectRatio'] as num?)?.toDouble();

  /// BlurHash eines bestimmten Bildes. Der Server liefert hier auch die
  /// Hashes geerbter Bilder (Serie, Staffel) mit – Schlüssel ist Typ + Tag.
  String? blurHashFor(String imageType, String tag) {
    final hashes = raw['ImageBlurHashes'];
    if (hashes is! Map) return null;
    final byType = hashes[imageType];
    if (byType is! Map) return null;
    final hash = byType[tag];
    return hash is String ? hash : null;
  }

  // --- Benutzerdaten, Personen, Medienquellen -------------------------------

  UserData get userData => UserData((raw['UserData'] as Map?)?.cast<String, dynamic>() ?? const {});

  List<Person> get people =>
      ((raw['People'] as List?) ?? const []).whereType<Map>().map((p) => Person(p.cast<String, dynamic>())).toList();

  List<MediaSource> get mediaSources => ((raw['MediaSources'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => MediaSource(m.cast<String, dynamic>()))
      .toList();

  /// Trickplay-Info für eine Medienquelle; bevorzugt die Auflösung um 320 px.
  /// Kapitel (Startzeit + Name), falls die Datei welche hat.
  List<Chapter> get chapters =>
      ((raw['Chapters'] as List?) ?? const []).whereType<Map>().map((c) => Chapter(c.cast<String, dynamic>())).toList();

  TrickplayInfo? trickplay(String mediaSourceId) {
    final all = raw['Trickplay'];
    if (all is! Map) return null;
    final bySource = all[mediaSourceId];
    if (bySource is! Map || bySource.isEmpty) return null;
    final infos = bySource.values.whereType<Map>().map((m) => TrickplayInfo(m.cast<String, dynamic>())).toList()
      ..sort((a, b) => (a.width - 320).abs().compareTo((b.width - 320).abs()));
    return infos.firstOrNull;
  }
}

class UserData {
  const UserData(this.raw);

  final Json raw;

  int get playbackPositionTicks => (raw['PlaybackPositionTicks'] as num?)?.toInt() ?? 0;
  double? get playedPercentage => (raw['PlayedPercentage'] as num?)?.toDouble();
  bool get played => raw['Played'] == true;
  bool get isFavorite => raw['IsFavorite'] == true;
  int? get unplayedItemCount => (raw['UnplayedItemCount'] as num?)?.toInt();

  bool get hasResumePosition => playbackPositionTicks > 0;
}

class Person {
  Person(this.raw);

  final Json raw;

  String get id => raw['Id'] as String;
  String get name => (raw['Name'] as String?) ?? '';
  String? get role => raw['Role'] as String?;
  String? get type => raw['Type'] as String?;
  String? get primaryImageTag => raw['PrimaryImageTag'] as String?;

  String? get blurHash {
    final tag = primaryImageTag;
    final hashes = raw['ImageBlurHashes'];
    if (tag == null || hashes is! Map) return null;
    final primary = hashes['Primary'];
    if (primary is! Map) return null;
    final hash = primary[tag];
    return hash is String ? hash : null;
  }
}

class MediaSource {
  MediaSource(this.raw);

  final Json raw;

  String get id => raw['Id'] as String;
  String? get container => raw['Container'] as String?;

  /// Name der Fassung (z. B. "Director's Cut" oder Dateiname-Zusatz wie "2160p").
  String? get name => raw['Name'] as String?;

  /// Dateigröße in Bytes.
  int? get size => (raw['Size'] as num?)?.toInt();
  String? get path => raw['Path'] as String?;
  int? get runTimeTicks => (raw['RunTimeTicks'] as num?)?.toInt();
  int? get defaultAudioStreamIndex => (raw['DefaultAudioStreamIndex'] as num?)?.toInt();
  int? get defaultSubtitleStreamIndex => (raw['DefaultSubtitleStreamIndex'] as num?)?.toInt();

  /// Bei umgerechneter Wiedergabe: relative Adresse des HLS-Streams.
  String? get transcodingUrl => raw['TranscodingUrl'] as String?;

  /// Gesamt-Bitrate der Originaldatei (bit/s).
  int? get bitrate => (raw['Bitrate'] as num?)?.toInt();

  List<MediaStream> get mediaStreams => ((raw['MediaStreams'] as List?) ?? const [])
      .whereType<Map>()
      .map((s) => MediaStream(s.cast<String, dynamic>()))
      .toList();

  /// Eingebettete Streams eines Typs in Datei-Reihenfolge.
  /// Die n-te Spur hier entspricht der mpv-Spur mit der ID "n+1".
  List<MediaStream> embeddedStreams(String type) =>
      mediaStreams.where((s) => s.type == type && !s.isExternal).toList()..sort((a, b) => a.index.compareTo(b.index));

  MediaStream? get videoStream => mediaStreams.where((s) => s.type == 'Video').firstOrNull;
  List<MediaStream> get audioStreams => mediaStreams.where((s) => s.type == 'Audio').toList();
  List<MediaStream> get subtitleStreams => mediaStreams.where((s) => s.type == 'Subtitle').toList();
}

class MediaStream {
  MediaStream(this.raw);

  final Json raw;

  String get type => (raw['Type'] as String?) ?? '';
  int get index => (raw['Index'] as num?)?.toInt() ?? 0;
  String? get codec => raw['Codec'] as String?;
  String? get language => raw['Language'] as String?;
  String? get displayTitle => raw['DisplayTitle'] as String?;
  bool get isExternal => raw['IsExternal'] == true;
  bool get isDefault => raw['IsDefault'] == true;
  bool get isForced => raw['IsForced'] == true;
  int? get height => (raw['Height'] as num?)?.toInt();
  int? get width => (raw['Width'] as num?)?.toInt();
  String? get title => raw['Title'] as String?;
  String? get profile => raw['Profile'] as String?;

  /// Bitrate dieser Spur (bit/s).
  int? get bitRate => (raw['BitRate'] as num?)?.toInt();
  int? get bitDepth => (raw['BitDepth'] as num?)?.toInt();
  double? get frameRate => ((raw['RealFrameRate'] ?? raw['AverageFrameRate']) as num?)?.toDouble();

  /// "SDR" oder "HDR"; genauer: [videoRangeType] (HDR10, HDR10Plus, DOVI, HLG …).
  String? get videoRange => raw['VideoRange'] as String?;
  String? get videoRangeType => raw['VideoRangeType'] as String?;
  int? get channels => (raw['Channels'] as num?)?.toInt();
  String? get channelLayout => raw['ChannelLayout'] as String?;
  int? get sampleRate => (raw['SampleRate'] as num?)?.toInt();

  /// "External", "Encode" (eingebrannt) … – nur bei umgerechneter Wiedergabe.
  String? get deliveryMethod => raw['DeliveryMethod'] as String?;
  String? get deliveryUrl => raw['DeliveryUrl'] as String?;
}

/// Empfehlungskategorie ("Weil du X angesehen hast" …).
class Recommendation {
  Recommendation(this.raw);

  final Json raw;

  String get type => (raw['RecommendationType'] as String?) ?? '';
  String get baselineItemName => (raw['BaselineItemName'] as String?) ?? '';

  List<BaseItem> get items =>
      ((raw['Items'] as List?) ?? const []).whereType<Map>().map((m) => BaseItem(m.cast<String, dynamic>())).toList();

  /// Überschrift für die Reihe auf der Startseite.
  String get title => switch (type) {
    'SimilarToRecentlyPlayed' => 'Weil du „$baselineItemName“ angesehen hast',
    'SimilarToLikedItem' => 'Weil dir „$baselineItemName“ gefällt',
    'HasDirectorFromRecentlyPlayed' || 'HasLikedDirector' => 'Mehr von $baselineItemName',
    'HasActorFromRecentlyPlayed' || 'HasLikedActor' => 'Mit $baselineItemName',
    _ => 'Empfehlungen',
  };
}

class Chapter {
  Chapter(this.raw);

  final Json raw;

  Duration get start => ticksToDuration((raw['StartPositionTicks'] as num?)?.toInt() ?? 0);
  String get name => (raw['Name'] as String?) ?? '';
}

/// Abschnitt einer Folge (Intro, Abspann …) aus der MediaSegments-API.
class MediaSegment {
  MediaSegment(this.raw);

  final Json raw;

  String get type => (raw['Type'] as String?) ?? 'Unknown';
  Duration get start => ticksToDuration((raw['StartTicks'] as num?)?.toInt() ?? 0);
  Duration get end => ticksToDuration((raw['EndTicks'] as num?)?.toInt() ?? 0);

  bool contains(Duration position) => position >= start && position < end;
}

/// Beschreibung der Trickplay-Vorschaubilder (Kachelraster pro Bild).
class TrickplayInfo {
  TrickplayInfo(this.raw);

  final Json raw;

  int get width => (raw['Width'] as num?)?.toInt() ?? 320;
  int get height => (raw['Height'] as num?)?.toInt() ?? 180;
  int get tileWidth => (raw['TileWidth'] as num?)?.toInt() ?? 10;
  int get tileHeight => (raw['TileHeight'] as num?)?.toInt() ?? 10;
  int get thumbnailCount => (raw['ThumbnailCount'] as num?)?.toInt() ?? 0;

  /// Abstand zwischen zwei Vorschaubildern.
  Duration get interval => Duration(milliseconds: (raw['Interval'] as num?)?.toInt() ?? 10000);
}

class PlaybackInfo {
  PlaybackInfo(this.raw);

  final Json raw;

  String? get playSessionId => raw['PlaySessionId'] as String?;

  List<MediaSource> get mediaSources => ((raw['MediaSources'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => MediaSource(m.cast<String, dynamic>()))
      .toList();
}

List<String> _stringList(Object? value) => value is List ? value.whereType<String>().toList() : const [];

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final e in value.entries)
      if (e.key is String && e.value is String) e.key as String: e.value as String,
  };
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
