import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/common/glass_icon_button.dart';

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// The glass disc behind the glyph, if any.
Finder get _disc => find.descendant(
    of: find.byType(GlassIconButton), matching: find.byType(GlassContainer));

double _discVisibility(WidgetTester tester) =>
    tester.widget<GlassContainer>(_disc).visibility;

void main() {
  testWidgets('tap calls onPressed once; disabled does nothing',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(GlassIconButton(
      icon: CupertinoIcons.play_fill,
      onPressed: () => taps++,
    )));
    await tester.tap(find.byType(GlassIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.pumpWidget(_app(const GlassIconButton(
      icon: CupertinoIcons.play_fill,
      onPressed: null,
    )));
    await tester.tap(find.byType(GlassIconButton));
    await tester.pumpAndSettle();
    expect(_disc, findsOneWidget, reason: 'persistent disc still drawn');
    expect(taps, 1);
  });

  testWidgets('persistent button always sits on a fully visible glass disc',
      (tester) async {
    await tester.pumpWidget(_app(GlassIconButton(
      icon: CupertinoIcons.heart,
      onPressed: () {},
    )));
    expect(_disc, findsOneWidget);
    expect(_discVisibility(tester), 1.0);
  });

  testWidgets(
      'press-reveal: no disc at rest, disc swells in right on pointer down '
      'even with competing gestures, and fades after release', (tester) async {
    var taps = 0;
    // A PageView and a vertical drag compete with the tap, which holds back
    // the tap's own down event for 100ms.
    await tester.pumpWidget(_app(GestureDetector(
      onVerticalDragEnd: (_) {},
      child: SizedBox(
        width: 300,
        height: 300,
        child: PageView(children: [
          Center(
            child: GlassIconButton(
              icon: CupertinoIcons.play_fill,
              size: 76,
              persistent: false,
              onPressed: () => taps++,
            ),
          ),
          const SizedBox(),
        ]),
      ),
    )));
    expect(_disc, findsNothing);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GlassIconButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_disc, findsOneWidget, reason: 'shown before the 100ms tap delay');
    expect(_discVisibility(tester), greaterThan(0.3));
    await tester.pump(const Duration(milliseconds: 120));
    expect(_discVisibility(tester), 1.0);

    await gesture.up();
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(_disc, findsNothing);
  });

  testWidgets('a quick tap still shows the full swell before fading',
      (tester) async {
    await tester.pumpWidget(_app(GlassIconButton(
      icon: CupertinoIcons.forward_fill,
      persistent: false,
      onPressed: () {},
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GlassIconButton)));
    await tester.pump();
    await gesture.up(); // Released almost at once.
    var peak = 0.0;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_disc.evaluate().isNotEmpty) {
        final v = _discVisibility(tester);
        if (v > peak) peak = v;
      }
    }
    expect(peak, 1.0);
    await tester.pumpAndSettle();
    expect(_disc, findsNothing);
  });

  testWidgets('a swipe that starts on the button releases it without a tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(SizedBox(
      width: 300,
      height: 200,
      child: PageView(children: [
        Center(
          child: GlassIconButton(
            icon: CupertinoIcons.backward_fill,
            persistent: false,
            onPressed: () => taps++,
          ),
        ),
        const SizedBox(),
      ]),
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GlassIconButton)));
    await tester.pump(const Duration(milliseconds: 30));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(_disc, findsNothing);
  });

  testWidgets('turning persistent on fades the disc in rather than popping',
      (tester) async {
    Widget button(bool on) => _app(GlassIconButton(
          icon: CupertinoIcons.shuffle,
          persistent: on,
          onPressed: () {},
        ));
    await tester.pumpWidget(button(false));
    expect(_disc, findsNothing);

    await tester.pumpWidget(button(true));
    await tester.pump(const Duration(milliseconds: 60));
    final mid = _discVisibility(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(_discVisibility(tester), 1.0);

    await tester.pumpWidget(button(false));
    await tester.pumpAndSettle();
    expect(_disc, findsNothing);
  });

  testWidgets('never fades glass with Opacity (it breaks the shader)',
      (tester) async {
    await tester.pumpWidget(_app(GlassIconButton(
      icon: CupertinoIcons.play_fill,
      persistent: false,
      onPressed: () {},
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GlassIconButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_disc, findsOneWidget);
    expect(_discVisibility(tester), inExclusiveRange(0.0, 1.0));
    expect(
      find.ancestor(of: _disc, matching: find.byType(Opacity)),
      findsNothing,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('changing the icon cross-fades the glyphs', (tester) async {
    Widget button(IconData icon) => _app(GlassIconButton(
          icon: icon,
          persistent: false,
          onPressed: () {},
        ));
    await tester.pumpWidget(button(CupertinoIcons.play_fill));
    await tester.pumpWidget(button(CupertinoIcons.pause_fill));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.play_fill), findsNothing);
    expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
  });

  testWidgets('is a labelled button for assistive tech', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_app(GlassIconButton(
      icon: CupertinoIcons.ellipsis,
      semanticLabel: 'More',
      onPressed: () => taps++,
    )));
    expect(
      tester.getSemantics(find.bySemanticsLabel('More')),
      isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('More'));
    expect(taps, 1);
    semantics.dispose();
  });
}
