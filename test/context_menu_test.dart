import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/widgets/media_cards.dart';
import 'package:jellyflex/l10n/strings.dart';
import 'package:jellyflex/core/settings.dart';

class _RecordingApi extends JellyfinApi {
  _RecordingApi() : super(baseUrl: 'http://localhost', deviceId: 'd', token: 't', userId: 'u');

  final calls = <String>[];

  @override
  Future<void> clearResumePosition(String itemId) async => calls.add('forget:$itemId');

  @override
  Future<void> setPlayed(String id, bool played) async => calls.add('played:$id:$played');

  @override
  Future<void> setFavorite(String id, bool favorite) async => calls.add('favorite:$id:$favorite');
}

/// Einstellungen nur im Speicher – Tests lesen nie die echte Einstellungsdatei.
class _MemorySettings extends SettingsController {
  @override
  AppSettings build() => const AppSettings(language: AppLanguage.de);
}

void main() {
  // Diese Tests prüfen die deutschen Texte.
  setUp(() => appLanguage = AppLanguage.de);

  final episode = BaseItem({
    'Id': 'ep1',
    'Name': 'Gegenwind',
    'Type': 'Episode',
    'SeriesId': 's1',
    'SeriesName': 'Nordlicht',
    'IndexNumber': 4,
    'ParentIndexNumber': 1,
    'RunTimeTicks': 30000000000,
    'UserData': {'PlaybackPositionTicks': 9000000000, 'Played': false, 'IsFavorite': false},
  });

  Future<_RecordingApi> pumpCard(WidgetTester tester) async {
    final api = _RecordingApi();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(child: LandscapeCard(item: episode)),
          ),
        ),
        GoRoute(path: '/play/:id', builder: (_, s) => Text('PLAYER ${s.uri}')),
        GoRoute(path: '/item/:id', builder: (_, s) => Text('DETAILS ${s.pathParameters['id']}')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api), settingsProvider.overrideWith(_MemorySettings.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return api;
  }

  Future<void> rightClickCard(WidgetTester tester) async {
    await tester.tap(find.text('Nordlicht').last, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('Rechtsklick zeigt passende Einträge', (tester) async {
    await pumpCard(tester);
    await rightClickCard(tester);
    expect(find.text('Fortsetzen'), findsOneWidget);
    expect(find.text('Von vorne abspielen'), findsOneWidget);
    expect(find.text('Zur Serie'), findsOneWidget);
    expect(find.text('Bereits angeschaut'), findsOneWidget);
    expect(find.text('Aus Weiterschauen entfernen'), findsOneWidget);
  });

  testWidgets('"Aus Weiterschauen entfernen" setzt den Fortschritt zurück', (tester) async {
    final api = await pumpCard(tester);
    await rightClickCard(tester);
    await tester.tap(find.text('Aus Weiterschauen entfernen'));
    await tester.pumpAndSettle();
    expect(api.calls, ['forget:ep1']);
    expect(find.text('Aus „Weiterschauen“ entfernt'), findsOneWidget);
  });

  testWidgets('"Bereits angeschaut" markiert als gesehen', (tester) async {
    final api = await pumpCard(tester);
    await rightClickCard(tester);
    await tester.tap(find.text('Bereits angeschaut'));
    await tester.pumpAndSettle();
    expect(api.calls, ['played:ep1:true']);
  });

  testWidgets('"Fortsetzen" startet an der gespeicherten Stelle', (tester) async {
    await pumpCard(tester);
    await rightClickCard(tester);
    await tester.tap(find.text('Fortsetzen'));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER /play/ep1?start=9000000000'), findsOneWidget);
  });
}
