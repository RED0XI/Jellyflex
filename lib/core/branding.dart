import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings.dart';

/// Eigener App-Name und eigenes Logo – überall dort, wo sonst "Jellyflex" steht
/// (Titelleiste, Fenstertitel, Taskleisten-Symbol, Anmeldung, Start).

const defaultAppName = 'Jellyflex';

/// Angezeigter Name: eigener Name oder "Jellyflex".
String appDisplayName(AppSettings s) {
  final name = s.appName?.trim() ?? '';
  return name.isEmpty ? defaultAppName : name;
}

/// Eigenes Logo (Datei) oder `null`, falls keins gesetzt oder die Datei fehlt.
File? customLogo(AppSettings s) {
  final path = s.logoPath;
  if (path == null) return null;
  final file = File(path);
  return file.existsSync() ? file : null;
}

/// Taskleisten-Symbol (.ico) zum Logo.
String _iconPathFor(String logoPath) => '${logoPath.substring(0, logoPath.lastIndexOf('.'))}.ico';

/// Kopiert ein gewähltes Bild in den App-Datenordner und erzeugt daraus ein
/// Taskleisten-Symbol. Liefert den Pfad der Kopie (für [AppSettings.logoPath]).
///
/// Jede Wahl bekommt einen neuen Dateinamen, damit kein altes Bild aus dem
/// Zwischenspeicher angezeigt wird; ältere Logos werden aufgeräumt.
Future<String> importLogo(String sourcePath, {Directory? dir}) async {
  final source = File(sourcePath);
  // Riesige Dateien gar nicht erst laden (ein Logo braucht keine 20 MB).
  if (await source.length() > 20 * 1024 * 1024) throw const FormatException('Bild zu groß');
  final ext = sourcePath.split('.').last.toLowerCase();
  if (!const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(ext)) throw const FormatException('Kein Bild');
  final bytes = await source.readAsBytes();
  // Prüfen, ob es ein lesbares Bild ist – verkleinert dekodiert (fürs Symbol reichen 512 px).
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final scale = math.min(1.0, 512 / math.max(w, h));
      return ui.TargetImageSize(width: (w * scale).round(), height: (h * scale).round());
    },
  );
  // Den Puffer gibt instantiateImageCodecWithSize selbst frei.
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }

  final folder = dir ?? appDataDir;
  await folder.create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final target = File('${folder.path}\\logo_$stamp.$ext');
  await target.writeAsBytes(bytes);
  try {
    await File(_iconPathFor(target.path)).writeAsBytes(await _icoFrom(image));
  } finally {
    image.dispose();
  }

  // Alte Logos löschen.
  await for (final f in folder.list()) {
    final name = f.uri.pathSegments.last;
    if (f is File && name.startsWith('logo_') && !name.startsWith('logo_$stamp.')) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
  return target.path;
}

/// Quadratisches 256-px-Symbol (Bild mittig, Rand transparent) als .ico mit PNG-Inhalt.
Future<Uint8List> _icoFrom(ui.Image image) async {
  const size = 256;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final scale = math.min(size / image.width, size / image.height);
  final w = image.width * scale;
  final h = image.height * scale;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH((size - w) / 2, (size - h) / 2, w, h),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final square = await picture.toImage(size, size);
  picture.dispose();
  final png = (await square.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  square.dispose();

  // ICO-Kopf (6 Byte) + ein Eintrag (16 Byte), danach die PNG-Daten.
  final header = ByteData(22)
    ..setUint16(0, 0, Endian.little) // reserviert
    ..setUint16(2, 1, Endian.little) // Typ: Symbol
    ..setUint16(4, 1, Endian.little) // Anzahl Bilder
    ..setUint8(6, 0) // Breite 256
    ..setUint8(7, 0) // Höhe 256
    ..setUint8(8, 0) // Farbpalette
    ..setUint8(9, 0)
    ..setUint16(10, 1, Endian.little) // Ebenen
    ..setUint16(12, 32, Endian.little) // Bit pro Pixel
    ..setUint32(14, png.length, Endian.little)
    ..setUint32(18, 22, Endian.little); // Position der Bilddaten
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(png))
      .toBytes();
}

/// Fenstertitel und Taskleisten-Symbol an Name/Logo anpassen.
Future<void> applyWindowBranding(AppSettings s) async {
  try {
    await windowManager.setTitle(appDisplayName(s));
    final logo = customLogo(s);
    final customIcon = logo == null ? null : File(_iconPathFor(logo.path));
    final icon = customIcon != null && customIcon.existsSync()
        ? customIcon.path
        // Standard-Symbol liegt den Programmdateien bei (Flutter-Assets).
        : '${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\app_icon.ico';
    if (File(icon).existsSync()) await windowManager.setIcon(icon);
  } catch (e) {
    // Ohne Fenster (z. B. in Tests) gibt es nichts anzupassen.
    debugPrint('Fenster-Branding nicht gesetzt: $e');
  }
}
