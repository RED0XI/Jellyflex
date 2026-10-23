import 'package:flutter/foundation.dart';

/// Zählt hoch, wenn sich auf dem Server Inhalte geändert haben (neue Titel,
/// gesehen markiert …). Seiten mit eigener Liste – z. B. die Bibliothek –
/// hören darauf und laden ihre Einträge neu. Seiten mit Providern werden
/// direkt über `ref.invalidate` aktualisiert (siehe LiveHandler).
final contentChanged = ValueNotifier<int>(0);
