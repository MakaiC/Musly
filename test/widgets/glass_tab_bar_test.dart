import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

void main() {
  testWidgets('bubble starts behind the selected tab, which uses the accent',
      (tester) async {
    final h = _Harness()..current.value = 1;
    await h.pump(tester);

    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 1), epsilon: 0.5));
    expect(find.byIcon(CupertinoIcons.collections_solid), findsOneWidget);
    expect(_iconColor(tester, CupertinoIcons.collections_solid), _accent);
    expect(find.byIcon(CupertinoIcons.music_house), findsOneWidget);
    expect(_iconColor(tester, CupertinoIcons.music_house), isNot(_accent));
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
    expect(_iconColor(tester, CupertinoIcons.search), _accent);
    expect(_iconColor(tester, CupertinoIcons.music_house), isNot(_accent));
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
    expect(find.byIcon(CupertinoIcons.collections_solid), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.music_house_fill), findsNothing);
    expect(
        _iconColor(tester, CupertinoIcons.music_house), isNot(_accent));

    // Continuous: every small move moves the bubble by the same amount.
    for (var i = 0; i < 5; i++) {
      final before = _bubbleX(tester);
      await moveTo(x + 3);
      expect(_bubbleX(tester) - before, moreOrLessEquals(3, epsilon: 0.01));
    }

    await moveTo(_tabX(tester, 2));
    expect(_bubbleX(tester), moreOrLessEquals(x, epsilon: 0.5));
    expect(_iconColor(tester, CupertinoIcons.search), _accent);
    expect(h.selections, isEmpty);

    await gesture.up();
    expect(h.selections, [2]);
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), moreOrLessEquals(_tabX(tester, 2), epsilon: 0.5));
    expect(haptics.where((t) => t == 'HapticFeedbackType.selectionClick'),
        hasLength(2), reason: 'one tick per tab crossed');
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
}
