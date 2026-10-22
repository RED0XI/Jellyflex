import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/jellyfin_api.dart';
import 'package:jellyflex/core/models.dart';
import 'package:jellyflex/core/session.dart';
import 'package:jellyflex/features/library/library_screen.dart';

class _FilterApi extends JellyfinApi {
  _FilterApi() : super(baseUrl: 'http://localhost', deviceId: 'd', token: 't', userId: 'u');

  final requests = <Map<String, Object?>>[];

  @override
  Future<List<String>> getGenres(String? parentId, {String includeItemTypes = 'Movie,Series'}) async => [
    'Action',
    'Drama',
  ];

  @override
  Future<LibraryPage> getLibraryPage({
    required String parentId,
    required String includeItemTypes,
    required String sortBy,
    required String sortOrder,
    int startIndex = 0,
    int limit = 100,
    List<String> filters = const [],
    String? genre,
    List<int> years = const [],
    String? nameStartsWith,
    String? nameLessThan,
  }) async {
    requests.add({
      'filters': filters.join(','),
      'genre': genre,
      'years': years.isEmpty ? null : '${years.first}-${years.last}',
      'start': nameStartsWith,
      'less': nameLessThan,
      'sort': sortBy,
    });
    final items = [
      for (var i = 0; i < 3; i++) BaseItem({'Id': 'm$i', 'Name': 'Film $i', 'Type': 'Movie', 'ProductionYear': 2001}),
    ];
    return LibraryPage(items, items.length);
  }
}

void main() {
  Future<_FilterApi> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final api = _FilterApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: LibraryScreen(libraryId: 'lib', name: 'Filme', collectionType: 'movies'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('Filter werden an den Server übergeben', (tester) async {
    final api = await pump(tester);
    expect(api.requests.last['filters'], '');

    await tester.tap(find.text('Ungesehen'));
    await tester.pumpAndSettle();
    expect(api.requests.last['filters'], 'IsUnplayed');

    await tester.tap(find.text('Favoriten'));
    await tester.pumpAndSettle();
    expect(api.requests.last['filters'], 'IsUnplayed,IsFavorite');

    await tester.tap(find.text('Genre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drama').last);
    await tester.pumpAndSettle();
    expect(api.requests.last['genre'], 'Drama');

    await tester.tap(find.text('Jahrzehnt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('90er').last);
    await tester.pumpAndSettle();
    expect(api.requests.last['years'], '1990-1999');

    await tester.tap(find.text('K'));
    await tester.pumpAndSettle();
    expect(api.requests.last['start'], 'K');

    await tester.tap(find.text('#'));
    await tester.pumpAndSettle();
    expect(api.requests.last['start'], isNull);
    expect(api.requests.last['less'], 'A');

    await tester.tap(find.text('Filter zurücksetzen').first);
    await tester.pumpAndSettle();
    expect(api.requests.last, {
      'filters': '',
      'genre': null,
      'years': null,
      'start': null,
      'less': null,
      'sort': 'SortName',
    });
  });
}
