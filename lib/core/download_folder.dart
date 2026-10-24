import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'platform/app_paths.dart';

/// Download-Ordner: Standardort, Prüfung eines selbst gewählten Ordners und
/// freier Speicherplatz.
abstract final class DownloadFolder {
  /// Standardordner: Videos\Jellyflex im Benutzerprofil (macOS: ~/Movies/Jellyflex).
  static String get defaultPath => AppPaths.join(AppPaths.videos, subfolder);

  /// Unterordner, den die App im gewählten Ordner anlegt – so landen die
  /// Downloads nie lose zwischen eigenen Dateien (und Löschen trifft nur sie).
  static const subfolder = 'Jellyflex';

  /// Aus dem gewählten Ordner wird `<Ordner>\Jellyflex` (außer er heißt schon so).
  static String fromPicked(String picked, {bool? windows}) {
    final win = windows ?? Platform.isWindows;
    final sep = win ? '\\' : '/';
    // Kürzester Pfad, der stehen bleibt: "D:\" bzw. "/".
    final minLength = win ? 3 : 1;
    var path = win ? picked.replaceAll('/', sep) : picked;
    while (path.endsWith(sep) && path.length > minLength) {
      path = path.substring(0, path.length - 1);
    }
    final last = path.split(sep).where((s) => s.isNotEmpty).lastOrNull ?? '';
    if (last.toLowerCase() == subfolder.toLowerCase()) return path;
    return path.endsWith(sep) ? '$path$subfolder' : '$path$sep$subfolder';
  }

  /// Systemordner, in denen Downloads nichts verloren haben.
  static List<String> get _forbidden {
    if (Platform.isWindows) {
      return [
        for (final name in ['SystemRoot', 'windir', 'ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432', 'ProgramData'])
          ?Platform.environment[name],
        ?Platform.environment['APPDATA'],
        ?Platform.environment['LOCALAPPDATA'],
      ];
    }
    return [
      '/System',
      '/Library',
      '/Applications',
      '/usr',
      '/bin',
      '/sbin',
      '/etc',
      '/var',
      '/private',
      '/opt',
      '/dev',
      '/cores',
      // Einstellungen und Zwischenspeicher aller Programme (auch dieser App).
      AppPaths.join(AppPaths.home, 'Library'),
    ];
  }

  static String _norm(String p) {
    final sep = Platform.pathSeparator;
    var s = (Platform.isWindows ? p.replaceAll('/', sep) : p).toLowerCase();
    while (s.endsWith(sep)) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Liegt [path] in einem Systemordner (oder ist er selbst einer)?
  static bool isForbidden(String path) {
    final sep = Platform.pathSeparator;
    final target = _norm(path);
    if (target.split(sep).contains('..')) return true;
    // Ohne festen Anfang (relativer Pfad) – unklar, wo er landet.
    if (!Platform.isWindows && !target.startsWith('/')) return true;
    // Das Wurzelverzeichnis selbst.
    if (!Platform.isWindows && target.isEmpty) return true;
    for (final f in _forbidden) {
      final base = _norm(f);
      if (base.isEmpty) continue;
      if (target == base || target.startsWith('$base$sep')) return true;
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
      final probe = File(AppPaths.join(dir.path, '.jellyflex-probe-$pid-${DateTime.now().microsecondsSinceEpoch}'));
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
    if (!Platform.isWindows && !Platform.isMacOS) return null;
    var dir = Directory(path).absolute;
    while (!dir.existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
    if (Platform.isMacOS) return _freeBytesPosix(dir.path);
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

  /// macOS: `df` (POSIX-Ausgabe in KiB) – Spalte "Available" des Laufwerks.
  static int? _freeBytesPosix(String path) {
    try {
      final result = Process.runSync('/bin/df', ['-P', '-k', path]);
      if (result.exitCode != 0) return null;
      final lines = (result.stdout as String).trim().split('\n');
      if (lines.length < 2) return null;
      final columns = lines.last.trim().split(RegExp(r'\s+'));
      final kib = columns.length >= 4 ? int.tryParse(columns[3]) : null;
      return kib == null ? null : kib * 1024;
    } catch (_) {
      return null;
    }
  }

  static final _getDiskFreeSpaceEx = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
        int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)
      >('GetDiskFreeSpaceExW');
}
