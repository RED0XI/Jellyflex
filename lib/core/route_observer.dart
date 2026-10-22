import 'package:flutter/widgets.dart';

/// Meldet Seitenwechsel – z. B. damit der Banner-Trailer stoppt, sobald eine
/// andere Seite geöffnet wird. Im Router registriert (app.dart).
final appRouteObserver = RouteObserver<ModalRoute<void>>();
