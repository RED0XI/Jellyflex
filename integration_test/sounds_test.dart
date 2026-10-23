// Prüft die Oberflächen-Klänge: alle WAV-Dateien laden, Windows nimmt jeden
// Klang an, und "aus" in den Einstellungen schaltet sie stumm.
//
// Start:  flutter test integration_test/sounds_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/ui_sounds.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Klänge laden und abspielen', (tester) async {
    await tester.runAsync(UiSounds.preload);
    expect(UiSounds.loadedCount, UiSound.values.length, reason: 'Alle Klänge geladen');

    UiSounds.enabled = true;
    for (final sound in UiSound.values) {
      expect(UiSounds.play(sound), isTrue, reason: '${sound.file} von Windows angenommen');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    }

    UiSounds.enabled = false;
    expect(UiSounds.play(UiSound.tick), isFalse, reason: 'Ausgeschaltet → kein Klang');
    UiSounds.enabled = true;
  });
}
