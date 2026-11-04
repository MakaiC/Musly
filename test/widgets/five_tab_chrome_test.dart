import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/navigation/glass_tab_bar.dart';

import '../bootstrap.dart';

const _accent = Color(0xFF007AFF);

const _items = [
  GlassTabItem(
      icon: CupertinoIcons.music_house,
      activeIcon: CupertinoIcons.music_house_fill,
      label: 'Home'),
  GlassTabItem(
      icon: CupertinoIcons.square_grid_2x2,
      activeIcon: CupertinoIcons.square_grid_2x2_fill,
      label: 'New'),
  GlassTabItem(
      icon: CupertinoIcons.dot_radiowaves_left_right,
      activeIcon: CupertinoIcons.dot_radiowaves_left_right,
      label: 'Add'),
  GlassTabItem(
      icon: CupertinoIcons.collections,
      activeIcon: CupertinoIcons.collections_solid,
      label: 'Library'),
  GlassTabItem(
      icon: CupertinoIcons.search,
      activeIcon: CupertinoIcons.search,
      label: 'Search'),
];

/// The glass tab bar with the app's five tabs at iPhone width (393pt wide,
/// 12pt margins: a 369pt bar, about 72pt a tab).
void main() {
  initializeTestEnvironment();

  // The default test font (Ahem) is far wider than a real one, so the label
  // fit is checked with Roboto from the SDK when it can be found.
  Future<bool> loadRoboto() async {
    final bin = File(Platform.resolvedExecutable).parent.path;
    final flutter = Platform.environment['FLUTTER_ROOT'] ??
        Process.runSync('which', ['flutter']).stdout.toString().trim();
    final roots = [
      if (Platform.environment['FLUTTER_ROOT'] != null)
        Platform.environment['FLUTTER_ROOT']!,
      File(flutter).resolveSymbolicLinksSync().replaceAll('/bin/flutter', ''),
      bin,
    ];
    for (final root in roots) {
      final dir = '$root/bin/cache/artifacts/material_fonts';
      final regular = File('$dir/Roboto-Regular.ttf');
      final bold = File('$dir/Roboto-Bold.ttf');
      if (regular.existsSync() && bold.existsSync()) {
        final loader = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(regular.readAsBytesSync())))
          ..addFont(Future.value(ByteData.sublistView(bold.readAsBytesSync())));
        await loader.load();
        return true;
      }
    }
    return false;
  }

  Future<List<int>> pumpBar(WidgetTester tester,
      {double collapse = 0, int current = 0, int? collapsedIndex}) async {
    final selections = <int>[];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: _accent).copyWith(primary: _accent),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 369,
            height: 62,
            child: GlassTabBar(
              items: _items,
              currentIndex: current,
              collapse: collapse,
              collapsedIndex: collapsedIndex,
              onTabSelected: selections.add,
            ),
          ),
        ),
      ),
    ));
    return selections;
  }

  Rect glassRect(WidgetTester tester) =>
      tester.getRect(find.byType(GlassContainer).first);

  testWidgets('every icon and label sits in its slot and fits', (tester) async {
    final realFont = await tester.runAsync(loadRoboto) ?? false;
    await pumpBar(tester);
    final bar = glassRect(tester);
    final slot = (369 - 8) / 5;
    for (final (i, item) in _items.indexed) {
      final icon = tester.getCenter(find
          .descendant(
              of: find.byKey(GlassTabBar.neutralLayerKey),
              matching: find.byIcon(item.icon))
          .first);
      // This is what the collapsed row's travelling button starts from, and
      // what the `_kIconCentreOffset` constant (7pt) stands for.
      expect(icon.dx,
          closeTo(bar.left + GlassTabBar.slotCentre(bar.width, 5, i), 0.5));
      expect(icon.dy, closeTo(bar.center.dy + GlassTabBar.iconCentreOffset, 1));

      final label = tester.getRect(find
          .descendant(
              of: find.byKey(GlassTabBar.neutralLayerKey),
              matching: find.text(item.label))
          .first);
      if (realFont) {
        expect(label.width, lessThanOrEqualTo(slot - 4),
            reason: '${item.label} must fit its ${slot.toStringAsFixed(1)}pt slot');
      }
      expect(label.center.dx, closeTo(icon.dx, 1));
    }
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  testWidgets('the selection bubble spans one slot, inside the bar',
      (tester) async {
    for (var i = 0; i < 5; i++) {
      await pumpBar(tester, current: i);
      await tester.pumpAndSettle();
      final bar = glassRect(tester);
      final bubble = tester.getRect(find.byKey(GlassTabBar.bubbleKey));
      expect(bubble.width, closeTo(361 / 5 - 4, 1), reason: 'slot-wide at tab $i');
      expect(bubble.left, greaterThanOrEqualTo(bar.left));
      expect(bubble.right, lessThanOrEqualTo(bar.right));
      expect(bubble.center.dx,
          closeTo(bar.left + GlassTabBar.slotCentre(bar.width, 5, i), 1));
    }
  });

  testWidgets('taps select each of the five tabs', (tester) async {
    final selections = await pumpBar(tester);
    final bar = glassRect(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(Offset(
          bar.left + GlassTabBar.slotCentre(bar.width, 5, i), bar.center.dy));
      await tester.pump();
    }
    expect(selections, [0, 1, 2, 3, 4]);
  });

  testWidgets('collapsed, the circle stands for the chosen tab, for any of '
      'the five', (tester) async {
    for (var i = 0; i < 5; i++) {
      final selections = await pumpBar(tester, collapse: 1, current: i);
      final circle = glassRect(tester);
      expect(circle.size, const Size(52, 52));
      await tester.tapAt(circle.center);
      await tester.pump();
      expect(selections, [i]);
    }
    // On Search the circle stands for Home.
    final selections = await pumpBar(tester, collapse: 1, current: 4, collapsedIndex: 0);
    await tester.tapAt(glassRect(tester).center);
    expect(selections, [0]);
  });
}
