import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/app_shell.dart';

void main() {
  test('Sprungliste: nur harmlose Kennungen werden übernommen', () {
    expect(AppShell.resumeIdFrom('--resume=abc123'), 'abc123');
    expect(AppShell.resumeIdFrom(r'"C:\x\jellyflex.exe" --resume=movie_5'), 'movie_5');
    expect(AppShell.resumeIdFrom('--resume=../../etc'), isNull);
    expect(AppShell.resumeIdFrom('--resume=abc?x=1'), isNull);
    expect(AppShell.resumeIdFrom('--resume=abc/def'), isNull);
    expect(AppShell.resumeIdFrom('etwas anderes'), isNull);
  });
}
