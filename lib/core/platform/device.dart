import 'dart:io';

/// Desktop (Windows, macOS): eigenes Fenster mit Titelleiste, Maus und Tastatur.
final bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// iPhone/iPad: Bedienung per Touch, kein Fenster, sichere Bereiche (Notch, Home-Leiste).
final bool isMobile = Platform.isIOS || Platform.isAndroid;

/// Apple-Systeme (macOS, iOS): Systemschrift, Schlüsselbund, ⌘-Kürzel.
final bool isApple = Platform.isMacOS || Platform.isIOS;
