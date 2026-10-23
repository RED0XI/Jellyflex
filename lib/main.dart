import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/ui_sounds.dart';
import 'core/system_certs.dart';
import 'core/redact.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Zugangsdaten nie in Protokolle schreiben (auch nicht aus Fehlermeldungen).
  final print = debugPrint;
  debugPrint = (message, {wrapWidth}) => print(message == null ? null : redactSecrets(message), wrapWidth: wrapWidth);
  MediaKit.ensureInitialized();
  UiSounds.preload();
  // Stammzertifikate für den Video-Player schon beim Start bereitlegen.
  SystemCerts.caFile();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    title: 'Jellyflex',
    size: Size(1440, 900),
    minimumSize: Size(1024, 640),
    center: true,
    // Keine backgroundColor setzen: window_manager überdeckt damit unter Windows
    // die Flutter-Oberfläche (Fenster bleibt weiß).
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: JellyflexApp()));
}
