import 'package:flutter/widgets.dart';

/// Meldet Seitenwechsel – z. B. damit der Banner-Trailer stoppt, sobald eine
/// andere Seite geöffnet wird. Im Router registriert (app.dart).
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// Zählt offene Dialoge und Menüs (Popup-Seiten) im Seiten-Navigator.
class PopupTracker extends NavigatorObserver {
  /// Anzahl gerade offener Dialoge/Menüs.
  final open = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) open.value++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) open.value = (open.value - 1).clamp(0, 1 << 20);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) open.value = (open.value - 1).clamp(0, 1 << 20);
  }
}

final popupTracker = PopupTracker();
