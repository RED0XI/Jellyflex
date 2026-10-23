import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';

const _parent = AuthSession(
  serverUrl: 'http://127.0.0.1:9',
  serverName: 'Test',
  userId: 'parent',
  userName: 'Eltern',
  token: 't',
  deviceId: 'd',
);
const _kid = AuthSession(
  serverUrl: 'http://127.0.0.1:9',
  serverName: 'Test',
  userId: 'kid',
  userName: 'Kind',
  token: 't',
  deviceId: 'd',
);

/// Anmeldung nur im Speicher (schreibt nichts in den echten Speicher).
class _TestSession extends SessionController {
  @override
  Future<AuthSession?> build() async => _parent;

  void use(AuthSession s) => state = AsyncData(s);
}

void main() {
  late Directory root;
  late ProviderContainer container;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('jellyflex_dl_sec_');
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_TestSession.new),
        downloadsProvider.overrideWith(() => DownloadManager(root)),
      ],
    );
    await container.read(sessionProvider.future);
  });

  tearDown(() {
    container.dispose();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  BaseItem movie(String id) => BaseItem({'Id': id, 'Name': 'Film', 'Type': 'Movie'});

  test('Kennungen mit Pfadzeichen werden nicht heruntergeladen', () async {
    final manager = container.read(downloadsProvider.notifier);
    await manager.enqueue(movie(r'..\..\Documents'));
    await manager.enqueue(movie('../etc'));
    await manager.enqueue(movie('C:'));
    expect(container.read(downloadsProvider), isEmpty);
  });

  test('Download-Ordner liegt im Download-Ordner und ist je Konto eindeutig', () async {
    final manager = container.read(downloadsProvider.notifier);
    await manager.enqueue(movie('abc123'));
    final entry = manager.entryFor('abc123')!;
    expect(entry.folder.startsWith(root.path), isTrue);
    expect(entry.folder, isNot('${root.path}\\abc123'), reason: 'Ordner enthält eine Konto-Kennung');
  });

  test('Ein anderes Konto sieht fremde Downloads nicht', () async {
    final manager = container.read(downloadsProvider.notifier);
    await manager.enqueue(movie('abc123'));
    expect(container.read(myDownloadsProvider), hasLength(1));

    (container.read(sessionProvider.notifier) as _TestSession).use(_kid);
    expect(manager.entryFor('abc123'), isNull);
    expect(container.read(myDownloadsProvider), isEmpty);
    expect(container.read(downloadedProvider('abc123')), isNull);
  });

  test('Löschen nie außerhalb des Download-Ordners', () async {
    // Manipulierter Eintrag in der Liste: Ordner zeigt nach außerhalb.
    final outside = Directory.systemTemp.createTempSync('jellyflex_outside_');
    File('${outside.path}\\wichtig.txt').writeAsStringSync('bitte nicht löschen');
    File('${root.path}\\downloads.json').writeAsStringSync(
      jsonEncode([
        {
          'itemId': 'evil',
          'serverUrl': _parent.serverUrl,
          'userId': _parent.userId,
          'name': 'x',
          'type': 'Movie',
          'folder': outside.path,
          'status': 'done',
        },
      ]),
    );
    final fresh = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_TestSession.new),
        downloadsProvider.overrideWith(() => DownloadManager(root)),
      ],
    );
    await fresh.read(sessionProvider.future);
    // Der manipulierte Eintrag wird gar nicht erst übernommen …
    expect(fresh.read(downloadsProvider), isEmpty);
    // … und selbst wenn: Löschen bleibt im Download-Ordner.
    await fresh.read(downloadsProvider.notifier).remove('evil');
    expect(File('${outside.path}\\wichtig.txt').existsSync(), isTrue);
    fresh.dispose();
    outside.deleteSync(recursive: true);
  });

  test('Gespeicherte Videodatei außerhalb des Download-Ordners wird ignoriert', () async {
    final folder = '${root.path}\\abc-1';
    File('${root.path}\\downloads.json').writeAsStringSync(
      jsonEncode([
        for (final (id, media) in [('good', '$folder\\media.mkv'), ('bad', r'C:\Windows\notepad.exe')])
          {
            'itemId': id,
            'serverUrl': _parent.serverUrl,
            'userId': _parent.userId,
            'name': id,
            'type': 'Movie',
            'folder': folder,
            'mediaFile': media,
            'status': 'done',
          },
      ]),
    );
    final fresh = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_TestSession.new),
        downloadsProvider.overrideWith(() => DownloadManager(root)),
      ],
    );
    await fresh.read(sessionProvider.future);
    expect(fresh.read(downloadsProvider).map((e) => e.itemId), ['good']);
    fresh.dispose();
  });
}
