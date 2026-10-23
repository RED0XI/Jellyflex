import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/download_folder.dart';
import 'package:jellyflex/core/downloads.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';

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

  /// Eigene Einstellungen im Testordner – nie die echten.
  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(_TestSession.new),
      settingsProvider.overrideWith(
        () => SettingsController(File('${root.path}${Platform.pathSeparator}settings.json')),
      ),
      downloadsProvider.overrideWith(() => DownloadManager(root, () async => false)),
    ],
  );

  String folderName(String id) => DownloadManager.folderNameFor(id, _parent.serverUrl, _parent.userId);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('jellyflex_dl_sec_');
    container = makeContainer();
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
    expect(
      entry.folder,
      isNot('${root.path}${Platform.pathSeparator}abc123'),
      reason: 'Ordner enthält eine Konto-Kennung',
    );
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
    File('${outside.path}${Platform.pathSeparator}wichtig.txt').writeAsStringSync('bitte nicht löschen');
    File('${root.path}${Platform.pathSeparator}downloads.json').writeAsStringSync(
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
    final fresh = makeContainer();
    await fresh.read(sessionProvider.future);
    // Der manipulierte Eintrag wird gar nicht erst übernommen …
    expect(fresh.read(downloadsProvider), isEmpty);
    // … und selbst wenn: Löschen bleibt im Download-Ordner.
    await fresh.read(downloadsProvider.notifier).remove('evil');
    expect(File('${outside.path}${Platform.pathSeparator}wichtig.txt').existsSync(), isTrue);
    fresh.dispose();
    outside.deleteSync(recursive: true);
  });

  test('Gespeicherte Videodatei außerhalb des Download-Ordners wird ignoriert', () async {
    File('${root.path}${Platform.pathSeparator}downloads.json').writeAsStringSync(
      jsonEncode([
        for (final (id, media) in [
          ('good', '${root.path}${Platform.pathSeparator}${folderName('good')}${Platform.pathSeparator}media.mkv'),
          ('bad', r'C:\Windows\notepad.exe'),
        ])
          {
            'itemId': id,
            'serverUrl': _parent.serverUrl,
            'userId': _parent.userId,
            'name': id,
            'type': 'Movie',
            'folder': '${root.path}${Platform.pathSeparator}${folderName(id)}',
            'mediaFile': media,
            'status': 'done',
          },
      ]),
    );
    final fresh = makeContainer();
    await fresh.read(sessionProvider.future);
    expect(fresh.read(downloadsProvider).map((e) => e.itemId), ['good']);
    fresh.dispose();
  });

  test('Ordner mit falschem Namen oder in fremdem Ordner wird ignoriert', () async {
    final other = Directory.systemTemp.createTempSync('jellyflex_other_root_');
    File('${root.path}${Platform.pathSeparator}downloads.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'roots': [root.path, other.path],
        'entries': [
          for (final (id, folder) in [
            ('inroot', '${root.path}${Platform.pathSeparator}${folderName('inroot')}'),
            ('second', '${other.path}${Platform.pathSeparator}${folderName('second')}'),
            ('wrongname', '${root.path}${Platform.pathSeparator}Dokumente'),
            ('foreign', '${Directory.systemTemp.path}${Platform.pathSeparator}${folderName('foreign')}'),
          ])
            {
              'itemId': id,
              'serverUrl': _parent.serverUrl,
              'userId': _parent.userId,
              'name': id,
              'type': 'Movie',
              'folder': folder,
              'status': 'paused',
            },
        ],
      }),
    );
    final fresh = makeContainer();
    await fresh.read(sessionProvider.future);
    expect(fresh.read(downloadsProvider).map((e) => e.itemId), ['inroot', 'second']);
    fresh.dispose();
    other.deleteSync(recursive: true);
  });

  test('Altes Listenformat wird weiter gelesen', () async {
    File('${root.path}${Platform.pathSeparator}downloads.json').writeAsStringSync(
      jsonEncode([
        {
          'itemId': 'old1',
          'serverUrl': _parent.serverUrl,
          'userId': _parent.userId,
          'name': 'Alt',
          'type': 'Movie',
          'folder': '${root.path}${Platform.pathSeparator}${folderName('old1')}',
          'status': 'paused',
        },
      ]),
    );
    final fresh = makeContainer();
    await fresh.read(sessionProvider.future);
    expect(fresh.read(downloadsProvider).map((e) => e.itemId), ['old1']);
    fresh.dispose();
  });

  test('Download-Ordner: Unterordner "Jellyflex", Systemordner gesperrt (Windows)', () {
    expect(DownloadFolder.fromPicked(r'D:\Filme', windows: true), r'D:\Filme\Jellyflex');
    expect(DownloadFolder.fromPicked(r'D:\', windows: true), r'D:\Jellyflex');
    expect(DownloadFolder.fromPicked(r'D:\Medien\jellyflex\', windows: true), r'D:\Medien\jellyflex');
    if (!Platform.isWindows) return;
    final windows = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    expect(DownloadFolder.isForbidden('$windows\\Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden('${Platform.environment['APPDATA']}${Platform.pathSeparator}Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden(r'D:\Filme\..\Windows'), isTrue);
    expect(DownloadFolder.isForbidden(r'D:\Filme\Jellyflex'), isFalse);
    expect(DownloadFolder.freeBytes(Directory.systemTemp.path), greaterThan(0));
  });

  test('Download-Ordner: Unterordner "Jellyflex", Systemordner gesperrt (macOS)', () {
    expect(DownloadFolder.fromPicked('/Volumes/Filme', windows: false), '/Volumes/Filme/Jellyflex');
    expect(DownloadFolder.fromPicked('/', windows: false), '/Jellyflex');
    expect(DownloadFolder.fromPicked('/Users/a/Movies/jellyflex/', windows: false), '/Users/a/Movies/jellyflex');
    if (!Platform.isMacOS) return;
    final home = Platform.environment['HOME']!;
    expect(DownloadFolder.isForbidden('/System/Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden('/Applications/Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden('$home/Library/Application Support/Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden('$home/Movies/../Library/Jellyflex'), isTrue);
    expect(DownloadFolder.isForbidden('/'), isTrue);
    expect(DownloadFolder.isForbidden('Filme/Jellyflex'), isTrue, reason: 'relativer Pfad');
    expect(DownloadFolder.isForbidden('$home/Movies/Jellyflex'), isFalse);
    expect(DownloadFolder.isForbidden('/Volumes/Filme/Jellyflex'), isFalse);
    expect(DownloadFolder.freeBytes(Directory.systemTemp.path), greaterThan(0));
    expect(DownloadFolder.defaultPath, '$home/Movies/Jellyflex');
  });
}
