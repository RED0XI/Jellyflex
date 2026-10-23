import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Die Test-Umgebung ersetzt echte HTTP-Verbindungen – hier wollen wir echte.
  HttpOverrides.global = null;

  late HttpServer server;
  late Directory dir;
  var requests = 0;
  final cache = ImageDiskCache.instance;

  setUp(() async {
    requests = 0;
    dir = Directory.systemTemp.createTempSync('jellyflex_imgcache_');
    cache
      ..directory = dir
      ..maxBytes = 1024 * 1024;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests++;
      final size = int.tryParse(req.uri.queryParameters['size'] ?? '') ?? 1000;
      if (req.uri.path == '/missing') req.response.statusCode = 404;
      if (req.uri.path != '/missing') req.response.add(Uint8List(size)..fillRange(0, size, req.uri.path.length));
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  String url(String path, [int size = 1000]) => 'http://127.0.0.1:${server.port}$path?size=$size';

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 200));

  test('Zweites Laden kommt von der Festplatte', () async {
    final first = await cache.load(url('/a'));
    await settle();
    final second = await cache.load(url('/a'));
    expect(second, first);
    expect(requests, 1);
  });

  test('Obergrenze: älteste Bilder werden gelöscht', () async {
    cache.maxBytes = 50 * 1000;
    for (var i = 0; i < 20; i++) {
      await cache.load(url('/bild$i', 5000));
      await settle();
    }
    await cache.trim();
    expect(await cache.sizeBytes(), lessThanOrEqualTo(50 * 1000));
    expect(await cache.sizeBytes(), greaterThan(0));
  });

  test('Ausgeschaltet: nichts auf der Festplatte', () async {
    cache.maxBytes = 0;
    await cache.load(url('/a'));
    await settle();
    await cache.load(url('/a'));
    expect(requests, 2);
    expect(dir.listSync(), isEmpty);
  });

  test('Fehler und zu große Bilder werden nicht gespeichert', () async {
    await expectLater(cache.load(url('/missing')), throwsA(anything));
    await expectLater(cache.load(url('/riesig', ImageDiskCache.maxImageBytes + 10)), throwsA(anything));
    await settle();
    expect(await cache.sizeBytes(), 0);
  });

  test('Leeren löscht alles', () async {
    await cache.load(url('/a'));
    await settle();
    expect(await cache.sizeBytes(), greaterThan(0));
    await cache.clear();
    expect(await cache.sizeBytes(), 0);
    await cache.load(url('/a'));
    expect(requests, 2);
  });
}
