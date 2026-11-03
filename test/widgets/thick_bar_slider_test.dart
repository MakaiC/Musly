import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/thick_bar_slider.dart';
import 'package:musly/widgets/now_playing/playback_progress_slider.dart';

/// Bar thickness as painted: the height of the bar's painted bounds.
double _paintedThickness(WidgetTester tester) {
  final paint = find.descendant(
    of: find.byType(ThickBarSlider),
    matching: find.byType(CustomPaint),
  );
  final box = tester.renderObject<RenderCustomPaint>(paint);
  final recorder = _RecordingCanvas();
  box.painter!.paint(recorder, box.size);
  return recorder.firstRRect!.height;
}

class _RecordingCanvas implements Canvas {
  RRect? firstRRect;
  @override
  void drawRRect(RRect rrect, Paint paint) => firstRRect ??= rrect;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(child: SizedBox(width: 200, child: child)),
        ),
      ),
    );

void main() {
  testWidgets('idle bar is thicker than the old 4px track, with no thumb',
      (tester) async {
    await tester.pumpWidget(_host(const ThickBarSlider(
      value: 0.5,
      activeColor: Colors.white,
    )));
    expect(_paintedThickness(tester), kThickBarIdleThickness);
    expect(kThickBarIdleThickness, greaterThan(4));
    expect(tester.getSize(find.byType(ThickBarSlider)).height,
        kThickBarHitHeight);
  });

  testWidgets('grows smoothly while touched and shrinks back on release',
      (tester) async {
    await tester.pumpWidget(_host(const ThickBarSlider(
      value: 0.5,
      activeColor: Colors.white,
    )));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(ThickBarSlider)));
    await tester.pump(); // first frame starts the ticker
    await tester.pump(kThickBarResizeDuration ~/ 4);
    final mid = _paintedThickness(tester);
    expect(mid, greaterThan(kThickBarIdleThickness));
    expect(mid, lessThan(kThickBarActiveThickness));
    await tester.pumpAndSettle();
    expect(_paintedThickness(tester), kThickBarActiveThickness);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_paintedThickness(tester), kThickBarIdleThickness);
  });

  testWidgets('reduce motion jumps between thicknesses', (tester) async {
    await tester.pumpWidget(_host(
      const ThickBarSlider(value: 0.5, activeColor: Colors.white),
      reduceMotion: true,
    ));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(ThickBarSlider)));
    await tester.pump();
    expect(_paintedThickness(tester), kThickBarActiveThickness);
    await gesture.up();
    await tester.pump();
    expect(_paintedThickness(tester), kThickBarIdleThickness);
  });

  testWidgets('tap reports start, change and end with the tapped value',
      (tester) async {
    final events = <String>[];
    await tester.pumpWidget(_host(ThickBarSlider(
      value: 0.0,
      activeColor: Colors.white,
      onChangeStart: (v) => events.add('start ${v.toStringAsFixed(2)}'),
      onChanged: (v) => events.add('change ${v.toStringAsFixed(2)}'),
      onChangeEnd: (v) => events.add('end ${v.toStringAsFixed(2)}'),
    )));
    final rect = tester.getRect(find.byType(ThickBarSlider));
    await tester.tapAt(Offset(rect.left + 150, rect.center.dy));
    await tester.pumpAndSettle();
    expect(events, ['start 0.75', 'change 0.75', 'end 0.75']);
  });

  testWidgets('drag starts from the current value and tracks the finger',
      (tester) async {
    final changes = <double>[];
    double? start, end;
    await tester.pumpWidget(_host(ThickBarSlider(
      value: 0.3,
      activeColor: Colors.white,
      onChangeStart: (v) => start = v,
      onChanged: changes.add,
      onChangeEnd: (v) => end = v,
    )));
    final rect = tester.getRect(find.byType(ThickBarSlider));
    final gesture =
        await tester.startGesture(Offset(rect.left + 60, rect.center.dy));
    await gesture.moveTo(Offset(rect.left + 120, rect.center.dy));
    await tester.pump();
    await gesture.moveTo(Offset(rect.left + 500, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(start, 0.3);
    // The fill follows the finger from the moment the drag is recognised.
    expect(changes.first, greaterThan(0.3));
    expect(changes.first, lessThanOrEqualTo(0.6));
    expect(changes.last, 1.0); // clamped past the end
    expect(end, 1.0);
  });

  testWidgets('scrubber seeks on release, not mid-drag, and on tap',
      (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_host(PlaybackProgressSlider(
      position: const Duration(seconds: 10),
      duration: const Duration(seconds: 100),
      accentColor: Colors.white,
      onChanged: seeks.add,
    )));
    final rect = tester.getRect(find.byType(ThickBarSlider));
    final gesture =
        await tester.startGesture(Offset(rect.left + 20, rect.center.dy));
    for (var x = 30.0; x <= 100; x += 10) {
      await gesture.moveTo(Offset(rect.left + x, rect.center.dy));
      await tester.pump();
    }
    expect(seeks, isEmpty);
    expect(find.text('00:50'), findsOneWidget); // label follows the drag
    await gesture.up();
    await tester.pumpAndSettle();
    expect(seeks, [const Duration(seconds: 50)]);

    await tester.tapAt(Offset(rect.left + 50, rect.center.dy));
    await tester.pumpAndSettle();
    expect(seeks.last, const Duration(seconds: 25));
  });
}
