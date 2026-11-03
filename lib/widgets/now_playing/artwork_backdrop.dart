import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Now-playing background in the Liquid Glass look: the current artwork,
/// heavily blurred and saturated, filling the screen and drifting slowly,
/// like Apple Music. It gives the glass controls real colour to sit on.
///
/// The artwork is decoded tiny (it ends up blurred anyway) and cross-fades
/// when the track changes. A scrim darkens it, more toward the bottom and
/// more for bright artwork, so the white controls stay legible.
class ArtworkBackdrop extends StatefulWidget {
  const ArtworkBackdrop({
    super.key,
    required this.image,
    required this.child,
    this.brightness,
  });

  final ImageProvider image;
  final Widget child;

  /// Relative luminance (0..1) of the artwork's dominant colour, if known.
  /// Brighter artwork gets a darker scrim.
  final double? brightness;

  @override
  State<ArtworkBackdrop> createState() => _ArtworkBackdropState();
}

class _ArtworkBackdropState extends State<ArtworkBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        RepaintBoundary(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, if (current != null) current],
              ),
              child: _BlurredArtwork(
                key: ValueKey<ImageProvider>(widget.image),
                image: widget.image,
                drift: _drift,
              ),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
              end: (widget.brightness ?? 0.2).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          builder: (context, lum, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30 + 0.25 * lum),
                  Colors.black.withValues(alpha: 0.22 + 0.36 * lum),
                  Colors.black.withValues(alpha: 0.58 + 0.24 * lum),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlurredArtwork extends StatelessWidget {
  const _BlurredArtwork({
    super.key,
    required this.image,
    required this.drift,
  });

  final ImageProvider image;
  final Animation<double> drift;

  static final ui.ImageFilter _filter = ui.ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate),
    inner: ui.ImageFilter.blur(
      sigmaX: 36,
      sigmaY: 36,
      tileMode: TileMode.clamp,
    ),
  );

  // Saturation 1.35 (Rec. 709 luminance weights).
  static const List<double> _saturate = <double>[
    1.2756, -0.2503, -0.0253, 0, 0, //
    -0.0744, 1.0997, -0.0253, 0, 0, //
    -0.0744, -0.2503, 1.3247, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drift,
      builder: (context, child) {
        final a = drift.value * 2 * math.pi;
        final size = MediaQuery.sizeOf(context);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(
                size.width * 0.05 * math.cos(a),
                size.height * 0.04 * math.sin(a),
                0,
                1)
            ..rotateZ(0.08 * math.sin(a))
            ..scaleByDouble(
                1.5 + 0.1 * math.sin(2 * a), 1.5 + 0.1 * math.sin(2 * a), 1, 1),
          child: child,
        );
      },
      child: ImageFiltered(
        imageFilter: _filter,
        child: Image(
          image: ResizeImage(image, width: 64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
