import 'package:flutter/material.dart';

/// Bar thickness while idle. The old sliders used a 4px track.
const double kThickBarIdleThickness = 6.0;

/// Bar thickness while a finger is on the bar or dragging it.
const double kThickBarActiveThickness = 12.0;

/// Height of the touch target the bar is centred in.
const double kThickBarHitHeight = 30.0;

/// How long the bar takes to grow or shrink between the two thicknesses.
const Duration kThickBarResizeDuration = Duration(milliseconds: 200);

/// A thumb-less, bar-style slider shared by the now-playing scrubber and the
/// volume slider, so both look and behave the same.
///
/// The fill and the bar's thickness are the only position indicator: there's
/// no handle. The bar is [kThickBarIdleThickness] at rest and grows to
/// [kThickBarActiveThickness] while it's touched or dragged.
///
/// Interaction mirrors the old sliders:
/// - **Tap** (`onTapDown`): [onChangeStart], [onChanged] and [onChangeEnd]
///   fire in a row with the tapped value.
/// - **Horizontal drag**: [onChangeStart] with [value], [onChanged] with the
///   finger's position as soon as the drag is recognised and on every update,
///   then [onChangeEnd] with the last dragged value.
///
/// While dragging, the bar shows its own drag value, so a parent that doesn't
/// feed [onChanged] back into [value] (e.g. a scrubber that only seeks on
/// release) still tracks the finger.
class ThickBarSlider extends StatefulWidget {
  const ThickBarSlider({
    super.key,
    required this.value,
    required this.activeColor,
    this.inactiveColor,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
    this.semanticLabel,
  });

  /// Current position, 0..1. Values outside are clamped.
  final double value;

  /// Fill colour.
  final Color activeColor;

  /// Track colour behind the fill. Defaults to white at 30%.
  final Color? inactiveColor;

  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  final String? semanticLabel;

  @override
  State<ThickBarSlider> createState() => _ThickBarSliderState();
}

class _ThickBarSliderState extends State<ThickBarSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _active = AnimationController(
    vsync: this,
    duration: kThickBarResizeDuration,
  );
  late final Animation<double> _activeCurve = CurvedAnimation(
    parent: _active,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  bool _pointerDown = false;
  bool _dragging = false;
  double _dragValue = 0.0;

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  void _syncActive() {
    final active = _pointerDown || _dragging;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _active.value = active ? 1.0 : 0.0;
    } else if (active) {
      _active.forward();
    } else {
      _active.reverse();
    }
  }

  double _valueAt(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    if (width <= 0) return 0.0;
    return (localPosition.dx.clamp(0.0, width) / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final shown = (_dragging ? _dragValue : widget.value).clamp(0.0, 1.0);
    final inactive =
        widget.inactiveColor ?? Colors.white.withValues(alpha: 0.3);

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: '${(shown * 100).round()}%',
      child: Listener(
        // Grow on first contact, before the gesture arena decides between a
        // tap and a drag.
        onPointerDown: (_) {
          _pointerDown = true;
          _syncActive();
        },
        onPointerUp: (_) {
          _pointerDown = false;
          _syncActive();
        },
        onPointerCancel: (_) {
          _pointerDown = false;
          _syncActive();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            final start = widget.value.clamp(0.0, 1.0);
            final v = _valueAt(details.localPosition);
            setState(() {
              _dragging = true;
              _dragValue = v;
            });
            _syncActive();
            widget.onChangeStart?.call(start);
            // Jump to the finger now rather than on the first update.
            widget.onChanged?.call(v);
          },
          onHorizontalDragUpdate: (details) {
            final v = _valueAt(details.localPosition);
            setState(() => _dragValue = v);
            widget.onChanged?.call(v);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            _syncActive();
            widget.onChangeEnd?.call(_dragValue);
          },
          onHorizontalDragCancel: () {
            if (!_dragging) return;
            setState(() => _dragging = false);
            _syncActive();
            widget.onChangeEnd?.call(_dragValue);
          },
          onTapDown: (details) {
            final v = _valueAt(details.localPosition);
            widget.onChangeStart?.call(v);
            widget.onChanged?.call(v);
            widget.onChangeEnd?.call(v);
          },
          child: SizedBox(
            height: kThickBarHitHeight,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ThickBarPainter(
                  value: shown,
                  active: _activeCurve,
                  activeColor: widget.activeColor,
                  inactiveColor: inactive,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThickBarPainter extends CustomPainter {
  _ThickBarPainter({
    required this.value,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  }) : super(repaint: active);

  final double value;
  final Animation<double> active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final thickness = Tween<double>(
      begin: kThickBarIdleThickness,
      end: kThickBarActiveThickness,
    ).transform(active.value);
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        (size.height - thickness) / 2,
        size.width,
        thickness,
      ),
      Radius.circular(thickness / 2),
    );

    canvas.drawRRect(bar, Paint()..color = inactiveColor);

    final fillWidth = size.width * value;
    if (fillWidth <= 0) return;
    // The fill is clipped to the bar, so its leading end follows the bar's
    // rounded cap and its trailing edge is a straight cut: the position reads
    // from where the fill stops, with no handle.
    canvas.save();
    canvas.clipRRect(bar);
    canvas.drawRect(
      Rect.fromLTWH(0, bar.top, fillWidth, thickness),
      Paint()..color = activeColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThickBarPainter old) =>
      old.value != value ||
      old.active != active ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}
