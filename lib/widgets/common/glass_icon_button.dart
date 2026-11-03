import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:musly/widgets/common/glass_container.dart';

/// A round Liquid Glass icon button.
///
/// Two looks, chosen by [persistent]:
///  * `true`: the glyph sits on a glass disc at all times (toolbar buttons,
///    a toggle that is on). Pressing swells the disc.
///  * `false`: only the glyph shows; while it is pressed a glass disc swells
///    in behind it and then fades away, like iOS 26 playback controls.
///
/// Changing [persistent] fades the disc in or out, so a toggle can show its
/// "on" state with the disc. Changing [icon] cross-fades the glyphs (e.g.
/// play/pause).
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize,
    this.color,
    this.persistent = true,
    this.style = GlassStyle.control,
    this.semanticLabel,
    this.tooltip,
    this.haptic = true,
  });

  final IconData icon;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Diameter of the glass disc, which is also the tap target.
  final double size;

  /// Defaults to 45% of [size].
  final double? iconSize;

  /// Glyph colour. Defaults to white.
  final Color? color;

  final bool persistent;
  final GlassStyle style;
  final String? semanticLabel;
  final String? tooltip;

  /// Light haptic on press.
  final bool haptic;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton>
    with TickerProviderStateMixin {
  /// 0 at rest, 1 while pressed.
  late final AnimationController _press;

  /// 1 while the disc is shown at rest ([GlassIconButton.persistent]).
  late final AnimationController _presence;

  bool _releasePending = false;

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 320),
    )..addStatusListener(_onPressStatus);
    _presence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.persistent ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(GlassIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.persistent != oldWidget.persistent) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _presence.value = widget.persistent ? 1 : 0;
      } else if (widget.persistent) {
        _presence.forward();
      } else {
        _presence.reverse();
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _onPressStatus(AnimationStatus status) {
    // A quick tap still shows the full swell before it fades.
    if (status == AnimationStatus.completed && _releasePending) {
      _releasePending = false;
      _press.reverse();
    }
  }

  /// Starts the press look on the raw pointer-down, so it shows at once even
  /// where competing gestures (page swipes, drag-to-dismiss) hold back the
  /// tap's own down event.
  void _down(PointerDownEvent _) {
    if (!_enabled) return;
    _releasePending = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = 1;
    } else {
      _press.forward();
    }
  }

  void _release() {
    if (_press.isAnimating && _press.status == AnimationStatus.forward) {
      _releasePending = true;
    } else {
      _press.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final iconSize = widget.iconSize ?? size * 0.45;
    final color = widget.color ?? Colors.white;

    Widget button = AnimatedBuilder(
      animation: Listenable.merge([_press, _presence]),
      builder: (context, _) {
        final press = Curves.easeOut.transform(_press.value);
        final presence = Curves.easeOut.transform(_presence.value);
        // How visible the disc is, and how far it has swollen.
        final shown = presence > press ? presence : press;
        final discScale = (0.72 + 0.28 * shown) * (1 + 0.1 * press);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (shown > 0)
              Transform.scale(
                scale: discScale,
                // Faded via `visibility`, not Opacity: see
                // GlassContainer.visibility.
                child: GlassContainer.capsule(
                  width: size,
                  height: size,
                  style: widget.style,
                  visibility: shown,
                  child: const SizedBox.expand(),
                ),
              ),
            Transform.scale(
              scale: 1 - 0.08 * press,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  key: ValueKey<IconData>(widget.icon),
                  size: iconSize,
                  color: _enabled ? color : color.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        );
      },
    );

    button = Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.tooltip,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: _down,
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (_enabled && widget.haptic) HapticFeedback.lightImpact();
            },
            onTapUp: (_) {
              if (_enabled) widget.onPressed!();
            },
            // A swipe that starts on the button lets go of it.
            onTapCancel: _release,
            child: SizedBox.square(dimension: size, child: button),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}
