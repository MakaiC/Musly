import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
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
    this.collapse = 0.0,
    this.collapsedSize = 52,
    this.collapsedIndex,
    this.detachedTabs = const {},
    this.detachProgress = 1,
  }) : assert(items.length > 0);

  final List<GlassTabItem> items;
  final int currentIndex;

  /// Called on a tap (including on the current tab, e.g. to pop to its root)
  /// and when a drag is released over a different tab.
  final ValueChanged<int> onTabSelected;

  final double height;
  final GlassStyle style;

  /// 0..1: shrinks the bar into a round button for a tab, as the
  /// floating chrome collapses. The glass capsule narrows toward its leading
  /// end (and to [collapsedSize] tall, bottom-aligned) while the tabs glide
  /// so that tab ([collapsedIndex], or the current one) ends up centred in
  /// the circle, fading out as its icon fades in there.
  ///
  /// May overshoot slightly past either end for a springy settle: above 1
  /// the circle dips a little smaller, below 0 the bar swells a little.
  ///
  /// While collapsed (above 0) the tabs don't take touches; tapping the
  /// circle calls [onTabSelected] with that tab.
  final double collapse;

  /// Diameter of the round button at [collapse] 1.
  final double collapsedSize;

  /// The tab the collapsed circle stands for; [currentIndex] when null. When
  /// it isn't the current tab, the circle shows that tab's plain icon in the
  /// neutral colour, and tapping it selects that tab.
  final int? collapsedIndex;

  /// Tabs that leave the bar as their own buttons while it collapses (the
  /// parent animates those from [slotCentre] to their spot). Above
  /// [collapse] 0 they fade out of the bar as [detachProgress] goes to 1,
  /// while the parent fades their buttons' glyphs in, so the hand-off is a
  /// crossfade and they never show twice or blink.
  final Set<int> detachedTabs;

  /// 0..1: how far [detachedTabs] have handed over to their own buttons.
  final double detachProgress;

  /// Horizontal centre of tab [index]'s slot in a bar [barWidth] wide with
  /// [count] tabs, from the bar's leading edge. Works for any tab count: use
  /// it to start a tab's transition from exactly where the bar draws it.
  static double slotCentre(double barWidth, int count, int index) {
    final slot = math.max(1.0, (barWidth - 2 * _kBubbleInset) / count);
    return _kBubbleInset + slot * (index + 0.5);
  }

  /// Vertical offset of a tab's icon centre from the bar's centre (the icon
  /// sits above its label).
  static const double iconCentreOffset = -_kIconCentreOffset;

  /// Key of the selection bubble, for tests.
  static const Key bubbleKey = ValueKey<String>('GlassTabBar.bubble');

  /// Key of the selection bubble's glass lens, for tests.
  static const Key bubbleGlassKey =
      ValueKey<String>('GlassTabBar.bubbleGlass');

  /// Keys of the neutral (outside the bubble) and accented (inside the
  /// bubble) tab layers, for tests.
  static const Key neutralLayerKey = ValueKey<String>('GlassTabBar.neutral');
  static const Key accentLayerKey = ValueKey<String>('GlassTabBar.accent');

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// Inset of the bubble from the bar's edges.
const double _kBubbleInset = 4;

/// How far above the bar's centre a tab's icon sits (measured from
/// [_TabSlot]'s layout; keep in sync if that changes).
const double _kIconCentreOffset = 7;

/// Bubble growth while held or dragged.
const double _kLiftScale = 0.16;

/// The bubble's glass: a lens over the tabs with the same rim optics as the
/// tab bar and mini-player (GlassStyle.regular's refraction, bevel, rim
/// frost and veil), but a completely clear centre: no tint, no adaptive
/// tint, no frost, no saturation boost, so whatever it hovers over shows through untouched
/// except where the rim warps it.
final GlassStyle _kBubbleGlass = GlassStyle.regular.copyWith(
  saturation: 1,
  lightTintOpacity: 0,
  darkTintOpacity: 0,
  adaptiveTint: 0,
  frost: 0,
  elevation: 0,
);

/// The bubble's jelly: an underdamped spring pulling its stretch toward a
/// target set by how fast it's moving, so it stretches into a droplet while
/// moving and wobbles back to round when it stops.
const double _kJellyStiffness = 260;
const double _kJellyDamping = 0.32;

/// Stretch per tab/second of bubble speed, and its cap.
const double _kJellyGain = 0.045;
const double _kJellyMax = 0.32;

/// Tap slide: gets going straight away, then decelerates gently into place.
const Curve _kSlideCurve = Cubic(0.3, 0.0, 0.1, 1.0);

/// Release snap: softer and a little more underdamped than a snap, so the
/// bubble glides into place and settles with a gentle overshoot, like a
/// liquid drop. (Was stiffness 520 / ratio 0.78; the user found the release
/// too snappy.)
final SpringDescription _kSnapSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 300,
  ratio: 0.7,
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

  /// Full width of the bar, remembered while expanded so the tabs keep their
  /// layout as the capsule shrinks around them.
  double? _expandedWidth;

  // Drag state.
  bool _dragging = false;
  double _dragAnchor = 0;
  double _finger = 0;
  int _hovered = 0;

  /// Tab the bubble is currently animating to, if any.
  int? _target;

  /// A finger is down on the bubble (it grows while held).
  bool _held = false;

  /// The bubble's rect in the last build, for hit-testing a hold.
  Rect _bubbleRect = Rect.zero;

  // Jelly: the bubble's stretch along its direction of travel, driven every
  // frame by its measured speed (any motion: drag, tap slide, snap).
  late final Ticker _jelly = createTicker(_tickJelly);
  final ValueNotifier<int> _jellyFrame = ValueNotifier<int>(0);
  Duration? _jellyLast;
  double _jellyPos = 0;
  double _speed = 0; // tabs per second, smoothed
  double _stretch = 0; // 0 round; >0 longer and flatter; <0 the rebound
  double _stretchVel = 0;

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
      // Settling back down after a hold or drag: unhurried.
      reverseDuration: const Duration(milliseconds: 420),
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
    _jelly.dispose();
    _jellyFrame.dispose();
    _pos.dispose();
    _lift.dispose();
    _catchUp.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- jelly

  void _wakeJelly() {
    if (_reduceMotion || _jelly.isActive) return;
    _jellyLast = null;
    _jellyPos = _pos.value;
    _jelly.start();
  }

  void _tickJelly(Duration elapsed) {
    final last = _jellyLast;
    _jellyLast = elapsed;
    if (last == null) return;
    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(1 / 240, 1 / 20);
    final measured = (_pos.value - _jellyPos) / dt;
    _jellyPos = _pos.value;
    _speed = lerpDouble(_speed, measured, 0.35)!;

    final target = math.min(_speed.abs() * _kJellyGain, _kJellyMax);
    final damping = 2 * _kJellyDamping * math.sqrt(_kJellyStiffness);
    final accel =
        _kJellyStiffness * (target - _stretch) - damping * _stretchVel;
    _stretchVel += accel * dt;
    _stretch = (_stretch + _stretchVel * dt).clamp(-0.14, _kJellyMax + 0.1);

    final settled = !_dragging &&
        !_pos.isAnimating &&
        _speed.abs() < 0.01 &&
        _stretch.abs() < 0.002 &&
        _stretchVel.abs() < 0.02;
    if (settled) {
      _speed = _stretch = _stretchVel = 0;
      _jelly.stop();
    }
    _jellyFrame.value++;
  }

  // ----------------------------------------------------------------- hold

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.collapse > 0) return;
    if (_bubbleRect.inflate(4).contains(event.localPosition)) {
      _held = true;
      if (_reduceMotion) {
        _lift.value = 1;
      } else {
        _lift.forward();
      }
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_held) return;
    _held = false;
    if (!_dragging) _lift.reverse();
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
    _wakeJelly();
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
      _wakeJelly();
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
    if (!_held) _lift.reverse();

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
    _wakeJelly();
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

    return LayoutBuilder(builder: (context, outer) {
      final raw = widget.collapse;
      final c = raw.clamp(0.0, 1.0);
      if (raw <= 0 || _expandedWidth == null) _expandedWidth = outer.maxWidth;
      final fullWidth = _expandedWidth!;
      if (raw <= 0) {
        final capsule = Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            _buildCapsule(context, neutral, accent),
            _buildLens(contentWidth: fullWidth, contentHeight: widget.height),
          ],
        );
        if (raw == 0) return capsule;
        // Overshooting on the way back: swell a touch, then settle.
        return Transform.scale(
          scale: 1 - 0.35 * raw,
          alignment: Alignment.bottomCenter,
          child: capsule,
        );
      }

      final size = widget.collapsedSize;
      // Geometry follows any overshoot (past 1 the circle dips smaller);
      // opacities and the glide don't.
      // Past 1, dip relative to the circle itself (not the bar's long
      // travel): ~7% for a typical 5% overshoot.
      final dip = raw > 1 ? math.max(0.85, 1 - 1.5 * (raw - 1)) : 1.0;
      final width = raw > 1 ? size * dip : lerpDouble(fullWidth, size, raw)!;
      final height =
          raw > 1 ? size * dip : lerpDouble(widget.height, size, raw)!;
      final index = _clampIndex(widget.collapsedIndex ?? widget.currentIndex);
      final isCurrent = index == _clampIndex(widget.currentIndex);
      // Slide the tabs so that tab's centre meets the circle's.
      final tabCentre = GlassTabBar.slotCentre(fullWidth, _count, index);
      final dx = c * (size / 2 - tabCentre);
      final item = widget.items[index];
      final contentOpacity = (1 - c / 0.6).clamp(0.0, 1.0);
      // Where the shrinking capsule sits in this box (bottom-left), and
      // where its tabs are (centred vertically in it, slid by dx).
      final boxHeight =
          outer.hasBoundedHeight ? outer.maxHeight : widget.height;
      final capsuleRect =
          Rect.fromLTWH(0, boxHeight - height, width, height);
      final tabsOrigin =
          Offset(dx, capsuleRect.top + (height - widget.height) / 2);

      final bar = Align(
        alignment: Alignment.bottomLeft,
        child: Semantics(
          button: true,
          selected: isCurrent,
          label: item.label,
          onTap: () => widget.onTabSelected(index),
          child: GlassContainer.capsule(
            width: width,
            height: height,
            style: widget.style,
            onTap: () => widget.onTabSelected(index),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The tabs keep their full-width layout; the capsule's edge
                // sweeps over them as it shrinks. Plain Opacity is fine:
                // they aren't glass.
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: fullWidth,
                        maxWidth: fullWidth,
                        minHeight: widget.height,
                        maxHeight: widget.height,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          // Faded per layer inside (the bubble is glass, so
                          // no Opacity may wrap it).
                          child: _buildTabs(context, neutral, accent,
                              hideDetached: true,
                              contentOpacity: contentOpacity),
                        ),
                      ),
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Opacity(
                    opacity: ((c - 0.35) / 0.65).clamp(0.0, 1.0),
                    child: Icon(
                      isCurrent ? item.activeIcon : item.icon,
                      color: isCurrent ? accent : neutral,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      return Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          bar,
          _buildLens(
            contentWidth: fullWidth,
            contentHeight: widget.height,
            origin: tabsOrigin,
            clip: RRect.fromRectAndRadius(
                capsuleRect, Radius.circular(height / 2)),
            visibility: contentOpacity,
          ),
        ],
      );
    });
  }

  /// The selection bubble's rect within tabs laid out [width] x [height]:
  /// its position, lift and jelly stretch. Shared by the tabs (the colour
  /// window) and the lens, so they always line up.
  Rect _bubbleRectIn(double width, double height) {
    final slot = math.max(1.0, (width - 2 * _kBubbleInset) / _count);
    final lift = _lift.value;
    final stretch = _reduceMotion ? 0.0 : _stretch;
    final baseWidth = (slot - _kBubbleInset) * (1 + _kLiftScale * lift);
    return Rect.fromCenter(
      center: Offset(_kBubbleInset + slot * (_pos.value + 0.5), height / 2),
      width: baseWidth * (1 + stretch),
      height: (height - 2 * _kBubbleInset) *
          (1 + _kLiftScale * lift) *
          (1 - 0.4 * stretch),
    );
  }

  /// The bubble's glass lens, drawn **over** the bar rather than inside it.
  ///
  /// Inside the bar's glass it would render into the bar's offscreen
  /// subpass (Impeller sizes it to the bar), where the shader's screen
  /// coordinates are wrong and it samples empty texture: a dark pill. Over
  /// the bar, in its own [BackdropGroup], it reads the finished bar and tabs
  /// on screen and refracts them.
  ///
  /// [origin] maps tab coordinates ([contentWidth] x [contentHeight]) into
  /// this bar's box; [clip] keeps it inside a shrinking capsule.
  Widget _buildLens({
    required double contentWidth,
    required double contentHeight,
    Offset origin = Offset.zero,
    RRect? clip,
    double visibility = 1,
  }) {
    // Not built when nearly faded: glass left at ~0 visibility still shows
    // on Impeller (it can hide what's under it).
    if (!GlassContainer.refractionAvailable || visibility <= 0.02) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pos, _lift, _jellyFrame]),
          builder: (context, _) {
            final rect =
                _bubbleRectIn(contentWidth, contentHeight).shift(origin);
            final Widget lens = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: BackdropGroup(
                    child: GlassContainer.capsule(
                      key: GlassTabBar.bubbleGlassKey,
                      style: _kBubbleGlass.copyWith(
                        refraction: lerpDouble(
                            _kBubbleGlass.refraction,
                            _kBubbleGlass.refraction + 4,
                            _lift.value),
                      ),
                      visibility: visibility,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            );
            if (clip == null) return lens;
            return ClipRRect(
              clipper: _RRectClipper(clip),
              child: lens,
            );
          },
        ),
      ),
    );
  }

  /// The expanded bar.
  Widget _buildCapsule(BuildContext context, Color neutral, Color accent) {
    return GlassContainer.capsule(
      height: widget.height,
      style: widget.style,
      child: _buildTabs(context, neutral, accent),
    );
  }

  /// The tabs, bubble and gestures, laid out in the incoming constraints.
  Widget _buildTabs(BuildContext context, Color neutral, Color accent,
      {bool hideDetached = false, double contentOpacity = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        _slotWidth = math.max(1.0, (width - 2 * _kBubbleInset) / _count);

        return Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerUp,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: _handleDragCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pos, _lift, _jellyFrame]),
            builder: (context, _) {
              final pos = _pos.value;
              final lift = _lift.value;

              // Position, lift and jelly (longer and flatter while moving,
              // wobbling back to round; symmetric, so the centre still
              // tracks the finger exactly).
              final bubbleRect = _bubbleRectIn(width, height);
              _bubbleRect = bubbleRect;
              // With the lens (drawn over the bar, see _buildLens) the
              // bubble is see-through: only its lift shadow is painted here.
              // Without the shader, the painted bubble keeps its fill and
              // lit rim, as before.
              final lens = GlassContainer.refractionAvailable;
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
                            // A detached tab fades over to its own button.
                            child: Opacity(
                              opacity: hideDetached &&
                                      widget.detachedTabs.contains(i)
                                  ? (1 - widget.detachProgress)
                                      .clamp(0.0, 1.0)
                                  : 1,
                              child: _TabSlot(
                                item: widget.items[i],
                                accented: accented,
                                color: accented ? accent : neutral,
                                scale: 1 + 0.12 * lift * _proximity(i, pos),
                              ),
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
                    child: Opacity(
                      opacity: contentOpacity,
                      child: CustomPaint(
                        key: GlassTabBar.bubbleKey,
                        painter: _BubblePainter(
                            isDark: isDark,
                            lift: lift,
                            rim: !lens,
                            fill: !lens),
                      ),
                    ),
                  ),
                  // Neutral tabs, everywhere except under the bubble.
                  Positioned.fill(
                    child: Opacity(
                      opacity: contentOpacity,
                      child: ClipPath(
                        key: GlassTabBar.neutralLayerKey,
                        clipper: _BubbleClipper(bubbleShape, outside: true),
                        child: ExcludeSemantics(child: row(accented: false)),
                      ),
                    ),
                  ),
                  // Accented tabs, only under the bubble.
                  Positioned.fill(
                    child: Opacity(
                      opacity: contentOpacity,
                      child: ClipPath(
                        key: GlassTabBar.accentLayerKey,
                        clipper: _BubbleClipper(bubbleShape, outside: false),
                        child: ExcludeSemantics(child: row(accented: true)),
                      ),
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
          ),
        );
      });
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  const _RRectClipper(this.rrect);

  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_RRectClipper old) => old.rrect != rrect;
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

/// The selection bubble's body, under the tabs: a soft fill (and a shadow
/// while lifted). With the refraction shader, the glass lens over the tabs
/// gives it its rim and refraction; without it ([rim]), this paints a lit
/// rim itself, turning brighter while lifted.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.isDark,
    required this.lift,
    this.rim = true,
    this.fill = true,
  });

  final bool isDark;
  final double lift;
  final bool rim;

  /// Off under the lens, so the bubble is completely see-through.
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(size.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(rect, r);

    if (lift > 0) {
      // Only outside the pill: under a see-through bubble a shadow inside
      // would darken the tabs it's over.
      canvas.save();
      canvas.clipPath(Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(24))
        ..addRRect(shape));
      canvas.drawRRect(
        shape.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: (isDark ? 0.30 : 0.12) * lift)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.restore();
    }

    final fill = isDark
        ? Colors.white.withValues(alpha: lerpDouble(0.14, 0.10, lift)!)
        : Color.lerp(
            Colors.black.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.55),
            lift,
          )!;
    if (this.fill) canvas.drawRRect(shape, Paint()..color = fill);
    if (!rim) return;

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
      old.isDark != isDark ||
      old.lift != lift ||
      old.rim != rim ||
      old.fill != fill;
}
