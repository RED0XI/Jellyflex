import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/power.dart';
import 'package:jellyflex/core/settings.dart';

void main() {
  tearDown(() {
    Power.mode = EnergySaver.auto;
    Power.debugSetStatus();
    Power.appActive.value = true;
  });

  test('Automatisch: spart nur im Akkubetrieb oder Stromsparmodus', () {
    Power.mode = EnergySaver.auto;
    Power.debugSetStatus();
    expect(Power.energySaving.value, isFalse);
    expect(Power.ambientMotion.value, isTrue);

    Power.debugSetStatus(battery: true);
    expect(Power.energySaving.value, isTrue);
    expect(Power.ambientMotion.value, isFalse);

    Power.debugSetStatus(lowPower: true);
    expect(Power.energySaving.value, isTrue);
  });

  test('Immer und nie gelten unabhängig vom Akku', () {
    Power.debugSetStatus(battery: true);
    Power.mode = EnergySaver.off;
    expect(Power.energySaving.value, isFalse);

    Power.debugSetStatus();
    Power.mode = EnergySaver.on;
    expect(Power.energySaving.value, isTrue);
  });

  testWidgets('Schmückende Animationen halten an, solange die App im Hintergrund ist', (tester) async {
    final controller = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1));
    final stop = Power.whileAmbient(controller, controller.repeat);
    expect(controller.isAnimating, isTrue);

    Power.appActive.value = false;
    expect(Power.ambientMotion.value, isFalse);
    expect(controller.isAnimating, isFalse);

    Power.appActive.value = true;
    expect(controller.isAnimating, isTrue);

    stop();
    controller.dispose();
  });

  test('Einstellung wird gespeichert und gelesen', () {
    const s = AppSettings(energySaver: EnergySaver.on);
    expect(AppSettings.fromJson(s.toJson()).energySaver, EnergySaver.on);
    expect(AppSettings.fromJson(const {}).energySaver, EnergySaver.auto);
  });
}
