import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/navigation/glass_collapsed_bar.dart';
import 'package:musly/widgets/navigation/glass_tab_bar.dart';

import '../bootstrap.dart';

const _accent = Color(0xFF007AFF);

const _home = GlassTabItem(
  icon: CupertinoIcons.music_house,
  activeIcon: CupertinoIcons.music_house_fill,
  label: 'Home',
);
const _library = GlassTabItem(
  icon: CupertinoIcons.collections,
  activeIcon: CupertinoIcons.collections_solid,
  label: 'Library',
);
const _search = GlassTabItem(
  icon: CupertinoIcons.search,
  activeIcon: CupertinoIcons.search,
  label: 'Search',
);

/// A tall list whose scroll updates go through a [GlassChromeScrollTracker].
class _ScrollHarness {
  final tracker = GlassChromeScrollTracker();
  bool collapsed = false;
  final List<bool> changes = [];

  Future<void> pump(WidgetTester tester,
      {ScrollPhysics physics = const ClampingScrollPhysics()}) {
    return tester.pumpWidget(MaterialApp(
      home: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final c = tracker.handle(n);
          if (c != null && c != collapsed) {
            collapsed = c;
            changes.add(c);
          }
          return false;
        },
        child: ListView(
          physics: physics,
          children: [
            SizedBox(
              height: 120,
              // A horizontal carousel: its scrolling must not count.
              child: ListView(
                key: const Key('carousel'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 20; i++)
                    const SizedBox(width: 120, child: Placeholder()),
                ],
              ),
            ),
            for (var i = 0; i < 60; i++)
              SizedBox(height: 60, child: Text('row $i')),
          ],
        ),
      ),
    ));
  }
}

/// Scrolls the outer list by [dy] (positive is down the page) in small
/// steps, one frame each, like a slow drag.
Future<void> _scrollBy(WidgetTester tester, double dy) async {
  final position =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final steps = (dy.abs() / 4).ceil();
  for (var i = 0; i < steps; i++) {
    position.jumpTo(position.pixels + dy / steps);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  initializeTestEnvironment();

  group('GlassChromeScrollTracker', () {
    testWidgets('collapses only past the threshold, scrolling down',
        (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester);

      await _scrollBy(tester, 15);
      expect(h.collapsed, isFalse, reason: 'below the threshold');

      await _scrollBy(tester, 40);
      expect(h.collapsed, isTrue);
    });

    testWidgets('stays collapsed while scrolling up, until the top',
        (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester);
      await _scrollBy(tester, 600);
      expect(h.collapsed, isTrue);

      await _scrollBy(tester, -300);
      expect(h.collapsed, isTrue, reason: 'scrolling up does not expand');
      await _scrollBy(tester, 200);
      await _scrollBy(tester, -480);
      expect(h.collapsed, isTrue, reason: 'still 20pt from the top');

      await _scrollBy(tester, -20);
      expect(h.collapsed, isFalse, reason: 'reached the top');
    });

    testWidgets('a small jiggle near the top does not collapse it',
        (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester);
      for (var i = 0; i < 4; i++) {
        await _scrollBy(tester, 18);
        await _scrollBy(tester, -18);
      }
      expect(h.changes, isEmpty);
    });

    testWidgets('pulling down against the top expands (clamping physics)',
        (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester);
      await _scrollBy(tester, 100);
      expect(h.collapsed, isTrue);
      // Back to the top without notifying, as if the page were replaced.
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      h.tracker.reset();
      position.correctPixels(0);
      h.collapsed = true;
      await tester.drag(find.text('row 3'), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(h.collapsed, isFalse);
    });

    testWidgets('horizontal scrolling is ignored', (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester);
      await tester.drag(find.byKey(const Key('carousel')),
          const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(h.changes, isEmpty);
    });

    testWidgets('the overscroll bounce at the end does not expand it',
        (tester) async {
      final h = _ScrollHarness();
      await h.pump(tester, physics: const BouncingScrollPhysics());
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent - 100);
      await tester.pump();
      await _scrollBy(tester, 60);
      expect(h.collapsed, isTrue);

      await tester.drag(find.text('row 59'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(h.collapsed, isTrue);
    });
  });

  group('GlassTabBar.collapse', () {
    Future<List<int>> pumpBar(WidgetTester tester, double collapse,
        {int current = 2, int? collapsedIndex, Set<int> detached = const {}}) async {
      final selections = <int>[];
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _accent)
              .copyWith(primary: _accent),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 369,
              height: 62,
              child: GlassTabBar(
                items: const [_home, _library, _search],
                currentIndex: current,
                collapse: collapse,
                collapsedIndex: collapsedIndex,
                detachedTabs: detached,
                onTabSelected: selections.add,
              ),
            ),
          ),
        ),
      ));
      return selections;
    }

    Rect glassRect(WidgetTester tester) =>
        tester.getRect(find.byType(GlassContainer));

    testWidgets('shrinks smoothly into a circle at the leading end',
        (tester) async {
      await pumpBar(tester, 0);
      final full = glassRect(tester);
      expect(full.size, const Size(369, 62));

      await pumpBar(tester, 0.5);
      final half = glassRect(tester);
      expect(half.left, full.left);
      expect(half.bottom, full.bottom);
      expect(half.width, closeTo((369 + 52) / 2, 0.01));
      expect(half.height, closeTo((62 + 52) / 2, 0.01));

      await pumpBar(tester, 1);
      final circle = glassRect(tester);
      expect(circle.size, const Size(52, 52));
      expect(circle.left, full.left);
      expect(circle.bottom, full.bottom);
    });

    testWidgets('the current tab glides into the circle', (tester) async {
      // Search is the last tab; its icon heads left, into the circle.
      await pumpBar(tester, 0);
      final x0 = tester
          .getCenter(find.byKey(GlassTabBar.accentLayerKey))
          .dx;
      await pumpBar(tester, 0.3);
      final x1 = tester
          .getCenter(find.byKey(GlassTabBar.accentLayerKey))
          .dx;
      expect(x1, lessThan(x0));

      await pumpBar(tester, 1);
      // The circle's own icon (the tab rows sit inside an OverflowBox).
      final circleIcon = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.color == _accent &&
          w.icon == CupertinoIcons.search);
      final outsideRows = circleIcon.evaluate().where((e) =>
          e.findAncestorWidgetOfExactType<OverflowBox>() == null);
      expect(outsideRows, hasLength(1));
      expect(tester.getCenter(find.byElementPredicate(
              (e) => e == outsideRows.single)),
          tester.getCenter(find.byType(GlassContainer)));
    });

    testWidgets('collapsed, tapping the circle selects the current tab',
        (tester) async {
      final selections = await pumpBar(tester, 1, current: 1);
      await tester.tap(find.byType(GlassContainer));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selections, [1]);
    });

    testWidgets('collapsedIndex: the circle stands for another tab',
        (tester) async {
      // On Search, the circle is Home: plain icon, neutral, selects Home.
      final selections =
          await pumpBar(tester, 1, current: 2, collapsedIndex: 0);
      final icons = find.byWidgetPredicate((w) =>
          w is Icon && w.icon == CupertinoIcons.music_house);
      final circleIcon = icons.evaluate().where(
          (e) => e.findAncestorWidgetOfExactType<OverflowBox>() == null);
      expect(circleIcon, hasLength(1));
      expect((circleIcon.single.widget as Icon).color, isNot(_accent));
      await tester.tap(find.byType(GlassContainer));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selections, [0]);
    });

    testWidgets('overshoot: past 1 the circle dips smaller, past 0 the bar '
        'swells', (tester) async {
      await pumpBar(tester, 1.06);
      expect(glassRect(tester).width, lessThan(52));
      expect(glassRect(tester).bottom, 600, reason: 'still bottom-aligned');
      await pumpBar(tester, -0.06);
      expect(glassRect(tester).width, greaterThan(369));
    });

    testWidgets('slotCentre matches where the bar draws each tab, for any '
        'tab count', (tester) async {
      await pumpBar(tester, 0);
      final bar = glassRect(tester);
      for (final (i, icon) in [
        (0, CupertinoIcons.music_house),
        (1, CupertinoIcons.collections),
        (2, CupertinoIcons.search),
      ]) {
        final c = tester.getCenter(find
            .descendant(
                of: find.byKey(GlassTabBar.neutralLayerKey),
                matching: find.byIcon(icon))
            .first);
        expect(c.dx, closeTo(bar.left + GlassTabBar.slotCentre(bar.width, 3, i), 0.5));
        expect(c.dy, closeTo(bar.center.dy + GlassTabBar.iconCentreOffset, 1));
      }
      // Four tabs: evenly spread inside the 4pt insets.
      expect(GlassTabBar.slotCentre(369, 4, 0), closeTo(4 + 361 / 8, 1e-9));
      expect(GlassTabBar.slotCentre(369, 4, 3), closeTo(369 - 4 - 361 / 8, 1e-9));
    });

    testWidgets('detached tabs leave the bar once it starts collapsing',
        (tester) async {
      bool searchVisible() => tester
          .widgetList<Opacity>(find.ancestor(
              of: find.descendant(
                  of: find.byKey(GlassTabBar.neutralLayerKey),
                  matching: find.byIcon(CupertinoIcons.search)),
              matching: find.byType(Opacity)))
          .every((o) => o.opacity > 0);
      await pumpBar(tester, 0, current: 0, detached: {2});
      expect(searchVisible(), isTrue, reason: 'expanded: drawn by the bar');
      await pumpBar(tester, 0.1, current: 0, detached: {2});
      expect(searchVisible(), isFalse);
    });

    testWidgets('collapsed semantics: one button for the current tab',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBar(tester, 1, current: 1);
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
      expect(find.bySemanticsLabel('Home'), findsNothing);
      handle.dispose();
    });
  });

  group('GlassTabButton', () {
    testWidgets('round, neutral, taps, semantics', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _accent)
              .copyWith(primary: _accent),
        ),
        home: Scaffold(
          body: Center(
            child: GlassTabButton(
              tab: GlassCollapsedTab(
                  item: _home, selected: false, onTap: () => taps++),
            ),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(GlassContainer)),
          const Size(kGlassCollapsedBarHeight, kGlassCollapsedBarHeight));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, CupertinoIcons.music_house);
      expect(icon.color, isNot(_accent));
      await tester.tap(find.byType(GlassTabButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
      expect(
          tester.getSemantics(find.byType(GlassTabButton)),
          matchesSemantics(
              label: 'Home',
              isButton: true,
              hasSelectedState: true,
              hasTapAction: true));
      handle.dispose();
    });
  });
}
