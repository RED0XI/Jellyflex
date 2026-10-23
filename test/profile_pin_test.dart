import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/profile_pin.dart';
import 'package:jellyflex/core/secure_store.dart';
import 'package:jellyflex/core/session.dart';

void main() {
  test('PIN: nur Hash gespeichert, richtige PIN passt, falsche nicht', () async {
    final stored = await ProfilePin.hash('4711');
    expect(stored, isNot(contains('4711')));
    expect(stored.startsWith(r'pbkdf2$'), isTrue);
    expect(await ProfilePin.verify('4711', stored), isTrue);
    expect(await ProfilePin.verify('4712', stored), isFalse);
    expect(await ProfilePin.verify('4711', 'kaputt'), isFalse);
    // Gleiche PIN, anderes Salz → anderer Hash.
    expect(await ProfilePin.hash('4711'), isNot(stored));
  });

  test('PIN-Format: 4–6 Ziffern', () {
    expect(ProfilePin.isValid('1234'), isTrue);
    expect(ProfilePin.isValid('123456'), isTrue);
    expect(ProfilePin.isValid('123'), isFalse);
    expect(ProfilePin.isValid('1234567'), isFalse);
    expect(ProfilePin.isValid('12a4'), isFalse);
  });

  test('Nach 5 falschen Versuchen kurz gesperrt', () {
    const key = 'server|kind';
    for (var i = 0; i < 4; i++) {
      ProfilePin.recordFailure(key);
    }
    expect(ProfilePin.lockedFor(key), Duration.zero);
    ProfilePin.recordFailure(key);
    expect(ProfilePin.lockedFor(key).inSeconds, greaterThan(20));
    ProfilePin.recordSuccess(key);
    expect(ProfilePin.lockedFor(key), Duration.zero);
  });

  test('Profil mit PIN öffnet beim Start nicht automatisch', () async {
    final dir = Directory.systemTemp.createTempSync('jellyflex_pin_');
    final previous = SecureStore.instance;
    try {
      SecureStore.instance = SecureStore.forFile(File('${dir.path}/secure.bin'));
      final session = AuthSession(
        serverUrl: 'https://jf.example',
        serverName: 'Test',
        userId: 'kind',
        userName: 'Kind',
        token: 'tok',
        deviceId: 'd',
        pinHash: await ProfilePin.hash('1234'),
      );
      await SecureStore.instance.write(key: 'jellyflex.session', value: jsonEncode(session.toJson()));
      await SecureStore.instance.write(key: 'jellyflex.accounts', value: jsonEncode([session.toJson()]));
      final container = ProviderContainer();
      expect(await container.read(sessionProvider.future), isNull, reason: 'erst über "Wer schaut?" mit PIN');
      expect((await loadSavedAccounts()).single.hasPin, isTrue);
      // Auch direkt (z. B. nach erneuter Anmeldung) öffnet es nur mit geprüfter PIN.
      await expectLater(container.read(sessionProvider.notifier).activate(session), throwsA(isA<PinRequired>()));
      expect(container.read(sessionProvider).value, isNull);
      await container.read(sessionProvider.notifier).activate(session, pinChecked: true);
      expect(container.read(sessionProvider).value?.userId, 'kind');
      container.dispose();
    } finally {
      SecureStore.instance = previous;
      dir.deleteSync(recursive: true);
    }
  });
}
