import 'dart:convert';
import 'dart:math' as math;

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
import 'package:musly/widgets/now_playing/album_art_view.dart';
import 'package:musly/widgets/now_playing/now_playing_transition.dart';
import 'package:provider/provider.dart';

import '../bootstrap.dart';
import '../test_helpers.dart';

// 1x1 transparent PNG.
final _pixel = MemoryImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

const _anchorKey = ValueKey<String>('anchor');
const _capsuleKey = ValueKey<String>('capsule');
const _openKey = ValueKey<String>('open');
const _height = 852.0;

class _FakePlayer extends PlayerProvider {
  _FakePlayer(super.a, super.b, super.c, super.d, super.e, super.f, super.g);

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Duration get duration => const Duration(seconds: 200);
  @override
  Duration get position => const Duration(seconds: 60);
  @override
  bool get isPlaying => true;
  @override
  bool get isPlayingRadio => false;
  @override
  Song? get currentSong => Song(
        id: 's1',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        duration: 200,
      );
}

/// A stand-in main screen: a "mini-player" capsule near the bottom with its
/// art square at the leading end (where the real one sits) and a button that opens the player the way the
/// mini-player does.
Future<void> _pump(WidgetTester tester,
    {bool glass = false, bool reduceMotion = false}) async {
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

  tester.view.physicalSize = const Size(393 * 3, _height * 3);
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
      theme: AppTheme.darkThemeWith(const Color(0xFF007AFF)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Stack(
            children: [
              Center(
                child: TextButton(
                  key: _openKey,
                  onPressed: () => Navigator.of(context).push(
                    NowPlayingRoute<void>(
                      builder: (_) => NowPlayingScreen(
                        image: _pixel,
                        title: 'Song',
                        artist: 'Artist',
                        heroTag: 'h',
                        song: player.currentSong,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 100,
                height: 60,
                child: NowPlayingCapsuleAnchor(
                  key: _capsuleKey,
                  child: ColoredBox(
                    color: Colors.grey,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: NowPlayingArtAnchor(
                          key: _anchorKey,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: ColoredBox(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ));
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
}

NowPlayingTransitionState _state(WidgetTester tester) =>
    tester.state<NowPlayingTransitionState>(find.byType(NowPlayingTransition));

double _p(WidgetTester tester) => _state(tester).progress.value;

Rect _anchorRect(WidgetTester tester) => tester.getRect(find.byKey(_anchorKey));

NowPlayingFrame _frame(WidgetTester tester) => _state(tester).frame;

Rect? _flyingRect(WidgetTester tester) {
  final f = find.byKey(NowPlayingTransition.flyingArtKey);
  return f.evaluate().isEmpty ? null : tester.getRect(f);
}

bool _anchorVisible(WidgetTester tester) => tester
    .widget<Visibility>(find.descendant(
        of: find.byKey(_anchorKey), matching: find.byType(Visibility)))
    .visible;

bool _visible(WidgetTester tester, Finder of) => tester
    .widget<Visibility>(
        find.ancestor(of: of, matching: find.byType(Visibility)).first)
    .visible;

/// Pumps ~[ms] of 120 Hz frames, reporting p after each.
Future<void> _frames(WidgetTester tester, int ms,
    [void Function(double p)? onFrame]) async {
  for (var t = 0; t < ms; t += 8) {
    await tester.pump(const Duration(milliseconds: 8));
    if (onFrame != null &&
        find.byType(NowPlayingTransition).evaluate().isNotEmpty) {
      onFrame(_p(tester));
    }
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  initializeTestEnvironment();

  group('NowPlayingTransition geometry', () {
    const full = Size(393, _height);
    const capsule = Rect.fromLTWH(12, 692, 369, 60);
    const travel = 692.0;
    const src = Rect.fromLTWH(24, 702, 40, 40);
    const dest = Rect.fromLTWH(32, 120, 329, 329);
    const b = kNowPlayingMergeStart;
    NowPlayingFrame open(double p) =>
        NowPlayingTransition.openFrame(p, full, capsule, 30);
    NowPlayingFrame close(double p) =>
        NowPlayingTransition.closeFrame(p, full, capsule, 30);

    test('both paths are the full screen when open', () {
      for (final f in [open(1), close(1)]) {
        expect(f.sheet, Offset.zero & full);
        expect(f.radius, 0);
        expect(f.opacity, 1);
        expect(f.contentOpacity, 1);
        expect(f.glassPresence, 1);
        expect(f.neck, isNull);
      }
    });

    test('opening grows out of the capsule', () {
      final f = open(0);
      expect(f.sheet, capsule);
      expect(f.radius, 30);
      expect(f.opacity, 0);
      for (var p = 0.12; p <= 1; p += 0.01) {
        expect(open(p).opacity, 1, reason: 'p=$p');
      }
    });

    test('closing slides the opaque player all the way off the bottom', () {
      // The top edge tracks a finger 1:1 down to the screen's bottom edge.
      for (var p = b; p <= 1; p += 0.02) {
        final f = close(p);
        expect(f.sheet.top, closeTo((1 - p) / (1 - b) * _height, 0.01));
        expect(f.sheet.width, full.width);
        expect(f.opacity, 1);
        expect(f.reach, 0);
        expect(f.neck, isNull);
      }
      expect(close(b).sheet.top, closeTo(_height, 0.01));
      // No fade until the last few points above the bottom edge.
      for (var p = b + 0.06; p <= 1; p += 0.01) {
        expect(close(p).contentOpacity, 1, reason: 'p=$p');
      }
    });

    test('then merges back up into the capsule', () {
      final end = close(0);
      expect(end.sheet, capsule);
      expect(end.radius, 30);
      expect(end.opacity, 0);
      expect(end.reach, 0);
      expect(end.gulp, 0);
      // The blob rises: its top moves up as p falls.
      var prevTop = double.infinity;
      for (var p = b; p >= 0; p -= 0.01) {
        final top = close(p).sheet.top;
        expect(top, lessThanOrEqualTo(prevTop + 1e-9));
        prevTop = top;
      }
    });

    test('the capsule reaches out and a neck joins them', () {
      var maxReach = 0.0;
      var necks = 0;
      for (var p = b; p >= 0; p -= 0.002) {
        final f = close(p);
        maxReach = math.max(maxReach, f.reach);
        if (f.neck != null) {
          necks++;
          // The neck spans the gap from the stretched capsule to the blob.
          final r = f.neck!.getBounds();
          expect(r.top, closeTo(capsule.bottom + f.reach - 3, 0.01));
          expect(r.bottom, closeTo(f.sheet.top + 3, 0.01));
        }
      }
      expect(maxReach, greaterThan(11));
      expect(necks, greaterThan(10));
      expect(close(b).reach, 0);
    });

    test('glass is only present while everything is fully opaque', () {
      for (var p = -0.1; p <= 1.05; p += 0.002) {
        for (final f in [open(p), close(p)]) {
          if (f.glassPresence > 0) {
            expect(f.opacity, 1, reason: 'p=$p');
            expect(f.contentOpacity, 1, reason: 'p=$p');
          }
        }
      }
    });

    test('the capsule swells as it swallows, settled at the ends', () {
      expect(close(0).gulp, 0);
      expect(close(1).gulp, 0);
      expect(close(b * 0.175).gulp, closeTo(1, 1e-9));
      expect(close(-0.03).gulp, 1);
      expect(open(0.1).gulp, closeTo(1, 1e-9));
    });

    test('opening art starts on the source and ends on the destination', () {
      expect(NowPlayingTransition.artRect(0, src, dest, travel), src);
      expect(NowPlayingTransition.artRect(1, src, dest, travel), dest);
      Rect prev = NowPlayingTransition.artRect(0, src, dest, travel);
      for (var p = 0.0; p <= 1.04; p += 0.001) {
        final r = NowPlayingTransition.artRect(p, src, dest, travel);
        expect((r.center - prev.center).distance, lessThan(3));
        prev = r;
      }
    });
  });

  testWidgets('opens by flying the art out of the mini-player', (tester) async {
    await _pump(tester);
    final anchor = _anchorRect(tester);
    await _open(tester);
    expect(_p(tester), 0);

    await tester.pump(const Duration(milliseconds: 8));
    final first = _flyingRect(tester);
    expect(first, isNotNull);
    expect((first!.center - anchor.center).distance, lessThan(12),
        reason: 'the flight starts on the mini-player art');
    expect(_anchorVisible(tester), isFalse,
        reason: 'the mini-player art is hidden while its copy flies');
    expect(_visible(tester, find.byType(AlbumArtView)), isFalse);

    // It grows smoothly: never shrinking, never jumping.
    var prev = first;
    await _frames(tester, 1000, (_) {
      final r = _flyingRect(tester);
      if (r == null) return;
      expect(r.width, greaterThanOrEqualTo(prev.width - 0.5));
      expect((r.center - prev.center).distance, lessThan(60));
      prev = r;
    });

    expect(_p(tester), 1);
    expect(_flyingRect(tester), isNull);
    expect(_visible(tester, find.byType(AlbumArtView)), isTrue);
    expect(_anchorVisible(tester), isTrue);
    // The copy landed exactly where the real art sits.
    expect((prev.center - tester.getCenter(find.byType(AlbumArtView))).distance,
        lessThan(2));

    await _unmount(tester);
  });

  testWidgets('glass never renders under a fractional fade', (tester) async {
    await _pump(tester, glass: true);
    await _open(tester);

    void check() {
      for (final e in find.byType(BackdropFilter).evaluate()) {
        e.visitAncestorElements((a) {
          final w = a.widget;
          if (w is Opacity) {
            expect(w.opacity, anyOf(0.0, 1.0),
                reason: 'a BackdropFilter inside a fractional Opacity');
          }
          return true;
        });
      }
    }

    await _frames(tester, 1000, (_) => check());
    expect(find.byType(BackdropFilter), findsWidgets,
        reason: 'glass is back once open');

    // And while dragging down.
    final g = await tester.startGesture(const Offset(196, 300));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 8));
      check();
    }
    await g.up();
    await _frames(tester, 2000, (_) => check());

    await _unmount(tester);
  });

  testWidgets('drag follows the finger and springs back with an overshoot',
      (tester) async {
    await _pump(tester);
    await _open(tester);
    await _frames(tester, 1000);

    final g = await tester.startGesture(const Offset(196, 300));
    await g.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 8));
    expect(_state(tester).closePath, isTrue);
    final topAtStart = _frame(tester).sheet.top;
    await g.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 8));
    expect(_frame(tester).sheet.top - topAtStart, closeTo(100, 0.5),
        reason: '1:1 with the finger');
    expect(_frame(tester).opacity, 1, reason: 'no fade while dragging');
    expect(_frame(tester).contentOpacity, 1);

    // Hold still so the release has no velocity, then let go.
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    var maxP = 0.0;
    await _frames(tester, 1200, (p) => maxP = p > maxP ? p : maxP);
    expect(maxP, greaterThan(1.0005), reason: 'a soft overshoot');
    expect(maxP, lessThan(1.02));
    expect(_p(tester), 1);
    expect(find.byType(NowPlayingScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('swipe down: slides off the bottom, then merges up',
      (tester) async {
    await _pump(tester);
    await _open(tester);
    await _frames(tester, 1000);

    final capsule = tester.getRect(find.byKey(_capsuleKey));
    final g = await tester.startGesture(const Offset(196, 300));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 8));
      expect(_frame(tester).opacity, 1, reason: 'no fade while dragging');
    }
    await g.up();

    var minP = 1.0, maxTop = 0.0, maxReach = 0.0, maxGulp = 0.0;
    var necks = 0;
    var revealedBeforeNeck = false;
    NowPlayingFrame? last;
    await _frames(tester, 2000, (p) {
      final f = _frame(tester);
      minP = math.min(minP, p);
      if (p >= kNowPlayingMergeStart) {
        expect(f.opacity, 1, reason: 'opaque all the way down');
        maxTop = math.max(maxTop, f.sheet.top);
      }
      if (f.neck != null) {
        necks++;
        if (maxTop > capsule.bottom) revealedBeforeNeck = true;
      }
      maxReach = math.max(maxReach, NowPlayingCapsuleAnchor.reach.value);
      maxGulp = math.max(maxGulp, NowPlayingCapsuleAnchor.gulp.value);
      expect(_flyingRect(tester), isNull, reason: 'closing, the art rides');
      expect(_anchorVisible(tester), isTrue);
      last = f;
    });

    // Frames are 8ms apart and the slide is fastest there, so the last
    // sampled frame above the merge may be a little short of the edge.
    expect(maxTop, greaterThan(_height * 0.9),
        reason: 'the player slid (nearly) off the bottom');
    expect(necks, greaterThan(3));
    expect(revealedBeforeNeck, isTrue,
        reason: 'the merge starts after the player has slid past the '
            'mini-player');
    expect(maxReach, greaterThan(0.1), reason: 'the capsule reached out');
    expect(maxGulp, greaterThan(0.3), reason: 'and swallowed the merge');
    expect(minP, lessThan(0), reason: 'a soft overshoot as it lands');
    expect(minP, greaterThan(-0.08));
    expect((last!.sheet.topLeft - capsule.topLeft).distance, lessThan(6));
    expect(last!.sheet.width, closeTo(capsule.width, 6));
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(NowPlayingCapsuleAnchor.gulp.value, 0);
    expect(NowPlayingCapsuleAnchor.reach.value, 0);

    await _unmount(tester);
  });

  testWidgets('a drag can catch and reverse the close mid-flight',
      (tester) async {
    await _pump(tester);
    await _open(tester);
    await _frames(tester, 1000);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await _frames(tester, 100);
    final caught = _p(tester);
    expect(caught, inExclusiveRange(0.1, 0.98));

    final g = await tester.startGesture(const Offset(196, 600));
    await g.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 8));
    expect(_p(tester), greaterThanOrEqualTo(caught - 0.01),
        reason: 'the drag took over from the close animation');
    // Back up near the top, so the release (with no fling) reopens.
    for (var i = 0; i < 9; i++) {
      await g.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.up();
    await _frames(tester, 1500);
    expect(_p(tester), 1);
    expect(find.byType(NowPlayingScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('system back animates closed before popping', (tester) async {
    await _pump(tester);
    await _open(tester);
    await _frames(tester, 1000);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    expect(_p(tester), lessThan(1));
    await _frames(tester, 2000);
    expect(find.byType(NowPlayingScreen), findsNothing);

    await _unmount(tester);
  });

  testWidgets('reduce motion: no flight, open and close jump', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _open(tester);
    expect(_p(tester), 1);
    await tester.pump(const Duration(milliseconds: 8));
    expect(_flyingRect(tester), isNull);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    expect(find.byType(NowPlayingScreen), findsNothing);

    await _unmount(tester);
  });

  testWidgets('glass mode still opens and closes from the chevron',
      (tester) async {
    await _pump(tester, glass: true);
    await _open(tester);
    await _frames(tester, 1000);
    await tester.tap(find.byIcon(CupertinoIcons.chevron_down));
    await _frames(tester, 2000);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await _unmount(tester);
  });
}
