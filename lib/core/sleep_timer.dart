import 'package:flutter/foundation.dart';

enum SleepMode { off, minutes, endOfItem }

/// Schlaf-Timer: hält die Wiedergabe nach einer Zeit oder am Ende des aktuellen
/// Titels an. Gilt über "Nächste Folge" hinweg (der Player wird dabei neu gebaut).
class SleepTimer extends ChangeNotifier {
  SleepTimer._();

  static final instance = SleepTimer._();

  /// Lautstärke wird in dieser Zeit vor dem Anhalten langsam heruntergeregelt.
  static const fadeOut = Duration(seconds: 60);

  SleepMode _mode = SleepMode.off;
  DateTime? _endsAt;

  SleepMode get mode => _mode;
  bool get active => _mode != SleepMode.off;

  /// Restzeit bei [SleepMode.minutes], sonst `null`.
  Duration? get remaining {
    final end = _endsAt;
    if (_mode != SleepMode.minutes || end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void setMinutes(int minutes) {
    _mode = SleepMode.minutes;
    _endsAt = DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();
  }

  void setEndOfItem() {
    _mode = SleepMode.endOfItem;
    _endsAt = null;
    notifyListeners();
  }

  void cancel() {
    if (_mode == SleepMode.off) return;
    _mode = SleepMode.off;
    _endsAt = null;
    notifyListeners();
  }

  /// Nur für Tests: Ablaufzeit direkt setzen.
  @visibleForTesting
  void debugSetEndsAt(DateTime endsAt) {
    _mode = SleepMode.minutes;
    _endsAt = endsAt;
    notifyListeners();
  }
}
