import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/models/song.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/screens/main/add_screen.dart';
import 'package:musly/screens/main/home_screen.dart';
import 'package:musly/screens/main/library_screen.dart';
import 'package:musly/screens/main/main_screen.dart';
import 'package:musly/screens/main/main_tabs.dart';
import 'package:musly/screens/main/new_screen.dart';
import 'package:musly/screens/main/search_screen.dart';
import 'package:musly/screens/media/fantasy_screen.dart';
import 'package:musly/services/audio_handler.dart';
import 'package:musly/services/local_music_service.dart';
import 'package:musly/services/services.dart';
import 'package:musly/services/transcoding_service.dart';
import 'package:musly/widgets/navigation/glass_tab_bar.dart';
import 'package:provider/provider.dart';

import '../bootstrap.dart';
import '../test_helpers.dart';

class _FakePlayer extends PlayerProvider {
  _FakePlayer(super.a, super.b, super.c, super.d, super.e, super.f, super.g);

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Song? get currentSong =>
      Song(id: 's1', title: 'Song', artist: 'Artist', album: 'Album', duration: 200);
}

/// The real [MainScreen] with its five tabs. Mounting it twice in one process
/// throws at teardown, so both modes run in one test.
void main() {
  initializeTestEnvironment();

  testWidgets('MainTabs: Home, New, Add, Library, Search', (tester) async {
    expect(MainTabs.home, 0);
    expect(MainTabs.newTab, 1);
    expect(MainTabs.add, 2);
    expect(MainTabs.library, 3);
    expect(MainTabs.search, 4);
  });

  testWidgets('five tabs: taps, the easter egg on Search, collapsed rules',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final theme = ThemeService();
    final service = SubsonicService();
    final storage = StorageService();
    final player = _FakePlayer(service, storage, FakeCastService(),
        UpnpService(), MuslyAudioHandler(), JukeboxService(), TranscodingService());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<RecommendationService>(
            create: (_) => RecommendationService()),
        ChangeNotifierProvider<LocalMusicService>(
            create: (_) => LocalMusicService()),
      ],
      child: createTestApp(
        child: const MainScreen(),
        subsonicService: service,
        storageService: storage,
        playerProvider: player,
        themeService: theme,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException(); // Home overflows under the test font.

    Finder tab(String label) => find.descendant(
        of: find.byType(BottomNavigationBar), matching: find.text(label));
    final fantasy = find.byType(FantasyScreen, skipOffstage: false);
    Finder page<T>() => find.byType(T, skipOffstage: true);

    // ---- classic: the bottom navigation bar -------------------------------
    final items = tester
        .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
        .items;
    expect(items.map((i) => i.label), ['Home', 'New', 'Add', 'Library', 'Search']);
    expect(items[2].icon, isA<Icon>().having(
        (i) => i.icon, 'icon', CupertinoIcons.dot_radiowaves_left_right));

    BottomNavigationBar bar() =>
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(page<HomeScreen>(), findsOneWidget);

    await tester.tap(tab('Add'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bar().currentIndex, MainTabs.add);
    expect(page<AddScreen>(), findsOneWidget);

    await tester.tap(tab('Library'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bar().currentIndex, MainTabs.library);
    expect(page<LibraryScreen>(), findsOneWidget);

    await tester.tap(tab('New'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(page<NewScreen>(), findsOneWidget);
    tester.takeException();

    await tester.tap(tab('Search'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bar().currentIndex, MainTabs.search);
    expect(page<SearchScreen>(), findsOneWidget);

    // The easter egg: 11 taps on Search (index 4), nowhere else.
    for (var i = 0; i < 9; i++) {
      await tester.tap(tab('Search'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fantasy, findsNothing);
    await tester.tap(tab('Search'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fantasy, findsOneWidget);
    tester.takeException();

    // ---- glass: the tab bar -----------------------------------------------
    // Back out of the easter egg, then switch the glass theme on.
    final nav = Navigator.of(tester.element(fantasy));
    nav.pop();
    await tester.pump(const Duration(milliseconds: 400));
    await theme.setLiquidGlass(true);
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();

    final glass = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(glass.items.map((i) => i.label), ['Home', 'New', 'Add', 'Library', 'Search']);
    expect(glass.items[MainTabs.add].icon, CupertinoIcons.dot_radiowaves_left_right);
    expect(glass.currentIndex, MainTabs.search);

    Future<void> tapGlass(int i) async {
      final bar = tester.getRect(find.byType(GlassTabBar));
      await tester.tapAt(Offset(
          bar.left + GlassTabBar.slotCentre(bar.width, 5, i), bar.center.dy));
      await tester.pump(const Duration(milliseconds: 600));
      tester.takeException();
    }

    await tapGlass(MainTabs.add);
    expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).currentIndex,
        MainTabs.add);
    expect(page<AddScreen>(), findsOneWidget);

    await tapGlass(MainTabs.library);
    expect(page<LibraryScreen>(), findsOneWidget);

    // Eleven taps on Search (index 4) open the easter egg in glass too.
    for (var i = 0; i < 11; i++) {
      await tapGlass(MainTabs.search);
    }
    expect(fantasy, findsOneWidget);

    // Unmount and drain the usage-time timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.takeException();
  });
}
