import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:musly/widgets/common/glass_container.dart';

/// One destination in a [GlassTabBar].
@immutable
class GlassTabItem {
  const GlassTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;

  /// Shown while the selection bubble is over this tab.
  final IconData activeIcon;
  final String label;
}

/// iOS 26-style floating Liquid Glass tab bar.
///
/// A glass capsule ([GlassContainer]) holding the tabs, with a selection
/// "bubble" behind the selected one. The bubble is a window onto an accented
/// copy of the tabs: whatever part of an icon or label lies under the bubble
/// is drawn in the theme accent, and everything outside it stays neutral. As
/// the bubble slides, its edges reveal and hide the colour exactly where they
/// cross; colours never fade. Only the bubble's position animates.
///
/// The bubble moves along two separate paths:
///  * **Tap:** [onTabSelected] fires, and when [currentIndex] changes the
///    bubble slides to the new tab with a short eased transition.
///  * **Drag:** while a finger drags across the bar, the bubble lifts and
///    tracks it 1:1 (after a brief catch-up if the drag started away from
///    it), lighting up whichever tab it is over. On release it springs to the
///    nearest tab (taking the fling into account) and selects it.
///
/// [currentIndex] stays the source of truth: if the parent doesn't adopt a
/// selection, the bubble returns to [currentIndex].
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTabSelected,
    this.height = 62,
    this.style = GlassStyle.regular,
  }) : assert(items.length > 0);

  final List<GlassTabItem> items;
  final int currentIndex;

  /// Called on a tap (including on the current tab, e.g. to pop to its root)
  /// and when a drag is released over a different tab.
  final ValueChanged<int> onTabSelected;

  final double height;
  final GlassStyle style;

  /// Key of the selection bubble, for tests.
  static const Key bubbleKey = ValueKey<String>('GlassTabBar.bubble');

  /// Keys of the neutral (outside the bubble) and accented (inside the
  /// bubble) tab layers, for tests.
  static const Key neutralLayerKey = ValueKey<String>('GlassTabBar.neutral');
  static const Key accentLayerKey = ValueKey<String>('GlassTabBar.accent');

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// Inset of the bubble from the bar's edges.
const double _kBubbleInset = 4;

/// Bubble scale while lifted by a drag.
const double _kLiftScale = 0.08;

/// Tap slide: gets going straight away, then decelerates gently into place.
const Curve _kSlideCurve = Cubic(0.3, 0.0, 0.1, 1.0);

/// Release snap: lightly underdamped, so the bubble settles with a hint of
/// overshoot, like a liquid drop.
final SpringDescription _kSnapSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 520,
  ratio: 0.78,
);

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  /// Bubble position in tab units: 0 is the centre of the first tab, 1 the
  /// second, and so on. Fractional while moving.
  late final AnimationController _pos;

  /// 0 at rest, 1 while a drag holds the bubble.
  late final AnimationController _lift;

  /// At drag start, blends the bubble from where it was to the finger, so it
  /// doesn't jump. 1 once it has caught up.
  late final AnimationController _catchUp;

  // Layout, refreshed every build.
  double _slotWidth = 1;

  // Drag state.
  bool _dragging = false;
  double _dragAnchor = 0;
  double _finger = 0;
  int _hovered = 0;

  /// Tab the bubble is currently animating to, if any.
  int? _target;

  int get _count => widget.items.length;

  int _clampIndex(int i) => i.clamp(0, widget.items.length - 1);

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _pos = AnimationController.unbounded(
      vsync: this,
      value: _clampIndex(widget.currentIndex).toDouble(),
    );
    _lift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _catchUp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 1,
    )..addListener(_applyDrag);
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _pos.value = _pos.value.clamp(0.0, (_count - 1).toDouble());
    }
    if (widget.currentIndex != oldWidget.currentIndex && !_dragging) {
      _slideTo(_clampIndex(widget.currentIndex));
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _lift.dispose();
    _catchUp.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ tap

  /// Tap path: a short eased slide (~320ms to a neighbour, a little longer
  /// for longer trips).
  void _slideTo(int index) {
    if (_target == index && _pos.isAnimating) return;
    _target = index;
    if (_reduceMotion) {
      _pos.value = index.toDouble();
      return;
    }
    final distance = (index - _pos.value).abs();
    if (distance < 0.001) {
      _pos.value = index.toDouble();
      return;
    }
    final ms = 260 + 60 * math.min(distance, 3.0);
    _pos.animateTo(
      index.toDouble(),
      duration: Duration(milliseconds: ms.round()),
      curve: _kSlideCurve,
    );
  }

  int _indexAt(double dx) =>
      _clampIndex(((dx - _kBubbleInset) / _slotWidth).floor());

  void _handleTapUp(TapUpDetails details) {
    widget.onTabSelected(_indexAt(details.localPosition.dx));
  }

  // ----------------------------------------------------------------- drag

  /// Finger position in tab units, with rubber-banding past the end tabs.
  double _fingerToPos(double dx) {
    final raw = (dx - _kBubbleInset) / _slotWidth - 0.5;
    final last = (_count - 1).toDouble();
    double band(double over) => 0.18 * (1 - 1 / (1 + over * 1.6));
    if (raw < 0) return -band(-raw);
    if (raw > last) return last + band(raw - last);
    return raw;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    _target = null;
    _pos.stop();
    _dragAnchor = _pos.value;
    _finger = _fingerToPos(details.localPosition.dx);
    _hovered = _clampIndex(_pos.value.round());
    if (_reduceMotion) {
      _lift.value = 1;
      _catchUp.value = 1;
      _applyDrag();
    } else {
      _lift.forward();
      _catchUp.forward(from: 0);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _finger = _fingerToPos(details.localPosition.dx);
    _applyDrag();
  }

  /// Drag path: the bubble follows the finger directly (blended in by
  /// [_catchUp] right after the drag starts).
  void _applyDrag() {
    if (!_dragging) return;
    final t = Curves.easeOutCubic.transform(_catchUp.value);
    _pos.value = lerpDouble(_dragAnchor, _finger, t)!;
    final hovered = _clampIndex(_pos.value.round());
    if (hovered != _hovered) {
      _hovered = hovered;
      HapticFeedback.selectionClick();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _catchUp.value = 1;
    _lift.reverse();

    // Velocity in tab units per second. A flick carries the bubble on to the
    // tab it is heading for.
    final velocity = details.velocity.pixelsPerSecond.dx / _slotWidth;
    final projected = _pos.value + velocity * 0.12;
    final index = _clampIndex(projected.round());
    // Capped so a hard flick at an end tab can't overshoot far past the bar.
    _snapTo(index, velocity.clamp(-10.0, 10.0));

    if (index != widget.currentIndex) widget.onTabSelected(index);

    // If the parent didn't adopt the selection, go back to its tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragging) return;
      final current = _clampIndex(widget.currentIndex);
      if (_target != current) _slideTo(current);
    });
  }

  void _handleDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _catchUp.value = 1;
    _lift.reverse();
    _snapTo(_clampIndex(widget.currentIndex), 0);
  }

  /// Release path: spring to [index], carrying the finger's velocity.
  void _snapTo(int index, double velocity) {
    _target = index;
    if (_reduceMotion) {
      _pos.value = index.toDouble();
      return;
    }
    _pos.animateWith(SpringSimulation(
      _kSnapSpring,
      _pos.value,
      index.toDouble(),
      velocity,
      tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
    ));
  }

  // ---------------------------------------------------------------- build

  /// How close the bubble is to tab [i], 1 when centred on it and easing to 0
  /// as it moves away. Drives only the lens magnification. Colour is not
  /// computed per tab at all: it comes from which layer shows through where
  /// (see [build]).
  double _proximity(int i, double pos) {
    final d = (pos - i).abs();
    final t = ((d - 0.15) / 0.6).clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final neutral = isDark ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73);

    return GlassContainer.capsule(
      height: widget.height,
      style: widget.style,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        _slotWidth = math.max(1.0, (width - 2 * _kBubbleInset) / _count);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: _handleDragCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pos, _lift]),
            builder: (context, _) {
              final pos = _pos.value;
              final lift = _lift.value;

              // Liquid stretch while sliding: longer and a little flatter in
              // the direction of travel.
              final stretch = math.min(_pos.velocity.abs() * 0.012, 0.18);
              final bubbleHeight = (height - 2 * _kBubbleInset) *
                  (1 + _kLiftScale * lift) *
                  (1 - 0.35 * stretch);
              final bubbleWidth = (_slotWidth - _kBubbleInset) *
                  (1 + _kLiftScale * lift) *
                  (1 + stretch);
              final centre = _kBubbleInset + _slotWidth * (pos + 0.5);
              final bubbleRect = Rect.fromCenter(
                center: Offset(centre, height / 2),
                width: bubbleWidth,
                height: bubbleHeight,
              );
              final bubbleShape = RRect.fromRectAndRadius(
                bubbleRect,
                Radius.circular(bubbleRect.shortestSide / 2),
              );

              // Two identical rows of tabs, one neutral and one accented,
              // laid out on the same grid. The bubble is a window: the
              // accented row shows only through the bubble's shape and the
              // neutral row only outside it. So as the bubble's edge crosses
              // an icon, the part under the bubble turns accent and the rest
              // stays gray, pixel by pixel. Nothing fades.
              Widget row({required bool accented}) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: _kBubbleInset),
                    child: Row(
                      children: [
                        for (var i = 0; i < _count; i++)
                          Expanded(
                            child: _TabSlot(
                              item: widget.items[i],
                              accented: accented,
                              color: accented ? accent : neutral,
                              scale: 1 + 0.12 * lift * _proximity(i, pos),
                            ),
                          ),
                      ],
                    ),
                  );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    rect: bubbleRect,
                    child: CustomPaint(
                      key: GlassTabBar.bubbleKey,
                      painter: _BubblePainter(isDark: isDark, lift: lift),
                    ),
                  ),
                  // Neutral tabs, everywhere except under the bubble.
                  Positioned.fill(
                    child: ClipPath(
                      key: GlassTabBar.neutralLayerKey,
                      clipper: _BubbleClipper(bubbleShape, outside: true),
                      child: ExcludeSemantics(child: row(accented: false)),
                    ),
                  ),
                  // Accented tabs, only under the bubble.
                  Positioned.fill(
                    child: ClipPath(
                      key: GlassTabBar.accentLayerKey,
                      clipper: _BubbleClipper(bubbleShape, outside: false),
                      child: ExcludeSemantics(child: row(accented: true)),
                    ),
                  ),
                  // One semantics node per tab, independent of the visuals.
                  Positioned.fill(
                    left: _kBubbleInset,
                    right: _kBubbleInset,
                    child: Row(
                      children: [
                        for (var i = 0; i < _count; i++)
                          Expanded(
                            child: Semantics(
                              container: true,
                              button: true,
                              selected: i == widget.currentIndex,
                              label: widget.items[i].label,
                              onTap: () => widget.onTabSelected(i),
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

/// Clips to the bubble's shape, or to everything outside it.
class _BubbleClipper extends CustomClipper<Path> {
  const _BubbleClipper(this.shape, {required this.outside});

  final RRect shape;
  final bool outside;

  @override
  Path getClip(Size size) {
    final bubble = Path()..addRRect(shape);
    if (!outside) return bubble;
    // Generous bounds so the magnified icons aren't cut at the bar's edge.
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(size.height))
      ..addRRect(shape);
  }

  @override
  bool shouldReclip(_BubbleClipper old) =>
      old.shape != shape || old.outside != outside;
}

/// One tab's icon and label, in a single colour. The neutral and accented
/// rows use identical metrics so the two layers line up exactly at the
/// bubble's edge.
class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    required this.accented,
    required this.color,
    required this.scale,
  });

  final GlassTabItem item;

  /// The accented copy uses the filled icon.
  final bool accented;
  final Color color;

  /// Lens magnification while a lifted bubble is near.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            accented ? item.activeIcon : item.icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The selection bubble: a soft glass pill with a lit rim. Lifted (while a
/// drag holds it), it turns clearer with a brighter rim and a soft shadow.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.isDark, required this.lift});

  final bool isDark;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(size.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(rect, r);

    if (lift > 0) {
      canvas.drawRRect(
        shape.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: (isDark ? 0.30 : 0.12) * lift)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final fill = isDark
        ? Colors.white.withValues(alpha: lerpDouble(0.14, 0.10, lift)!)
        : Color.lerp(
            Colors.black.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.55),
            lift,
          )!;
    canvas.drawRRect(shape, Paint()..color = fill);

    // Light catching the top-left of the pill, fading toward the bottom-right.
    final peak = (isDark ? 0.22 : 0.55) + (isDark ? 0.25 : 0.35) * lift;
    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: peak),
            Colors.white.withValues(alpha: peak * 0.15),
            Colors.white.withValues(alpha: peak * 0.45),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.isDark != isDark || old.lift != lift;
}
