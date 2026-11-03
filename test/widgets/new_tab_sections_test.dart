import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/models/album.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/widgets/new_tab/new_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bootstrap.dart';

/// Serves canned getAlbumList / getArtist / getRandomSongs data and counts
/// calls. Throws for a type listed in [failTypes] (then clears it, so a
/// retry succeeds).
class _FakeApi extends SubsonicService {
  _FakeApi({
    this.lists = const {},
    this.artistAlbums = const {},
    this.songs = const [],
  });

  final Map<String, List<Album>> lists;
  final Map<String, List<Album>> artistAlbums;
  final List<Song> songs;
  final Set<String> failTypes = {};
  final List<String> calls = [];

  @override
  Future<List<Album>> getAlbumList({
    String type = 'recent',
    int size = 20,
    int offset = 0,
  }) async {
    calls.add('$type@$offset');
    if (failTypes.remove(type)) throw Exception('boom');
    return (lists[type] ?? const []).skip(offset).take(size).toList();
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    calls.add('artist:$artistId');
    return artistAlbums[artistId] ?? const [];
  }

  @override
  Future<List<Song>> getRandomSongs({int size = 20, String? genre}) async {
    calls.add('random');
    return songs.take(size).toList();
  }
}

Album _album(String id, {String? artist, String? artistId, int? year}) =>
    Album(id: id, name: 'Album $id', artist: artist, artistId: artistId,
        year: year);

Future<void> _pump(WidgetTester tester, _FakeApi api, Widget child) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SubsonicService>.value(value: api),
        ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  initializeTestEnvironment();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hero carousel features the newest albums', (tester) async {
    final api = _FakeApi(lists: {
      'newest': [for (var i = 0; i < 10; i++) _album('n$i', artist: 'A')],
    });
    await _pump(tester, api, const FeaturedHeroCarousel());

    expect(api.calls, ['newest@0']);
    expect(find.text('Album n0'), findsOneWidget);
    expect(find.text('RECENTLY ADDED'), findsWidgets);
    expect(find.text('Play'), findsWidgets);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Album n1'), findsOneWidget);
  });

  testWidgets('recently added skips the albums the hero features',
      (tester) async {
    final api = _FakeApi(lists: {
      'newest': [for (var i = 0; i < 10; i++) _album('n$i')],
    });
    await _pump(tester, api, const RecentlyAddedSection(skip: 6));

    expect(api.calls, ['newest@6']);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Album n5'), findsNothing);
    expect(find.text('Album n6'), findsOneWidget);
  });

  testWidgets('fresh from artists: newest unplayed albums by top artists',
      (tester) async {
    final api = _FakeApi(
      lists: {
        'frequent': [
          _album('p1', artist: 'Alpha', artistId: 'a'),
          _album('p2', artist: 'Alpha', artistId: 'a'),
          _album('p3', artist: 'Beta', artistId: 'b'),
          _album('p4', artist: 'Various Artists', artistId: 'va'),
        ],
      },
      artistAlbums: {
        'a': [
          _album('p1', artist: 'Alpha', year: 2025),
          _album('a-old', artist: 'Alpha', year: 2001),
          _album('a-new', artist: 'Alpha', year: 2024),
          _album('a-mid', artist: 'Alpha', year: 2010),
        ],
        'b': [_album('b-new', artist: 'Beta', year: 2023)],
      },
    );
    await _pump(tester, api, const FreshFromArtistsSection());

    expect(api.calls, containsAll(['artist:a', 'artist:b']));
    expect(api.calls, isNot(contains('artist:va')));
    expect(find.text('New from Alpha and Beta'), findsOneWidget);
    // Already-played p1 is left out; two newest per artist.
    expect(find.text('Album p1'), findsNothing);
    expect(find.text('Album a-new'), findsOneWidget);
    expect(find.text('Album a-mid'), findsOneWidget);
    expect(find.text('Album a-old'), findsNothing);
    expect(find.text('Album b-new'), findsOneWidget);
  });

  testWidgets('rediscover: starred albums not played recently',
      (tester) async {
    final api = _FakeApi(lists: {
      'starred': [for (var i = 0; i < 8; i++) _album('s$i')],
      'recent': [_album('s0'), _album('s1')],
    });
    await _pump(tester, api, const RediscoverSection());

    expect(find.text('Rediscover'), findsOneWidget);
    expect(find.text('Album s0'), findsNothing);
    expect(find.text('Album s1'), findsNothing);
    // 6 candidates, so no top-up from frequent.
    expect(api.calls, isNot(contains('frequent@0')));
  });

  testWidgets('rediscover tops up from most-played when few are starred',
      (tester) async {
    final api = _FakeApi(lists: {
      'starred': [_album('s0')],
      'recent': [_album('f0')],
      'frequent': [_album('f0'), _album('f1')],
    });
    await _pump(tester, api, const RediscoverSection());

    expect(find.text('Album s0'), findsOneWidget);
    expect(find.text('Album f1'), findsOneWidget);
    expect(find.text('Album f0'), findsNothing);
  });

  testWidgets('empty state', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api, const RecentlyAddedSection());
    expect(find.text('Nothing new on your server yet.'), findsOneWidget);
  });

  testWidgets('error state retries', (tester) async {
    final api = _FakeApi(lists: {
      'newest': [_album('n0')],
    })
      ..failTypes.add('newest');
    await _pump(tester, api, const RecentlyAddedSection());

    expect(find.text('Album n0'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Album n0'), findsOneWidget);
  });

  testWidgets('mix for you shows the mix and rolls a new one',
      (tester) async {
    final api = _FakeApi(songs: [
      for (var i = 0; i < 30; i++)
        Song(id: 's$i', title: 'Song $i', artist: 'Artist ${i % 4}'),
    ]);
    await _pump(tester, api, const MixForYouSection());

    expect(find.text('Mix For You'), findsOneWidget);
    expect(find.text('25 songs'), findsOneWidget);
    expect(find.text('Artist 0, Artist 1, Artist 2 and more'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('New mix'));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c == 'random').length, 2);
  });

  testWidgets('refresh scope reloads every mounted section', (tester) async {
    final api = _FakeApi(lists: {
      'newest': [_album('n0')],
    });
    final registry = NewTabRefreshRegistry();
    await _pump(
      tester,
      api,
      NewTabRefreshScope(
        registry: registry,
        child: const Column(
          children: [RecentlyAddedSection(), MixForYouSection()],
        ),
      ),
    );
    api.calls.clear();

    await registry.refreshAll();
    await tester.pumpAndSettle();
    expect(api.calls, unorderedEquals(['newest@0', 'random']));
  });
}
