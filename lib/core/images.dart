import 'models.dart';

/// Bildtypen, wie Jellyfin sie kennt.
///
/// Der Server ordnet lokale Artwork-Dateien diesen Typen zu
/// (siehe https://jellyfin.org/docs/general/server/media/movies/#metadata-images):
///
/// | Typ      | Dateinamen                                              |
/// |----------|---------------------------------------------------------|
/// | Primary  | poster, folder, cover, default, movie, show, *-thumb (Episode) |
/// | Backdrop | backdrop, fanart, background, art, extrafanart/ (mehrere) |
/// | Thumb    | landscape, thumb                                        |
/// | Logo     | logo, clearlogo                                         |
/// | Banner   | banner                                                  |
/// | Art      | clearart                                                |
/// | Disc     | disc, cdart, discart                                    |
///
/// Staffelbilder können auch im Serienordner liegen (season01-poster,
/// season01-fanart, season01-landscape, season-specials-poster …).
abstract final class ImageType {
  static const primary = 'Primary';
  static const backdrop = 'Backdrop';
  static const thumb = 'Thumb';
  static const logo = 'Logo';
  static const banner = 'Banner';
  static const art = 'Art';
  static const disc = 'Disc';
}

/// Verweis auf ein konkretes Bild auf dem Server.
class ImageRef {
  const ImageRef(this.itemId, this.type, this.tag, {this.index, this.blurHash});

  /// Eintrag, dem das Bild gehört – bei geerbten Bildern z. B. die Serie.
  final String itemId;
  final String type;
  final String tag;

  /// Nur bei Backdrops: welches von mehreren (backdrop, backdrop1, …).
  final int? index;
  final String? blurHash;

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.itemId == itemId && other.type == type && other.tag == tag && other.index == index;

  @override
  int get hashCode => Object.hash(itemId, type, tag, index);
}

/// Wählt Bilder genauso aus wie die offizielle Jellyfin-Weboberfläche
/// (`getCardImageUrl` in jellyfin-web, `components/cardbuilder/utils/url.ts`
/// und `components/backdrop/backdrop.js`), inklusive aller Rückfallebenen
/// auf Bilder der Staffel bzw. Serie.
///
/// Wichtig: Die BlurHashes geerbter Bilder liefert der Server in
/// `ImageBlurHashes` des Eintrags selbst mit – nachgeschlagen über Typ + Tag.
abstract final class Images {
  static ImageRef? _ref(BaseItem source, String? itemId, String type, String? tag, {int? index}) {
    if (itemId == null || tag == null) return null;
    return ImageRef(itemId, type, tag, index: index, blurHash: source.blurHashFor(type, tag));
  }

  static ImageRef? _own(BaseItem item, String type) => _ref(item, item.id, type, item.imageTags[type]);

  static ImageRef? _firstBackdrop(BaseItem item) =>
      _ref(item, item.id, ImageType.backdrop, item.backdropImageTags.firstOrNull, index: 0);

  static ImageRef? _seriesThumb(BaseItem item) => _ref(item, item.seriesId, ImageType.thumb, item.seriesThumbImageTag);

  static ImageRef? _parentThumb(BaseItem item) =>
      _ref(item, item.parentThumbItemId, ImageType.thumb, item.parentThumbImageTag);

  static ImageRef? _parentBackdrop(BaseItem item) =>
      _ref(item, item.parentBackdropItemId, ImageType.backdrop, item.parentBackdropImageTags.firstOrNull, index: 0);

  static ImageRef? _seriesPrimary(BaseItem item) =>
      _ref(item, item.seriesId, ImageType.primary, item.seriesPrimaryImageTag);

  static ImageRef? _parentPrimary(BaseItem item) =>
      _ref(item, item.parentPrimaryImageItemId, ImageType.primary, item.parentPrimaryImageTag);

  /// Hochformat (Poster). Bei Episoden wird – wie mit `preferParentPoster` in
  /// jellyfin-web – das Staffel- bzw. Serienposter genommen.
  static ImageRef? poster(BaseItem item) {
    if (item.isEpisode) {
      final parent = _parentPrimary(item) ?? _seriesPrimary(item);
      if (parent != null) return parent;
    }
    return _own(item, ImageType.primary) ??
        _seriesPrimary(item) ??
        _parentPrimary(item) ??
        (item.isSeason ? _own(item, ImageType.thumb) : null) ??
        _firstBackdrop(item) ??
        _own(item, ImageType.thumb) ??
        _seriesThumb(item) ??
        _parentThumb(item) ??
        _parentBackdrop(item);
  }

  /// Querformat (16:9) – entspricht `preferThumb` in jellyfin-web.
  ///
  /// Für Episoden gilt standardmäßig das Standbild der Folge (wie die
  /// Option "Episodenbilder in Weiterschauen verwenden"). Mit
  /// [episodeImages] = false wird das Serien-Thumb bevorzugt.
  static ImageRef? landscape(BaseItem item, {bool episodeImages = true}) {
    if (item.isEpisode && episodeImages) {
      return _own(item, ImageType.thumb) ??
          _own(item, ImageType.primary) ??
          _seriesThumb(item) ??
          _parentThumb(item) ??
          _parentBackdrop(item);
    }
    return _own(item, ImageType.thumb) ??
        _seriesThumb(item) ??
        _parentThumb(item) ??
        _firstBackdrop(item) ??
        (item.isEpisode ? _parentBackdrop(item) : null) ??
        _own(item, ImageType.primary) ??
        (item.isEpisode ? null : _seriesPrimary(item)) ??
        _parentBackdrop(item);
  }

  /// Alle Hintergrundbilder (backdrop, backdrop1, … bzw. fanart, extrafanart).
  /// Eigene zuerst, sonst die geerbten (Episode/Staffel → Serie).
  static List<ImageRef> backdrops(BaseItem item) {
    final own = item.backdropImageTags;
    if (own.isNotEmpty) {
      return [
        for (var i = 0; i < own.length; i++)
          ImageRef(
            item.id,
            ImageType.backdrop,
            own[i],
            index: i,
            blurHash: item.blurHashFor(ImageType.backdrop, own[i]),
          ),
      ];
    }
    final parentId = item.parentBackdropItemId;
    final parent = item.parentBackdropImageTags;
    if (parentId != null && parent.isNotEmpty) {
      return [
        for (var i = 0; i < parent.length; i++)
          ImageRef(
            parentId,
            ImageType.backdrop,
            parent[i],
            index: i,
            blurHash: item.blurHashFor(ImageType.backdrop, parent[i]),
          ),
      ];
    }
    return const [];
  }

  /// Erstes Hintergrundbild, notfalls ein Querformat-Thumb.
  static ImageRef? backdrop(BaseItem item) =>
      backdrops(item).firstOrNull ?? _own(item, ImageType.thumb) ?? _seriesThumb(item) ?? _parentThumb(item);

  /// Titel-Logo (logo/clearlogo), bei Episoden und Staffeln das der Serie.
  static ImageRef? logo(BaseItem item) =>
      _own(item, ImageType.logo) ?? _ref(item, item.parentLogoItemId, ImageType.logo, item.parentLogoImageTag);

  /// ClearArt (von offiziellen Clients ungenutzt, aber hübsch für Details).
  static ImageRef? art(BaseItem item) =>
      _own(item, ImageType.art) ?? _ref(item, item.parentArtItemId, ImageType.art, item.parentArtImageTag);

  static ImageRef? banner(BaseItem item) => _own(item, ImageType.banner);

  static ImageRef? person(Person person) {
    final tag = person.primaryImageTag;
    if (tag == null) return null;
    return ImageRef(person.id, ImageType.primary, tag, blurHash: person.blurHash);
  }
}
