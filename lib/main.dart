import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/ui_sounds.dart';
import 'core/system_certs.dart';
import 'core/redact.dart';
import 'core/app_log.dart';
import 'core/download_notify.dart';
import 'core/app_shell.dart';
import 'core/window_memory.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start aus der Sprungliste ("Weiterschauen"): Titel nach dem Anmelden fortsetzen.
  AppShell.pendingResumeId = AppShell.resumeIdFrom(args.join(' '));
  // Zugangsdaten nie in Protokolle schreiben (auch nicht aus Fehlermeldungen).
  final print = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message == null) return;
    final clean = redactSecrets(message);
    AppLog.add(clean);
    print(clean, wrapWidth: wrapWidth);
  };
  // Fehler für den (lokalen) Fehlerbericht merken.
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.add('FEHLER: ${details.exceptionAsString()}\n${details.stack.toString().split('\n').take(6).join('\n')}');
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.add('FEHLER: $error\n${stack.toString().split('\n').take(6).join('\n')}');
    return false;
  };
  MediaKit.ensureInitialized();
  UiSounds.preload();
  // Stammzertifikate für den Video-Player schon beim Start bereitlegen.
  SystemCerts.caFile();
  await windowManager.ensureInitialized();
  // Fenster wie beim letzten Mal (Größe, Lage, maximiert).
  final saved = await WindowMemory.load();

  final options = WindowOptions(
    title: 'Jellyflex',
    size: saved?.bounds.size ?? const Size(1440, 900),
    minimumSize: const Size(1024, 640),
    center: saved == null,
    // Keine backgroundColor setzen: window_manager überdeckt damit unter Windows
    // die Flutter-Oberfläche (Fenster bleibt weiß).
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    taskbarReady = true;
    if (saved != null) {
      await windowManager.setBounds(saved.bounds);
      if (saved.maximized) await windowManager.maximize();
    }
    WindowMemory.startWatching();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: JellyflexApp()));
}
