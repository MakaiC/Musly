import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/models/models.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/screens/player/now_playing_screen.dart';
import 'package:musly/services/audio_handler.dart';
import 'package:musly/services/services.dart';
import 'package:musly/services/transcoding_service.dart';
import 'package:musly/services/tv_detection_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/common/blurred_gradient_background.dart';
import 'package:musly/widgets/common/glass_icon_button.dart';
import 'package:musly/widgets/now_playing/album_art_view.dart';
import 'package:musly/widgets/now_playing/artwork_backdrop.dart';
import 'package:provider/provider.dart';

import '../bootstrap.dart';
import '../test_helpers.dart';

const _accent = Color(0xFF007AFF);

// 1x1 transparent PNG.
final _pixel = MemoryImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

class _FakePlayer extends PlayerProvider {
  _FakePlayer(super.a, super.b, super.c, super.d, super.e, super.f, super.g);

  bool playing = true;
  bool shuffle = false;
  int toggles = 0;

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Duration get duration => const Duration(seconds: 200);
  @override
  Duration get position => const Duration(seconds: 60);
  @override
  bool get isPlaying => playing;
  @override
  bool get shuffleEnabled => shuffle;
  @override
  bool get isPlayingRadio => false;
  @override
  Song? get currentSong => Song(
        id: 's1',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        duration: 200,
        starred: true,
      );
  @override
  Future<void> togglePlayPause() async {
    toggles++;
    playing = !playing;
    notifyListeners();
  }
}

Future<_FakePlayer> _pump(WidgetTester tester, {required bool glass}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
      const MethodChannel('com.kurenai7968.volume_controller.method'),
      (call) async => call.method == 'getVolume' ? 0.5 : null);
  messenger.setMockStreamHandler(
      const EventChannel(
          'com.kurenai7968.volume_controller.volume_listener_event'),
      MockStreamHandler.inline(onListen: (_, __) {}));
  addTearDown(() {
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.kurenai7968.volume_controller.method'), null);
    messenger.setMockStreamHandler(
        const EventChannel(
            'com.kurenai7968.volume_controller.volume_listener_event'),
        null);
  });

  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final service = SubsonicService();
  final storage = StorageService();
  final cast = FakeCastService();
  final player = _FakePlayer(service, storage, cast, UpnpService(),
      MuslyAudioHandler(), JukeboxService(), TranscodingService());
  final theme = ThemeService();
  await theme.setLiquidGlass(glass);

  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<SubsonicService>.value(value: service),
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<CastService>.value(value: cast),
      ChangeNotifierProvider<UpnpService>.value(value: UpnpService()),
      ChangeNotifierProvider<JukeboxService>.value(value: JukeboxService()),
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<ThemeService>.value(value: theme),
      ChangeNotifierProvider<TvDetectionService>.value(
          value: TvDetectionService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.darkThemeWith(_accent),
      home: NowPlayingScreen(
        image: _pixel,
        title: 'Song',
        artist: 'Artist',
        heroTag: 'h',
        song: player.currentSong,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  return player;
}

/// Lets pending timers (palette extraction, lyrics) run out before teardown.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

double _artScale(WidgetTester tester) => tester
    .widget<AnimatedScale>(find.ancestor(
        of: find.byType(AlbumArtView), matching: find.byType(AnimatedScale)))
    .scale;

void main() {
  initializeTestEnvironment();

  testWidgets('glass mode: artwork backdrop and glass controls',
      (tester) async {
    final player = await _pump(tester, glass: true);

    expect(find.byType(ArtworkBackdrop), findsOneWidget);
    expect(find.byType(BlurredGradientBackground), findsNothing);
    expect(find.byType(BackdropGroup), findsOneWidget,
        reason: 'one shared backdrop read for the whole screen');
    // Close, More, favourite, add, shuffle, previous, play, next, repeat,
    // lyrics, queue.
    expect(find.byType(GlassIconButton), findsNWidgets(11));

    // Favourite uses the app accent, not the stock dark theme's purple.
    final heart = tester.widget<GlassIconButton>(find.ancestor(
        of: find.byIcon(CupertinoIcons.heart_fill),
        matching: find.byType(GlassIconButton)));
    expect(heart.color, _accent);

    // Play/pause works, and the artwork shrinks while paused.
    expect(_artScale(tester), 1.0);
    await tester.tap(find.byIcon(CupertinoIcons.pause_fill));
    await tester.pump(const Duration(milliseconds: 600));
    expect(player.toggles, 1);
    expect(_artScale(tester), lessThan(1.0));
    expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);

    // Shuffle shows its "on" state on a glass disc in the accent colour.
    final shuffleBefore = tester.widget<GlassIconButton>(find.ancestor(
        of: find.byIcon(CupertinoIcons.shuffle),
        matching: find.byType(GlassIconButton)));
    expect(shuffleBefore.persistent, isFalse);
    player.shuffle = true;
    player.notifyListeners();
    await tester.pump();
    final shuffleAfter = tester.widget<GlassIconButton>(find.ancestor(
        of: find.byIcon(CupertinoIcons.shuffle),
        matching: find.byType(GlassIconButton)));
    expect(shuffleAfter.persistent, isTrue);
    expect(shuffleAfter.color, _accent);

    await _unmount(tester);
  });

  testWidgets('classic mode is unchanged', (tester) async {
    await _pump(tester, glass: false);

    expect(find.byType(BlurredGradientBackground), findsOneWidget);
    expect(find.byType(ArtworkBackdrop), findsNothing);
    expect(find.byType(GlassIconButton), findsNothing);
    expect(find.byType(BackdropGroup), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(
      find.ancestor(
          of: find.byType(AlbumArtView), matching: find.byType(AnimatedScale)),
      findsNothing,
    );

    await _unmount(tester);
  });
}
