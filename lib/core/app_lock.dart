import 'package:flutter/foundation.dart';

/// Ist die App gerade gesperrt (Profil mit PIN nach Inaktivität)? Solange `true`,
/// starten weder Sprungliste noch Fernsteuerung etwas, und der Player reagiert
/// nicht auf Medientasten oder Controller.
final appLocked = ValueNotifier<bool>(false);

/// Läuft gerade ein Video (nicht pausiert)? Dann sperrt sich die App nicht –
/// Filmschauen ohne Eingaben ist keine Abwesenheit.
final playerPlaying = ValueNotifier<bool>(false);
