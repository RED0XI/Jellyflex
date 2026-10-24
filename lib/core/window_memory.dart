import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/window_frame.dart';
import 'platform/app_paths.dart';

/// Merkt sich Größe, Lage und "maximiert" des Fensters über Neustarts hinweg
/// (`window.json` neben den Einstellungen). Vollbild und Mini-Player zählen nicht.
abstract final class WindowMemory {
  /// Nur die echte App speichert – Tests sollen die Datei des Benutzers nicht verändern.
  static bool enabled = false;

  static File get _file => File(AppPaths.join(AppPaths.appData.path, 'window.json'));
  static Timer? _saveTimer;

  /// Letzte normale (nicht maximierte) Lage – damit "Wiederherstellen" nach einem Neustart passt.
  static Rect? _normal;

  /// Zuletzt geschriebener Inhalt (nur bei Änderungen neu schreiben).
  static String? _written;

  /// Gespeicherte Lage – nur wenn sie noch auf einen angeschlossenen Bildschirm passt.
  static Future<({Rect bounds, bool maximized})?> load() async {
    try {
      if (!_file.existsSync()) return null;
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      double n(String key) => (json[key] as num).toDouble();
      final bounds = Rect.fromLTWH(n('x'), n('y'), n('width'), n('height'));
      if (bounds.width < 400 || bounds.height < 300 || bounds.width > 10000 || bounds.height > 10000) return null;
      // Bildschirm abgesteckt? Dann lieber mittig auf dem Hauptbildschirm.
      final titleBar = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 40);
      final displays = await screenRetriever.getAllDisplays();
      final visible = displays.any((d) {
        final area = (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
        final overlap = area.intersect(titleBar);
        return overlap.width >= 120 && overlap.height >= 20;
      });
      if (!visible) return null;
      _normal = bounds;
      return (bounds: bounds, maximized: json['maximized'] == true);
    } catch (_) {
      return null;
    }
  }

  /// Ab jetzt speichern. Das Fenster meldet nur Ziehen mit der Maus und Maximieren –
  /// Andocken (Windows-Taste + Pfeil) nicht. Deshalb zusätzlich alle paar Sekunden nachsehen.
  static void startWatching() {
    enabled = true;
    Timer.periodic(const Duration(seconds: 3), (_) => _save());
  }

  /// Nach Verschieben/Größe ändern gebündelt speichern.
  static void scheduleSave() {
    if (!enabled) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  static Future<void> _save() async {
    if (windowFullscreen.value || windowMiniPlayer.value) return;
    try {
      final maximized = await windowManager.isMaximized();
      if (!maximized && !await windowManager.isMinimized()) _normal = await windowManager.getBounds();
      final normal = _normal;
      if (normal == null) return;
      final content = jsonEncode({
        'x': normal.left,
        'y': normal.top,
        'width': normal.width,
        'height': normal.height,
        'maximized': maximized,
      });
      if (content == _written) return;
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(content);
      _written = content;
    } catch (_) {
      // Nicht schlimm – dann startet das Fenster beim nächsten Mal mittig.
    }
  }
}
