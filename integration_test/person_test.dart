// Prüft die Personenseite gegen den Demo-Server: Besetzung anklicken,
// Lebensdaten, Biografie, Filter Filme/Serien, Gastauftritte.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/person_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/person/person_screen.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:window_manager/window_manager.dart';

const _server = 'http://localhost:8097';

class _DemoSession extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    serverUrl: _server,
    serverName: 'Demo-Server',
    userId: 'user1',
    userName: 'Demo',
    token: 'mock-token',
    deviceId: 'person-test',
  );
}

final _shotKey = GlobalKey();

Future<void> _saveShot(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('build/screenshots/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('Screenshot: ${file.absolute.path}');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Personenseite: aus der Besetzung öffnen, Infos, Filter', (tester) async {
    try {
      await HttpClient().getUrl(Uri.parse('$_server/System/Info/Public')).then((r) => r.close());
    } catch (_) {
      markTestSkipped('Demo-Server läuft nicht');
      return;
    }
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_DemoSession.new)],
        child: RepaintBoundary(key: _shotKey, child: const JellyflexApp()),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));

    // Detailseite → in der Besetzung auf die erste Person klicken.
    container.read(routerProvider).push('/item/movie0');
    await _pumpFor(tester, const Duration(seconds: 2));
    final cast = find.text('Lena Brandt');
    expect(cast, findsOneWidget);
    await tester.scrollUntilVisible(cast, 300, scrollable: find.byType(Scrollable).first);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(cast);
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(PersonScreen), findsOneWidget);

    // Lebensdaten und Biografie.
    expect(find.textContaining('Geboren am 10. Januar 1960'), findsOneWidget);
    expect(find.textContaining('in Hamburg, Deutschland'), findsOneWidget);
    await _saveShot(tester, 'person');
    expect(find.text('Mehr anzeigen'), findsOneWidget, reason: 'Lange Biografie ist zuerst gekürzt');

    // Filmografie: Filme und Serien, mit Filter.
    final all = find.byType(PosterCard).evaluate().length;
    debugPrint('Titel gesamt (sichtbar): $all');
    expect(all, greaterThan(0));

    final seriesChip = find.textContaining(RegExp(r'^Serien \(\d+\)$'));
    expect(seriesChip, findsOneWidget);
    final seriesCount = int.parse(RegExp(r'\d+').firstMatch((seriesChip.evaluate().single.widget as Text).data!)![0]!);
    await tester.tap(seriesChip);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byType(PosterCard).evaluate().length, seriesCount);

    await tester.tap(find.text('Mehr anzeigen'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Weniger anzeigen'), findsOneWidget);

    // Gastauftritte stehen weiter unten.
    final page = tester.widget<CustomScrollView>(
      find.descendant(of: find.byType(PersonScreen), matching: find.byType(CustomScrollView)),
    );
    page.controller!.jumpTo(page.controller!.position.maxScrollExtent);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Auftritte in einzelnen Folgen'), findsOneWidget);
    await _saveShot(tester, 'person_bottom');
  });
}
