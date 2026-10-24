// Szenen-Vorschau auf Karten: Verweilen auf einem Poster blättert durch Trickplay-Bilder,
// ohne Trickplay durch Hintergrundbilder; ausgeschaltet passiert nichts.
//
// Voraussetzung:  dart run tool/mock_server.dart
// Start:          flutter test integration_test/hover_preview_test.dart -d windows

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyflex/app.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/core/settings.dart';
import 'package:jellyflex/widgets/hover_preview.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'test_helpers.dart';
import 'test_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Verweilen auf Postern zeigt Szenen bzw. Hintergrundbilder', (tester) async {
    if (!await demoServerRunning()) return;
    await windowManager.ensureInitialized();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(DemoSession.new), settingsProvider.overrideWith(testSettings)],
        child: RepaintBoundary(key: shotKey, child: const JellyflexApp()),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(JellyflexApp)));
    container.read(routerProvider).push('/library/lib-movies?name=Filme&type=movies');
    await pumpFor(tester, const Duration(seconds: 2));

    Finder card(String id) => find.byWidgetPredicate((w) => w is PosterCard && w.item.id == id);
    Finder preview(String id) => find.descendant(of: card(id), matching: find.byType(HoverPreview));
    double opacity(String id) => tester
        .widget<AnimatedOpacity>(find.descendant(of: preview(id), matching: find.byType(AnimatedOpacity)).first)
        .opacity;
    Iterable<String> imageUrls(String id) => tester
        .widgetList<Image>(find.descendant(of: preview(id), matching: find.byType(Image)))
        .map((i) => '${i.image}');

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    Future<void> hover(String id) async {
      await tester.ensureVisible(card(id));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(card(id))));
    }

    // Mit Trickplay: nach kurzem Verweilen Szenen, die wechseln.
    await hover('movie1');
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(opacity('movie1'), 0, reason: 'Noch nicht – erst nach kurzem Verweilen');
    await pumpFor(tester, const Duration(milliseconds: 1500));
    expect(opacity('movie1'), 1);
    expect(imageUrls('movie1').any((u) => u.contains('Trickplay')), isTrue);
    await saveShot(tester, 'hover_preview_scene');
    final firstFrame = tester
        .widget<Transform>(find.descendant(of: preview('movie1'), matching: find.byType(Transform)).last)
        .transform
        .toString();
    await pumpFor(tester, const Duration(milliseconds: 1400));
    final laterFrame = tester
        .widget<Transform>(find.descendant(of: preview('movie1'), matching: find.byType(Transform)).last)
        .transform
        .toString();
    expect(laterFrame, isNot(firstFrame), reason: 'Nächste Szene');

    // Maus weg → Vorschau blendet aus.
    await tester.sendEventToBinding(mouse.hover(const Offset(5, 300)));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(opacity('movie1'), 0);

    // Ohne Trickplay: Hintergrundbilder.
    await hover('movie7');
    await pumpFor(tester, const Duration(milliseconds: 1800));
    expect(opacity('movie7'), 1);
    expect(imageUrls('movie7').any((u) => u.contains('Backdrop')), isTrue);
    await tester.sendEventToBinding(mouse.hover(const Offset(5, 300)));
    await pumpFor(tester, const Duration(milliseconds: 600));

    // Ausgeschaltet: nichts.
    container.read(settingsProvider.notifier).update((s) => s.copyWith(hoverPreview: false));
    await hover('movie2');
    await pumpFor(tester, const Duration(milliseconds: 1800));
    expect(opacity('movie2'), 0);

    await tester.pumpWidget(const SizedBox());
  });
}
