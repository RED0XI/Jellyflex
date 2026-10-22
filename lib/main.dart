import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
