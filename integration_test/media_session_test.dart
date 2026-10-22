// Öffnet den Test-Player und hält ihn 25 s offen, damit man von außen prüfen
// kann, ob Windows die Wiedergabe in der Medienanzeige (SMTC) zeigt.
//
// Start:  flutter test integration_test/media_session_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/dev/player_harness.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Medienanzeige bleibt 25 s aktiv', (tester) async {
    await windowManager.ensureInitialized();
    Player? player;
    await prepareHarness(onPlayer: (p) => player = p);
    await tester.pumpWidget(buildHarnessApp());
    await tester.pump();
    await tester.tap(find.text('Test-Player öffnen'));

    final end = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(player, isNotNull);
  });
}
