import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Energiesparen: automatisch (Mac: im Akkubetrieb oder Stromsparmodus; iPhone/iPad: nur im
/// Stromsparmodus – sie laufen fast immer auf Akku), immer oder nie.
enum EnergySaver { auto, on, off }

/// Stromversorgung und was daraus für die Oberfläche folgt (Gegenstücke: macos/Runner/Power.swift,
/// ios/Runner/Power.swift).
///
/// Jede laufende Animation lässt Flutter jedes Bild neu zeichnen – auf ProMotion-Displays
/// bis zu 120-mal pro Sekunde, auch wenn sich kaum etwas bewegt. Deshalb zwei Schalter:
/// - [energySaving]: Energiesparen gilt gerade – keine Trailer im Banner, kein Ambilight,
///   keine Szenen-Vorschau, einfachere Bildskalierung im Player, keine Dauer-Animationen.
/// - [ambientMotion]: rein schmückende Dauer-Animationen (Partikel, wandernde Farbflächen …)
///   dürfen laufen – nicht beim Energiesparen und nicht, solange eine andere App vorne ist.
abstract final class Power {
  static const _channel = MethodChannel('jellyflex/power');

  static EnergySaver _mode = EnergySaver.auto;
  static bool _battery = false;
  static bool _lowPower = false;
  static AppLifecycleListener? _lifecycle;

  /// Energiesparen gilt gerade (Einstellung + Akku/Stromsparmodus).
  static final ValueNotifier<bool> energySaving = ValueNotifier(false);

  /// Jellyflex ist die App im Vordergrund.
  static final ValueNotifier<bool> appActive = ValueNotifier(true)..addListener(_update);

  /// Jellyflex ist zu sehen – auch wenn kurz das Kontrollzentrum o. Ä. darüber liegt (iOS:
  /// "inactive"). `false` erst, wenn die App im Hintergrund bzw. das Fenster verdeckt ist.
  static final ValueNotifier<bool> appVisible = ValueNotifier(true);

  /// Schmückende Dauer-Animationen dürfen laufen.
  static final ValueNotifier<bool> ambientMotion = ValueNotifier(true);

  /// Läuft der Mac gerade auf Akku (oder im Stromsparmodus)?
  static bool get onBattery => _battery || _lowPower;

  /// Einmal beim Start (nach `WidgetsFlutterBinding.ensureInitialized`).
  static Future<void> init() async {
    final state = WidgetsBinding.instance.lifecycleState;
    appActive.value = state == null || state == AppLifecycleState.resumed;
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        appActive.value = state == AppLifecycleState.resumed;
        appVisible.value = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
      },
    );
    _update();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _setStatus(call.arguments);
    });
    try {
      _setStatus(await _channel.invokeMethod<Object?>('status'));
    } on MissingPluginException {
      // Ohne Runner mit dem Kanal (Windows, Tests): gilt als Netzbetrieb.
    } catch (e) {
      debugPrint('Stromversorgung unbekannt: $e');
    }
  }

  /// Aus den Einstellungen gesetzt.
  static set mode(EnergySaver value) {
    _mode = value;
    _update();
  }

  /// Nur für Tests: so tun, als hätte sich die Stromversorgung geändert.
  @visibleForTesting
  static void debugSetStatus({bool battery = false, bool lowPower = false}) =>
      _setStatus({'battery': battery, 'lowPower': lowPower});

  static void _setStatus(Object? status) {
    if (status is! Map) return;
    _battery = status['battery'] == true;
    _lowPower = status['lowPower'] == true;
    _update();
  }

  static void _update() {
    energySaving.value = switch (_mode) {
      EnergySaver.on => true,
      EnergySaver.off => false,
      EnergySaver.auto => Platform.isIOS ? _lowPower : onBattery,
    };
    ambientMotion.value = !energySaving.value && appActive.value;
  }

  /// Lässt [controller] nur laufen, solange [ambientMotion] es erlaubt: [start] (z. B.
  /// `controller.repeat()`) setzt dort fort, wo die Animation angehalten wurde.
  /// Gibt die Abmeldung zurück (in `dispose` aufrufen).
  static VoidCallback whileAmbient(AnimationController controller, VoidCallback start) {
    void sync() => ambientMotion.value ? start() : controller.stop(canceled: false);
    ambientMotion.addListener(sync);
    sync();
    return () => ambientMotion.removeListener(sync);
  }
}
