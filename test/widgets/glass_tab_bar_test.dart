import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/navigation/glass_tab_bar.dart';

const _accent = Color(0xFF007AFF);

const _items = [
  GlassTabItem(
    icon: CupertinoIcons.music_house,
    activeIcon: CupertinoIcons.music_house_fill,
    label: 'Home',
  ),
  GlassTabItem(
    icon: CupertinoIcons.collections,
    activeIcon: CupertinoIcons.collections_solid,
    label: 'Library',
  ),
  GlassTabItem(
    icon: CupertinoIcons.search,
    activeIcon: CupertinoIcons.search,
    label: 'Search',
  ),
];

/// Bar width 368 => 3 slots of 120px after the 4px insets.
const double _barWidth = 368;

class _Harness {
  final ValueNotifier<int> current = ValueNotifier<int>(0);
  final List<int> selections = [];

  /// When false, selections are reported but not adopted (like the Search
  /// easter egg, which opens a page instead of switching tabs).
  bool adopt = true;

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) {
    return tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _accent))
          .copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: _accent)
                  .copyWith(primary: _accent)),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: _barWidth,
              child: ValueListenableBuilder<int>(
                valueListenable: current,
                builder: (context, index, _) => GlassTabBar(
                  items: _items,
                  currentIndex: index,
                  onTabSelected: (i) {
                    selections.add(i);
                    if (adopt) current.value = i;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

Rect _bar(WidgetTester tester) => tester.getRect(find.byType(GlassTabBar));

double _tabX(WidgetTester tester, int i) => _bar(tester).left + 4 + 120 * (i + 0.5);

double _bubbleX(WidgetTester tester) =>
    tester.getRect(find.byKey(GlassTabBar.bubbleKey)).center.dx;

const _neutral = Color(0xFF6E6E73); // light theme

/// Whether the layer with [key] is visible at [global] (a screen point),
/// according to its clip.
bool _layerShows(WidgetTester tester, Key key, Offset global) {
  final finder = find.byKey(key);
  final clip = tester.widget<ClipPath>(finder);
  final box = tester.renderObject<RenderBox>(finder);
  return clip.clipper!.getClip(box.size).contains(box.globalToLocal(global));
}

/// The colour seen at [global]: accent where the accented layer shows
/// through the bubble, neutral where the neutral layer shows. Exactly one
/// layer shows at any point.
Color _colourAt(WidgetTester tester, Offset global) {
  final accent = _layerShows(tester, GlassTabBar.accentLayerKey, global);
  final neutral = _layerShows(tester, GlassTabBar.neutralLayerKey, global);
  expect(accent, isNot(neutral), reason: 'exactly one layer at $global');
  return accent ? _accent : _neutral;
}

Offset _tab(WidgetTester tester, int i) =>
    Offset(_tabX(tester, i), _bar(tester).center.dy);

Iterable<Icon> _layerIcons(WidgetTester tester, Key key) => tester
    .widgetList<Icon>(find.descendant(
        of: find.byKey(key), matching: find.byType(Icon)));

void main() {
  testWidgets('bubble starts behind the selected tab, which uses the accent',
      (tester) async {
    final h = _Harness()..current.value = 1;
    await h.pump(tester);

    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 1), epsilon: 0.5));
    expect(_colourAt(tester, _tab(tester, 1)), _accent);
    expect(_colourAt(tester, _tab(tester, 0)), _neutral);
    expect(_colourAt(tester, _tab(tester, 2)), _neutral);

    // The accented layer is filled icons in the accent; the neutral layer is
    // outline icons in gray.
    final accented = _layerIcons(tester, GlassTabBar.accentLayerKey).toList();
    expect(accented.map((i) => i.icon), [
      CupertinoIcons.music_house_fill,
      CupertinoIcons.collections_solid,
      CupertinoIcons.search,
    ]);
    expect(accented.map((i) => i.color), everyElement(_accent));
    final plain = _layerIcons(tester, GlassTabBar.neutralLayerKey).toList();
    expect(plain.map((i) => i.icon), [
      CupertinoIcons.music_house,
      CupertinoIcons.collections,
      CupertinoIcons.search,
    ]);
    expect(plain.map((i) => i.color), everyElement(_neutral));
  });

  testWidgets('tap selects and the bubble slides over with an eased transition',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    await tester.tapAt(Offset(_tabX(tester, 2), y));
    expect(h.selections, [2]);

    // Not a teleport: part-way there after a short while...
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final mid = _bubbleX(tester);
    expect(mid, greaterThan(_tabX(tester, 0) + 20));
    expect(mid, lessThan(_tabX(tester, 2) - 5));

    // ...and settled on the tab well under half a second later.
    await tester.pump(const Duration(milliseconds: 300));
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 2), epsilon: 0.5));
    expect(_colourAt(tester, _tab(tester, 2)), _accent);
    expect(_colourAt(tester, _tab(tester, 0)), _neutral);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'slow drag: bubble tracks the finger live, highlights the tab under it, '
      'and selects on release', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    var x = _tabX(tester, 0);
    final gesture = await tester.startGesture(Offset(x, y));
    Future<void> moveTo(double target) async {
      while ((target - x).abs() > 0.01) {
        x += (target - x).clamp(-4.0, 4.0);
        await gesture.moveTo(Offset(x, y));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Past the touch slop and on to a quarter of the way past Library.
    await moveTo(_tabX(tester, 1) + 30);
    await tester.pump(const Duration(milliseconds: 200)); // catch-up done
    expect(_bubbleX(tester), moreOrLessEquals(x, epsilon: 0.5));
    expect(h.selections, isEmpty, reason: 'nothing selected mid-drag');
    expect(_colourAt(tester, _tab(tester, 1)), _accent);
    expect(_colourAt(tester, _tab(tester, 0)), _neutral);

    // Continuous: every small move moves the bubble by the same amount.
    for (var i = 0; i < 5; i++) {
      final before = _bubbleX(tester);
      await moveTo(x + 3);
      expect(_bubbleX(tester) - before, moreOrLessEquals(3, epsilon: 0.01));
    }

    await moveTo(_tabX(tester, 2));
    expect(_bubbleX(tester), moreOrLessEquals(x, epsilon: 0.5));
    expect(_colourAt(tester, _tab(tester, 2)), _accent);
    expect(h.selections, isEmpty);

    await gesture.up();
    expect(h.selections, [2]);
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 2), epsilon: 0.5));
    expect(haptics.where((t) => t == 'HapticFeedbackType.selectionClick'),
        hasLength(2), reason: 'one tick per tab crossed');
  });

  testWidgets(
      'the bubble is a window: colour shows only inside it, and its edge '
      'splits an icon it is crossing', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    var x = _tabX(tester, 0);
    final gesture = await tester.startGesture(Offset(x, y));
    Future<void> moveTo(double target) async {
      while ((target - x).abs() > 0.01) {
        x += (target - x).clamp(-1.0, 1.0);
        await gesture.moveTo(Offset(x, y));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Get the drag going, then park the bubble so its left edge runs
    // through the middle of the Home icon.
    await moveTo(x + 30);
    await tester.pump(const Duration(milliseconds: 300)); // catch-up + lift
    final halfWidth =
        tester.getRect(find.byKey(GlassTabBar.bubbleKey)).width / 2;
    await moveTo(_tabX(tester, 0) + halfWidth);
    final bubble = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
    // (Within 1.5pt: the jelly stretch makes the width breathe slightly with
    // speed. The split below is checked against the actual rect.)
    expect(bubble.left, moreOrLessEquals(_tabX(tester, 0), epsilon: 1.5));

    // Home's icon is half gray (outside) and half accent (under the bubble).
    final home = _tab(tester, 0);
    expect(_colourAt(tester, home - const Offset(5, 0)), _neutral);
    expect(_colourAt(tester, home + const Offset(5, 0)), _accent);

    // The split follows the edge to the pixel, on both sides of the bubble.
    for (final edge in [bubble.left, bubble.right]) {
      final inward = edge == bubble.left ? 1.0 : -1.0;
      expect(_colourAt(tester, Offset(edge + inward, y)), _accent);
      expect(_colourAt(tester, Offset(edge - inward, y)), _neutral);
    }

    // As the bubble slides on, Home's right half goes back to gray.
    await moveTo(x + 10);
    expect(_colourAt(tester, home + const Offset(5, 0)), _neutral);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('drag released over the current tab selects nothing',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    final gesture = await tester.startGesture(Offset(_tabX(tester, 0), y));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(h.selections, isEmpty);
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 0), epsilon: 0.5));
  });

  testWidgets('a flick carries the bubble on to the tab it is heading for',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    // Released less than halfway to Library (a plain release would go back
    // to Home), but moving fast.
    await tester.flingFrom(
        Offset(_tabX(tester, 0), y), const Offset(50, 0), 900);
    expect(h.selections, [1]);
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 1), epsilon: 0.5));
  });

  testWidgets('bubble returns if the parent does not adopt a selection',
      (tester) async {
    final h = _Harness()..adopt = false;
    await h.pump(tester);
    final y = _bar(tester).center.dy;

    final gesture = await tester.startGesture(Offset(_tabX(tester, 0), y));
    for (var i = 1; i <= 60; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    expect(h.selections, [2]);
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 0), epsilon: 0.5));
  });

  testWidgets('an index change from outside slides the bubble too',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);

    h.current.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = _bubbleX(tester);
    expect(mid, greaterThan(_tabX(tester, 0) + 5));
    expect(mid, lessThan(_tabX(tester, 1) - 5));
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 1), epsilon: 0.5));
  });

  testWidgets('reduce motion: taps move the bubble without a transition',
      (tester) async {
    final h = _Harness();
    await h.pump(tester, reduceMotion: true);

    await tester.tapAt(Offset(_tabX(tester, 1), _bar(tester).center.dy));
    await tester.pump();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 1), epsilon: 0.5));
  });

  testWidgets('tabs are selectable buttons for assistive tech',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final h = _Harness()..current.value = 2;
    await h.pump(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Search')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      isSemantics(isButton: true, isSelected: false, hasTapAction: true),
    );

    tester.semantics.tap(find.semantics.byLabel('Home'));
    expect(h.selections, [0]);
    semantics.dispose();
  });

  testWidgets('holding the bubble grows it; letting go settles it back',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final rest = tester.getRect(find.byKey(GlassTabBar.bubbleKey));

    final g = await tester.startGesture(rest.center);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final held = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
    expect(held.width, greaterThan(rest.width * 1.12));
    expect(held.center.dx, moreOrLessEquals(rest.center.dx, epsilon: 0.5));
    expect(h.selections, isEmpty, reason: 'holding selects nothing');

    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(GlassTabBar.bubbleKey)).width,
        moreOrLessEquals(rest.width, epsilon: 0.1));
  });

  testWidgets('holding elsewhere on the bar does not grow the bubble',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final rest = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
    final g = await tester.startGesture(
        Offset(_tabX(tester, 2), _bar(tester).center.dy));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getRect(find.byKey(GlassTabBar.bubbleKey)).width,
        rest.width);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('jelly: stretches while moving fast, wobbles past round when '
      'it stops, then settles', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final y = _bar(tester).center.dy;
    var x = _tabX(tester, 0);
    final g = await tester.startGesture(Offset(x, y));
    await tester.pump(const Duration(milliseconds: 16));
    // Hold still first, so the bubble is lifted and round.
    await tester.pump(const Duration(milliseconds: 300));
    final round = tester.getRect(find.byKey(GlassTabBar.bubbleKey));

    final widths = <double>[];
    for (var i = 0; i < 24; i++) {
      x += 9;
      await g.moveTo(Offset(x, y));
      await tester.pump(const Duration(milliseconds: 16));
      widths.add(tester.getRect(find.byKey(GlassTabBar.bubbleKey)).width);
    }
    final moving = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
    expect(widths.reduce(math.max), greaterThan(round.width * 1.2));
    expect(moving.height, lessThan(round.height), reason: 'flatter');
    // Still tracks the finger: the stretch is symmetric.
    expect(moving.center.dx, moreOrLessEquals(x, epsilon: 1));

    final after = <double>[];
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      after.add(tester.getRect(find.byKey(GlassTabBar.bubbleKey)).width);
    }
    expect(after.reduce(math.min), lessThan(round.width - 1),
        reason: 'rebounds past round');
    expect(after.last, moreOrLessEquals(round.width, epsilon: 1));
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion: no jelly', (tester) async {
    final h = _Harness();
    await h.pump(tester, reduceMotion: true);
    final rest = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
    await tester.tapAt(Offset(_tabX(tester, 2), _bar(tester).center.dy));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byKey(GlassTabBar.bubbleKey)).size, rest.size);
  });

  testWidgets('the glass lens only appears with the refraction shader',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.byKey(GlassTabBar.bubbleGlassKey),
        GlassContainer.refractionAvailable ? findsOneWidget : findsNothing);
  });
}
