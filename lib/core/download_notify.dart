import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/strings.dart';
import '../theme.dart';
import 'downloads.dart';

/// Wird von main() gesetzt, sobald window_manager die Taskleiste kennt.
bool taskbarReady = false;

/// Downloads, die zwischen [before] und [after] fertig geworden sind.
List<DownloadEntry> finishedDownloads(List<DownloadEntry> before, List<DownloadEntry> after) {
  final wasDone = {for (final e in before) e.key: e.isDone};
  return [
    for (final e in after)
      if (e.isDone && wasDone.containsKey(e.key) && wasDone[e.key] == false) e,
  ];
}

/// Fortschritt des laufenden Downloads (0–1) oder `null`, wenn keiner läuft.
double? runningProgress(Iterable<DownloadEntry> entries) {
  final running = entries.where((e) => e.status == DownloadStatus.downloading).firstOrNull;
  if (running == null) return null;
  return running.total > 0 ? (running.received / running.total).clamp(0.0, 1.0) : 0;
}

/// Zeigt den Download-Fortschritt am Taskleisten-Symbol. Wird ein Download
/// fertig, während die App im Hintergrund ist, blinkt ihr Taskleisten-Knopf
/// (Windows-üblich, ohne Zusatzprogramme); die Meldung erscheint, sobald man
/// zurückkommt. Im Vordergrund erscheint sie sofort.
class DownloadNotifier extends ConsumerStatefulWidget {
  const DownloadNotifier({super.key, required this.messenger, required this.child});

  final GlobalKey<ScaffoldMessengerState> messenger;
  final Widget child;

  @override
  ConsumerState<DownloadNotifier> createState() => _DownloadNotifierState();
}

class _DownloadNotifierState extends ConsumerState<DownloadNotifier> with WindowListener {
  bool _focused = true;
  final _waiting = <String>[];
  int _lastPercent = -1;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isFocused().then((f) => _focused = f).catchError((_) => true);
    ref.listenManual(downloadsProvider, (before, after) => _onChange(before ?? const [], after));
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _setTaskbarProgress(null);
    super.dispose();
  }

  void _onChange(List<DownloadEntry> before, List<DownloadEntry> after) {
    final manager = ref.read(downloadsProvider.notifier);
    _setTaskbarProgress(runningProgress(after.where(manager.isMine)));
    final finished = finishedDownloads(before, after).where(manager.isMine).map((e) => e.name).toList();
    if (finished.isEmpty) return;
    if (_focused) {
      _show(finished);
    } else {
      _waiting.addAll(finished);
      _flashTaskbar(true);
    }
  }

  void _setTaskbarProgress(double? progress) {
    // window_manager legt die Taskleisten-Schnittstelle erst in waitUntilReadyToShow an –
    // ohne sie (z. B. in Tests) stürzt der Aufruf ab.
    if (!taskbarReady) return;
    final percent = progress == null ? -1 : (progress * 100).round();
    if (percent == _lastPercent) return;
    _lastPercent = percent;
    windowManager.setProgressBar(progress ?? -1).catchError((_) {});
  }

  void _show(List<String> names) {
    widget.messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(names.length == 1 ? tr.downloadFinished(names.first) : tr.downloadsFinished(names.length)),
        behavior: SnackBarBehavior.floating,
        width: 460,
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void onWindowFocus() {
    _focused = true;
    if (_waiting.isNotEmpty) {
      _flashTaskbar(false);
      _show(List.of(_waiting));
      _waiting.clear();
    }
  }

  @override
  void onWindowBlur() => _focused = false;

  /// Taskleisten-Knopf blinken lassen, bis das Fenster wieder vorne ist (FlashWindowEx).
  Future<void> _flashTaskbar(bool on) async {
    try {
      final hwnd = await windowManager.getId();
      final info = calloc<_FlashInfo>();
      try {
        info.ref
          ..cbSize = sizeOf<_FlashInfo>()
          ..hwnd = hwnd
          ..dwFlags = on ? _flashTray | _flashUntilForeground : _flashStop
          ..uCount = 0
          ..dwTimeout = 0;
        _flashWindowEx(info);
      } finally {
        calloc.free(info);
      }
    } catch (e) {
      debugPrint('Taskleiste blinkt nicht: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _flashStop = 0;
const _flashTray = 2;
const _flashUntilForeground = 12;

final class _FlashInfo extends Struct {
  @Uint32()
  external int cbSize;
  @IntPtr()
  external int hwnd;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int uCount;
  @Uint32()
  external int dwTimeout;
}

final _flashWindowEx = DynamicLibrary.open('user32.dll')
    .lookupFunction<Int32 Function(Pointer<_FlashInfo>), int Function(Pointer<_FlashInfo>)>('FlashWindowEx');
