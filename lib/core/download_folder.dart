import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Download-Ordner: Standardort, Prüfung eines selbst gewählten Ordners und
/// freier Speicherplatz.
abstract final class DownloadFolder {
  /// Standardordner: Videos\Jellyflex im Benutzerprofil.
  static String get defaultPath =>
      '${Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}\\Videos\\Jellyflex';

  /// Unterordner, den die App im gewählten Ordner anlegt – so landen die
  /// Downloads nie lose zwischen eigenen Dateien (und Löschen trifft nur sie).
  static const subfolder = 'Jellyflex';

  /// Aus dem gewählten Ordner wird `<Ordner>\Jellyflex` (außer er heißt schon so).
  static String fromPicked(String picked) {
    var path = picked.replaceAll('/', '\\');
    while (path.endsWith('\\') && path.length > 3) {
      path = path.substring(0, path.length - 1);
    }
    final last = path.split('\\').where((s) => s.isNotEmpty).lastOrNull ?? '';
    if (last.toLowerCase() == subfolder.toLowerCase()) return path;
    return path.endsWith('\\') ? '$path$subfolder' : '$path\\$subfolder';
  }

  /// Systemordner, in denen Downloads nichts verloren haben.
  static List<String> get _forbidden => [
    for (final name in ['SystemRoot', 'windir', 'ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432', 'ProgramData'])
      ?Platform.environment[name],
    ?Platform.environment['APPDATA'],
    ?Platform.environment['LOCALAPPDATA'],
  ];

  static String _norm(String p) {
    var s = p.replaceAll('/', '\\').toLowerCase();
    while (s.endsWith('\\')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Liegt [path] in einem Systemordner (oder ist er selbst einer)?
  static bool isForbidden(String path) {
    final target = _norm(path);
    if (target.split('\\').contains('..')) return true;
    for (final f in _forbidden) {
      final base = _norm(f);
      if (base.isEmpty) continue;
      if (target == base || target.startsWith('$base\\')) return true;
    }
    return false;
  }

  /// Ordner anlegen und einmal zur Probe hineinschreiben.
  /// Liefert `null` bei Erfolg, sonst eine kurze Fehlerbeschreibung.
  static Future<String?> checkWritable(String path) async {
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      // Eindeutiger Name und "exclusive": eine vorhandene Datei wird nie überschrieben.
      final probe = File('${dir.path}\\.jellyflex-probe-$pid-${DateTime.now().microsecondsSinceEpoch}');
      await probe.create(exclusive: true);
      try {
        await probe.writeAsString('ok', flush: true);
      } finally {
        await probe.delete();
      }
      return null;
    } on FileSystemException catch (e) {
      return e.osError?.message ?? e.message;
    } catch (e) {
      return '$e';
    }
  }

  /// Freier Speicherplatz (Bytes) auf dem Laufwerk von [path]; `null` = unbekannt.
  /// Der Ordner selbst muss nicht existieren – es zählt der nächste vorhandene darüber.
  static int? freeBytes(String path) {
    if (!Platform.isWindows) return null;
    var dir = Directory(path).absolute;
    while (!dir.existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
    final pathPtr = dir.path.toNativeUtf16();
    final free = calloc<Uint64>();
    try {
      final ok = _getDiskFreeSpaceEx(pathPtr, free, nullptr, nullptr);
      return ok != 0 ? free.value : null;
    } catch (_) {
      return null;
    } finally {
      calloc.free(pathPtr);
      calloc.free(free);
    }
  }

  static final _getDiskFreeSpaceEx = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
        int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)
      >('GetDiskFreeSpaceExW');
}
