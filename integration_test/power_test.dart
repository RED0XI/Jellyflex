// Prüft im echten Runner: Das System meldet die Stromversorgung (Kanal `jellyflex/power`,
// Gegenstücke: windows/runner/power.cpp, macos/Runner/Power.swift, ios/Runner/Power.swift) –
// darauf beruht "Energiesparen: im Akkubetrieb".
//
// Start:  flutter test integration_test/power_test.dart -d windows   (bzw. -d macos)

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/core/power.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jellyflex/power');

  testWidgets('Der Runner meldet Akku und Stromsparmodus', (tester) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isIOS) {
      markTestSkipped('Kein Runner mit dem Kanal');
      return;
    }
    final status = await tester.runAsync(() => channel.invokeMethod<Object?>('status'));
    expect(status, isA<Map<Object?, Object?>>());
    final map = status! as Map<Object?, Object?>;
    expect(map['battery'], isA<bool>());
    expect(map['lowPower'], isA<bool>());
  });

  testWidgets('Windows: Wechsel der Stromversorgung kommt in der App an', (tester) async {
    if (!Platform.isWindows) {
      markTestSkipped('Nur unter Windows');
      return;
    }
    final changed = Completer<Object?>();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && !changed.isCompleted) changed.complete(call.arguments);
    });
    // Danach hört wieder die App selbst zu.
    addTearDown(Power.init);

    // So meldet Windows "Netzteil an/ab" an jedes Fenster: WM_POWERBROADCAST mit
    // PBT_APMPOWERSTATUSCHANGE. Hier an das eigene Fenster geschickt.
    final user32 = DynamicLibrary.open('user32.dll');
    final findWindow = user32
        .lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>), int Function(Pointer<Utf16>, Pointer<Utf16>)>(
          'FindWindowW',
        );
    final getWindowProcess = user32
        .lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>(
          'GetWindowThreadProcessId',
        );
    final postMessage = user32
        .lookupFunction<Int32 Function(IntPtr, Uint32, IntPtr, IntPtr), int Function(int, int, int, int)>(
          'PostMessageW',
        );
    final windowClass = 'JELLYFLEX_WINDOW'.toNativeUtf16();
    final owner = calloc<Uint32>();
    try {
      final window = findWindow(windowClass, nullptr);
      expect(window, isNot(0));
      getWindowProcess(window, owner);
      expect(owner.value, pid, reason: 'Es läuft noch ein anderes Jellyflex-Fenster');
      const wmPowerBroadcast = 0x0218;
      const pbtApmPowerStatusChange = 0x000A;
      expect(postMessage(window, wmPowerBroadcast, pbtApmPowerStatusChange, 0), isNot(0));
    } finally {
      calloc.free(windowClass);
      calloc.free(owner);
    }

    final status = await tester.runAsync(() => changed.future.timeout(const Duration(seconds: 5)));
    expect(status, isA<Map<Object?, Object?>>());
    expect((status! as Map<Object?, Object?>)['battery'], isA<bool>());
  });
}
