// Einmalige Prüfung (kein normaler Test): passt eine .sig zum eingebauten Schlüssel?
// Start: flutter test test/update_key_check.dart --dart-define=SIGNED=dist\Jellyflex-Setup-0.2.0.exe
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/update_check.dart';

void main() {
  const path = String.fromEnvironment('SIGNED');
  test('Signatur passt zum eingebauten Schlüssel', () async {
    if (path.isEmpty) return markTestSkipped('kein --dart-define=SIGNED=…');
    final ok = await UpdateCheck.verify(File(path).readAsBytesSync(), File('$path.sig').readAsStringSync());
    expect(ok, isTrue);
  });
}
