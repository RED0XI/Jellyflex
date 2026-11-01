import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Desktop (Windows, macOS): eigenes Fenster mit Titelleiste, Maus und Tastatur.
final bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// iPhone/iPad: Bedienung per Touch, kein Fenster, sichere Bereiche (Notch, Home-Leiste).
final bool isMobile = Platform.isIOS || Platform.isAndroid;

/// Apple-Systeme (macOS, iOS): Systemschrift, Schlüsselbund, ⌘-Kürzel.
final bool isApple = Platform.isMacOS || Platform.isIOS;

/// Telefon (iPhone): Tab-Leiste unten, Player im Querformat. iPads gelten nicht als Telefon –
/// dort passen die Desktop-Layouts.
bool isPhone(BuildContext context) => isMobile && MediaQuery.sizeOf(context).shortestSide < 600;

/// Ausrichtungen außerhalb des Players: das iPhone bleibt hochkant (wie bei Video-Apps üblich –
/// nur der Player dreht quer), das iPad darf sich frei drehen.
List<DeviceOrientation> get mobileOrientations => isPhoneDevice ? const [DeviceOrientation.portraitUp] : const [];

/// Wie [isPhone], aber ohne BuildContext (z. B. in initState): nach der Größe des Hauptfensters.
bool get isPhoneDevice {
  if (!isMobile) return false;
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null) return false;
  return view.physicalSize.shortestSide / view.devicePixelRatio < 600;
}
