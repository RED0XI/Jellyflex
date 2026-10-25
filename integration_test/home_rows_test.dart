// Startseite anpassen: Reihen umsortieren und ausblenden (Einstellungen),
// Merkliste als eigene Reihe.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/home_rows_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/lists.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/widgets/media_row.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

List<String?> _rowTitles() => find.byType(MediaRow).evaluate().map((e) => (e.widget as MediaRow).title).toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Reihen der Startseite', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(() => testSettings())],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    final home = tester.widget<CustomScrollView>(find.byType(CustomScrollView).first);
    home.controller!.jumpTo(600);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(_rowTitles().first, 'Weiterschauen');

    // Merkliste füllen → eigene Reihe (Standard: nach "Als Nächstes").
    await tester.runAsync(
      () => container.read(listsProvider).toggleWatchlist(BaseItem({'Id': 'movie4', 'Name': 'x', 'Type': 'Movie'})),
    );
    // "Weiterschauen" ausblenden, Favoriten nach vorn.
    container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(homeRows: ['favorites', '!resume', 'nextUp', 'watchlist']));
    await pumpFor(tester, const Duration(seconds: 2));
    final titles = _rowTitles();
    debugPrint('Reihen: $titles');
    expect(titles.first, 'Deine Favoriten');
    expect(titles, isNot(contains('Weiterschauen')));
    expect(titles, contains('Merkliste'));
    await saveShot(tester, 'home_rows');

    // Einstellungen: Dialog "Anpassen".
    container.read(routerProvider).push('/settings?section=appearance');
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Anpassen'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Anpassen'));
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(find.text('Reihen der Startseite'), findsWidgets);
    await saveShot(tester, 'home_rows_dialog');
    await tester.tap(find.text('Standard wiederherstellen'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(container.read(settingsProvider).homeRows.first, 'resume');

    // Aufräumen: Merkliste des Demo-Servers wieder leeren (andere Tests erwarten das).
    await tester.runAsync(
      () => container.read(listsProvider).toggleWatchlist(BaseItem({'Id': 'movie4', 'Name': 'x', 'Type': 'Movie'})),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
