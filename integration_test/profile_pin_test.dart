// Profil-PIN: in den Einstellungen festlegen, Benutzer wechseln, bei "Wer
// schaut?" schützt die PIN das Profil (falsche PIN → abgelehnt, richtige → offen).
// Alles in einem Temp-Speicher (testSettings), nie im echten.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/profile_pin_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/features/home/home_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.text(c).last);
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await pumpFor(tester, const Duration(milliseconds: 900));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Profil-PIN', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => testSettings())],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    // Festlegen (zweimal eingeben).
    container.read(routerProvider).push('/settings');
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('PIN festlegen'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('PIN festlegen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await saveShot(tester, 'pin_dialog');
    await _typePin(tester, '2468');
    await _typePin(tester, '2468');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(container.read(sessionProvider).value!.hasPin, isTrue);
    expect(container.read(sessionProvider).value!.pinHash, isNot(contains('2468')));

    // Benutzer wechseln → "Wer schaut?" mit Schloss.
    await container.read(sessionProvider.notifier).switchUser();
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Wer schaut?'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    await saveShot(tester, 'pin_profiles');

    // Falsche PIN.
    await tester.tap(find.text('Demo'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await _typePin(tester, '1111');
    expect(find.text('Falsche PIN'), findsOneWidget);
    expect(container.read(sessionProvider).value, isNull);

    // Richtige PIN.
    await _typePin(tester, '2468');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(container.read(sessionProvider).value?.userName, 'Demo');
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
