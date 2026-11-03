import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:musly/widgets/common/glass_container.dart';

/// Opening from the mini-player: quick, with barely any overshoot.
final SpringDescription _kOpenSpring =
    SpringDescription.withDampingRatio(mass: 1, stiffness: 230, ratio: 0.88);

/// Closing from a button or the system back gesture. Softer than the open,
/// so the slide down and the merge back up both get time to read, with a
/// little give as the merge lands.
final SpringDescription _kCloseSpring =
    SpringDescription.withDampingRatio(mass: 1, stiffness: 110, ratio: 0.72);

/// After a drag is released, either way. Softer damping gives a gentle
/// overshoot: the capsule wobbles as it lands the merge, or the player
/// swells a touch before settling open.
final SpringDescription _kSettleSpring =
    SpringDescription.withDampingRatio(mass: 1, stiffness: 125, ratio: 0.62);

const Tolerance _kTolerance = Tolerance(distance: 0.0015, velocity: 0.02);

/// A release this fast downward (px/s) always dismisses.
const double _kDismissVelocity = 700;

/// A release past this much drag (pt) dismisses unless the finger was
/// moving back up.
const double _kDismissDistance = 150;

/// How much the mini-player capsule swells as it swallows the player.
const double _kGulpSwell = 0.055;

/// How far (pt) the capsule stretches down to reach for the rising player.
const double _kReach = 18;

/// The neck between the capsule and the rising player starts forming when
/// they're this close (pt), like Liquid Glass shapes within a container's
/// spacing.
const double _kNeckSpacing = 110;

/// Corner radius of the sheet once it's off its rest position.
const double _kSheetCornerRadius = 44;

/// Closing: progress at which the player has slid off the bottom of the
/// screen. Above it the player slides down; below it, it rises back up into
/// the mini-player as a liquid blob.
const double kNowPlayingMergeStart = 0.4;

/// The mini-player's artwork: where the now-playing art flies from on open.
/// Hidden while the art is in flight so there's only ever one copy.
class NowPlayingArtAnchor extends StatefulWidget {
  const NowPlayingArtAnchor({
    super.key,
    required this.child,
    this.borderRadius = 10,
  });

  final Widget child;

  /// Corner radius of [child], so the flying art starts out matching it.
  final double borderRadius;

  /// True while the now-playing art is flying from this anchor.
  static final ValueNotifier<bool> sourceHidden = ValueNotifier<bool>(false);

  static _NowPlayingArtAnchorState? _current;

  @override
  State<NowPlayingArtAnchor> createState() => _NowPlayingArtAnchorState();
}

class _NowPlayingArtAnchorState extends State<NowPlayingArtAnchor> {
  @override
  void initState() {
    super.initState();
    NowPlayingArtAnchor._current = this;
  }

  @override
  void dispose() {
    if (NowPlayingArtAnchor._current == this) {
      NowPlayingArtAnchor._current = null;
    }
    super.dispose();
  }

  RenderBox? get _box => _attachedBox(context);

  @override
  Widget build(BuildContext context) {
    // A later mount (e.g. after a layout switch) takes over as the source.
    NowPlayingArtAnchor._current = this;
    return ValueListenableBuilder<bool>(
      valueListenable: NowPlayingArtAnchor.sourceHidden,
      child: widget.child,
      builder: (context, hidden, child) => Visibility(
        visible: !hidden,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child!,
      ),
    );
  }
}

/// The whole mini-player surface (the glass capsule, or the classic bar):
/// the shape the player grows out of when it opens and merges back into when
/// it closes. While closing it stretches down to reach for the rising
/// player ([reach]) and swells as it swallows it ([gulp]).
///
/// Its rect is measured live, so any layout of the mini-player works,
/// including the collapsed chrome's narrower 52pt capsule.
class NowPlayingCapsuleAnchor extends StatefulWidget {
  const NowPlayingCapsuleAnchor({
    super.key,
    required this.child,
    this.capsule = true,
    this.borderRadius = 0,
    this.inset = EdgeInsets.zero,
  });

  final Widget child;

  /// Padding around the surface inside [child]; the measured shape is
  /// [child]'s box deflated by it.
  final EdgeInsets inset;

  /// A pill: the corner radius is half the measured height.
  final bool capsule;

  /// The corner radius when not a [capsule].
  final double borderRadius;

  /// 0..1, set by the transition: how far into its swallow swell it is.
  static final ValueNotifier<double> gulp = ValueNotifier<double>(0);

  /// How far the capsule is stretched down, as a fraction of its height,
  /// set by the transition while it reaches for the rising player.
  static final ValueNotifier<double> reach = ValueNotifier<double>(0);

  static _NowPlayingCapsuleAnchorState? _current;

  @override
  State<NowPlayingCapsuleAnchor> createState() =>
      _NowPlayingCapsuleAnchorState();
}

class _NowPlayingCapsuleAnchorState extends State<NowPlayingCapsuleAnchor> {
  static final Listenable _motion = Listenable.merge(
      [NowPlayingCapsuleAnchor.gulp, NowPlayingCapsuleAnchor.reach]);

  @override
  void initState() {
    super.initState();
    NowPlayingCapsuleAnchor._current = this;
  }

  @override
  void dispose() {
    if (NowPlayingCapsuleAnchor._current == this) {
      NowPlayingCapsuleAnchor._current = null;
    }
    super.dispose();
  }

  /// The unstretched box: the swell and reach are a paint transform inside.
  RenderBox? get _box => _attachedBox(context);

  /// The surface's rect in [root]'s coordinates, and its corner radius.
  (Rect, double)? shapeIn(RenderBox root) {
    final box = _box;
    if (box == null) return null;
    final rect = widget.inset.deflateRect(
        root.globalToLocal(box.localToGlobal(Offset.zero)) & box.size);
    return (
      rect,
      widget.capsule ? rect.shortestSide / 2 : widget.borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    NowPlayingCapsuleAnchor._current = this;
    return AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, child) {
        final g = NowPlayingCapsuleAnchor.gulp.value;
        final stretch = NowPlayingCapsuleAnchor.reach.value;
        // Hung from its top edge: it swells, and stretches (narrowing a
        // little, like a drop) down toward the merge.
        final sx = 1 + _kGulpSwell * g - 0.12 * stretch;
        final sy = 1 + _kGulpSwell * g + stretch;
        return Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.diagonal3Values(sx, sy, 1),
          child: child,
        );
      },
    );
  }
}

RenderBox? _attachedBox(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.attached && box.hasSize ? box : null;
}

/// A transparent full-screen route for the now-playing view. It has no
/// transition of its own: [NowPlayingTransition] animates the view in and out.
class NowPlayingRoute<T> extends PageRoute<T> {
  NowPlayingRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get allowSnapshotting => false;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      NowPlayingTransition(child: Builder(builder: builder));

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}

/// One frame of the transition: where the player sheet is and how it looks.
@immutable
class NowPlayingFrame {
  const NowPlayingFrame({
    required this.sheet,
    required this.contentOrigin,
    required this.scale,
    required this.radius,
    this.opacity = 1,
    this.contentOpacity = 1,
    this.glassPresence = 1,
    this.reach = 0,
    this.gulp = 0,
    this.neck,
    this.swallow,
  });

  /// The visible sheet (or, while merging, the liquid blob), on screen.
  final Rect sheet;

  /// Where the player's top-left corner sits on screen.
  final Offset contentOrigin;

  /// Uniform scale of the player.
  final double scale;

  /// Corner radius of [sheet], on screen.
  final double radius;

  /// The whole sheet's opacity.
  final double opacity;

  /// The player's controls and pages (the backdrop is always shown).
  final double contentOpacity;

  /// See [GlassPresence]. Only above 0 while both opacities are 1.
  final double glassPresence;

  /// Points the capsule stretches down by.
  final double reach;

  /// The capsule's swallow swell (0..1).
  final double gulp;

  /// The liquid neck joining the capsule and the rising blob, on screen.
  final Path? neck;

  /// While merging: the capsule's (stretched, swollen) shape, cut out of the
  /// blob so the blob disappears *into* the capsule instead of covering it.
  final RRect? swallow;

  /// The visible shape, in the player's own (unscaled) coordinates.
  Path clipPath() {
    var path = Path()
      ..addRRect(RRect.fromRectAndRadius(sheet, Radius.circular(radius)));
    if (neck != null) path.addPath(neck!, Offset.zero);
    if (swallow != null) {
      path = Path.combine(
          PathOperation.difference, path, Path()..addRRect(swallow!));
    }
    final m = Matrix4.identity()
      ..scaleByDouble(1 / scale, 1 / scale, 1, 1)
      ..translateByDouble(-contentOrigin.dx, -contentOrigin.dy, 0, 1);
    return path.transform(m.storage);
  }
}

/// The now-playing open/close animation.
///
/// Everything is driven by one unbounded [AnimationController], the
/// progress `p`: 0 is merged into the mini-player, 1 is fully open. Every
/// visual is a pure function of `p` ([openFrame], [closeFrame], [artRect]),
/// so a drag simply writes `p`, a release hands the finger's velocity to a
/// spring on the same `p`, and a drag can grab the view mid-flight.
///
/// It plays two paths, like iOS 26's Music:
///  * **Opening** ([openFrame]): the art flies out of the mini-player's art
///    to its place while the player grows up out of the capsule.
///  * **Closing** ([closeFrame]): the whole player stays opaque and slides
///    all the way off the bottom of the screen, revealing the mini-player;
///    then its material rises back up as a liquid blob. The capsule
///    stretches down to reach for it, a neck forms between them like two
///    Liquid Glass shapes merging, and the capsule swells as it swallows
///    the blob.
/// The open path is used until the player first settles open; from then on
/// it's the close path. Both are the full sheet at `p` = 1, so the switch is
/// invisible, and a gesture during either keeps that path's geometry.
///
/// [NowPlayingScreen] cooperates through [maybeOf]: it hands its backdrop
/// and content to [wrapSheet] and its artwork to [wrapArt], and routes its
/// close button and vertical drags here.
class NowPlayingTransition extends StatefulWidget {
  const NowPlayingTransition({super.key, required this.child});

  final Widget child;

  /// Key of the flying copy of the artwork (for tests).
  static const Key flyingArtKey = ValueKey<String>('now-playing-flying-art');

  /// Key of the sheet's opacity layer (for tests).
  static const Key sheetKey = ValueKey<String>('now-playing-sheet');

  static NowPlayingTransitionState? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_NowPlayingTransitionScope>()
      ?.state;

  // --- Opening path ---

  /// How far the sheet's sides and bottom have drawn in toward the capsule:
  /// 1 when open, 0 merged. Packed into the last stretch.
  static double compaction(double p) {
    final q = 1 - p.clamp(0.0, 1.0);
    return 1 - q * q * q * q;
  }

  /// Opening: the sheet grows out of the capsule. Its top edge travels
  /// linearly from the capsule's top to the screen top; its bottom and sides
  /// spread out with [compaction].
  static Rect sheetRect(double p, Size full, Rect capsule) {
    final q = p.clamp(0.0, 1.0);
    final e = compaction(q);
    return Rect.fromLTRB(
      lerpDouble(capsule.left, 0, e)!,
      (1 - q) * capsule.top,
      lerpDouble(capsule.right, full.width, e)!,
      lerpDouble(capsule.bottom, full.height, e)!,
    );
  }

  static double sheetRadius(double p, double capsuleRadius) {
    if (p >= 1) return 0;
    final q = p.clamp(0.0, 1.0);
    final r = lerpDouble(
        capsuleRadius, _kSheetCornerRadius, (q / 0.35).clamp(0.0, 1.0))!;
    return r * ((1 - q) * 12).clamp(0.0, 1.0);
  }

  /// Opening: the sheet only fades over the very first stretch, at the
  /// capsule.
  static double sheetOpacity(double p) =>
      Curves.easeOut.transform((p / 0.12).clamp(0.0, 1.0));

  static double glassPresence(double p) => ((p - 0.12) / 0.08).clamp(0.0, 1.0);

  /// Opening: the capsule bulges as the player pushes out of it.
  static double capsuleGulp(double p) {
    if (p > 0 && p < 0.2) return math.sin(math.pi * p / 0.2);
    return 0;
  }

  static NowPlayingFrame openFrame(
      double p, Size full, Rect capsule, double capsuleRadius) {
    if (p >= 1) return _restFrame(p, full);
    final gulp = capsuleGulp(p);
    final sheet =
        sheetRect(p, full, _scaled(capsule, 1 + _kGulpSwell * gulp));
    return NowPlayingFrame(
      sheet: sheet,
      contentOrigin: sheet.topLeft,
      scale: (sheet.width / full.width).clamp(0.01, 1.0),
      radius: sheetRadius(p, capsuleRadius),
      opacity: sheetOpacity(p),
      glassPresence: glassPresence(p),
      gulp: gulp,
    );
  }

  /// Open, or overshooting past open: the full screen; an overshoot swells
  /// the player very slightly (it never moves, so no gap can open).
  static NowPlayingFrame _restFrame(double p, Size full) {
    final k = 1 + 0.4 * math.min(math.max(p - 1, 0.0), 0.08);
    return NowPlayingFrame(
      sheet: Offset.zero & full,
      contentOrigin: Offset(full.width * (1 - k) / 2, 0),
      scale: k,
      radius: 0,
    );
  }

  // --- Closing path ---

  /// Closing. Above [kNowPlayingMergeStart] the opaque player slides down,
  /// its top edge travelling linearly to the screen bottom (so it tracks the
  /// finger). Below it, a blob of the player's material rises from the
  /// bottom edge into the capsule, with the capsule reaching down for it
  /// and a neck joining them.
  static NowPlayingFrame closeFrame(
      double p, Size full, Rect capsule, double capsuleRadius) {
    const b = kNowPlayingMergeStart;
    if (p >= 1) return _restFrame(p, full);
    if (p >= b) {
      final a = (p - b) / (1 - b); // 1 open .. 0 off the bottom
      final top = (1 - a) * full.height;
      final content = ((p - b) / 0.06).clamp(0.0, 1.0);
      return NowPlayingFrame(
        sheet: Rect.fromLTRB(0, top, full.width, full.height),
        contentOrigin: Offset(0, top),
        scale: 1,
        radius: _kSheetCornerRadius * ((1 - p) * 12).clamp(0.0, 1.0),
        contentOpacity: content,
        glassPresence: ((p - b - 0.06) / 0.04).clamp(0.0, 1.0),
      );
    }

    final u = (p / b).clamp(0.0, 1.0); // 1 at the bottom edge .. 0 merged
    final blobH = lerpDouble(capsule.height, capsule.height * 1.5, u)!;
    final blobW = lerpDouble(capsule.width, full.width, u)!;
    final blobTop = lerpDouble(capsule.top, full.height, u)!;
    final blobCx = lerpDouble(capsule.center.dx, full.width / 2, u)!;
    final blob = Rect.fromLTWH(blobCx - blobW / 2, blobTop, blobW, blobH);
    final radius = math.min(
        lerpDouble(capsuleRadius, _kSheetCornerRadius, u)!, blobH / 2);

    final reach = _kReach * reachAmount(u);
    final neck = _neck(capsule, capsuleRadius, reach, blob, radius, full);

    final double gulp;
    if (p < 0) {
      gulp = math.min(1.0, -p / 0.03); // the landing wobble
    } else if (u < 0.35) {
      gulp = math.sin(math.pi * u / 0.35);
    } else {
      gulp = 0;
    }

    // The capsule as it's drawn: hung from its top, swollen and stretched
    // (see NowPlayingCapsuleAnchor).
    final stretch = reach / math.max(1.0, capsule.height);
    final sw = capsule.width * (1 + _kGulpSwell * gulp - 0.12 * stretch);
    final sh = capsule.height * (1 + _kGulpSwell * gulp + stretch);
    final swallow = RRect.fromRectAndRadius(
      Rect.fromLTWH(capsule.center.dx - sw / 2, capsule.top, sw, sh),
      Radius.circular(math.min(capsuleRadius, sh / 2)),
    );

    final s = (blob.width / full.width).clamp(0.01, 1.0);
    // Anchor the player's (backdrop) texture at the top of the neck, so the
    // neck has material to show; it's within the player's box either way.
    final originY = math.min(blob.top, capsule.bottom + reach - 4);
    return NowPlayingFrame(
      sheet: blob,
      contentOrigin: Offset(blob.left, originY),
      scale: s,
      radius: radius,
      opacity: Curves.easeOut.transform((u / 0.2).clamp(0.0, 1.0)),
      contentOpacity: 0,
      glassPresence: 0,
      reach: reach,
      gulp: gulp,
      neck: neck,
      swallow: swallow,
    );
  }

  /// 0..1: the capsule reaches down as the blob rises into view, holds while
  /// they join, and lets go as they fuse.
  static double reachAmount(double u) {
    double smooth(double a, double b, double x) {
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    return smooth(1.0, 0.65, u) * smooth(0.12, 0.42, u);
  }

  /// A pinched liquid bridge between the capsule's (stretched) bottom and
  /// the blob's top: thin when they first sense each other, swelling to a
  /// full join as the gap closes, the way Liquid Glass shapes merge.
  static Path? _neck(Rect capsule, double capsuleRadius, double reach,
      Rect blob, double blobRadius, Size full) {
    final topY = capsule.bottom + reach - 3;
    final botY = blob.top + 3;
    if (botY - topY < 2) return null;
    final gap = blob.top - (capsule.bottom + reach);
    final fuse = (1 - gap / _kNeckSpacing).clamp(0.0, 1.0);
    final emerged = ((full.height - blob.top) / 14).clamp(0.0, 1.0);
    if (fuse <= 0 || emerged <= 0) return null;
    final base = math.max(
        12.0,
        math.min(capsule.width - 2 * capsuleRadius,
            blob.width - 2 * blobRadius));
    final end = base * (0.3 + 0.7 * fuse) * emerged;
    final waist = end * (0.12 + 0.88 * fuse * fuse);
    final cxTop = capsule.center.dx;
    final cxBot = blob.center.dx;
    final midY = (topY + botY) / 2;
    final cxMid = (cxTop + cxBot) / 2;
    // A quadratic through the waist at its midpoint.
    final ctrl = 2 * (waist / 2) - end / 2;
    return Path()
      ..moveTo(cxTop - end / 2, topY)
      ..quadraticBezierTo(cxMid - ctrl, midY, cxBot - end / 2, botY)
      ..lineTo(cxBot + end / 2, botY)
      ..quadraticBezierTo(cxMid + ctrl, midY, cxTop + end / 2, topY)
      ..close();
  }

  // --- Art (opening) ---

  /// How far the art has morphed from the source to the destination (0..1).
  static double artMorph(double p) {
    final q = p.clamp(0.0, 1.0);
    return 1 - (1 - q) * (1 - q);
  }

  /// Opening: the flying art's rect, from the mini-player's art to its place.
  /// Rides a share of the sheet's travel ([travel], the capsule's top) so a
  /// drag that catches it moves it with the finger.
  static Rect artRect(double p, Rect source, Rect dest, double travel) {
    if (p >= 1) {
      final k = 1 + 0.4 * math.min(p - 1, 0.08);
      return _scaled(dest, k);
    }
    if (p <= 0) return source;
    final follow = travel * (1 - p) * p;
    return Rect.lerp(source, dest.shift(Offset(0, follow)), artMorph(p))!;
  }

  static Rect _scaled(Rect r, double k) => k == 1
      ? r
      : Rect.fromCenter(
          center: r.center, width: r.width * k, height: r.height * k);

  @override
  State<NowPlayingTransition> createState() => NowPlayingTransitionState();
}

class NowPlayingTransitionState extends State<NowPlayingTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p =
      AnimationController.unbounded(vsync: this, value: 0)..addListener(_onTick);
  final ValueNotifier<double> _presence = ValueNotifier<double>(0);
  final ValueNotifier<bool> _artHidden = ValueNotifier<bool>(false);

  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _artKey = GlobalKey();

  Rect? _source;
  double _sourceRadius = 10;
  bool _sourceIsAnchor = false;
  Rect? _dest;

  Rect? _capsule;
  double _capsuleRadius = 30;
  bool _capsuleIsAnchor = false;

  ImageProvider? _image;
  double _artScale = 1;
  double _artRadius = 16;

  Size _size = const Size(400, 800);
  bool _reduceMotion = false;
  bool _started = false;
  bool _dragging = false;
  bool _closing = false;
  bool _popped = false;

  /// Whether the close path is in effect (from the first settle open on).
  bool _closePath = false;
  int _motion = 0;

  /// The progress controller (0 = in the mini-player, 1 = open).
  Animation<double> get progress => _p;

  /// Whether the close path (slide down, then merge up) is in effect.
  bool get closePath => _closePath;

  /// The current frame's geometry.
  NowPlayingFrame get frame => _frameAt(_p.value);

  Rect get _capsuleRect => _capsule ?? _fallbackCapsule();

  Rect _fallbackCapsule() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Rect.fromLTWH(
        12, _size.height - bottom - 140, _size.width - 24, 60);
  }

  /// Progress per point of drag: the sheet's top edge follows the finger.
  double get _progressPerPoint => _closePath
      ? (1 - kNowPlayingMergeStart) / _size.height
      : 1 / math.max(120.0, _capsuleRect.top);

  NowPlayingFrame _frameAt(double p) => _closePath
      ? NowPlayingTransition.closeFrame(
          p, _size, _capsuleRect, _capsuleRadius)
      : NowPlayingTransition.openFrame(
          p, _size, _capsuleRect, _capsuleRadius);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _closePath = true;
      _p.value = 1;
    } else {
      // One frame at p = 0 lays the screen out, so the art's destination is
      // known before it starts to fly.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dragging) _runSpring(1, _kOpenSpring, 0);
      });
    }
  }

  @override
  void dispose() {
    _releaseAnchors();
    _p.dispose();
    _presence.dispose();
    _artHidden.dispose();
    super.dispose();
  }

  // --- Cooperation with NowPlayingScreen ---

  /// The player as one sheet: [backdrop] behind [content], moved, clipped
  /// and faded together with the progress. Glass inside [content] is
  /// switched off (see [GlassPresence]) whenever a fade is fractional.
  Widget wrapSheet({required Widget backdrop, required Widget content}) {
    return AnimatedBuilder(
      animation: _p,
      child: RepaintBoundary(
        key: _contentKey,
        child: Stack(
          children: [
            Positioned.fill(child: RepaintBoundary(child: backdrop)),
            Positioned.fill(
              child: _ContentFade(
                transition: this,
                child: GlassPresence(presence: _presence, child: content),
              ),
            ),
          ],
        ),
      ),
      builder: (context, child) {
        final f = _frameAt(_p.value);
        final settled =
            f.radius == 0 && f.neck == null && f.sheet == Offset.zero & _size;
        // The structure never changes, so the backdrop's state survives.
        return IgnorePointer(
          ignoring: _closing,
          child: Opacity(
            key: NowPlayingTransition.sheetKey,
            opacity: f.opacity,
            child: Transform(
              transform: Matrix4.translationValues(
                  f.contentOrigin.dx, f.contentOrigin.dy, 0)
                ..scaleByDouble(f.scale, f.scale, 1, 1),
              child: ClipPath(
                clipper: _SheetClipper(f),
                clipBehavior: settled ? Clip.none : Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Marks the screen's artwork as the destination and hides it while the
  /// flying copy stands in for it. [art]'s layout box must be the unscaled
  /// artwork square.
  Widget wrapArt(Widget art) {
    return KeyedSubtree(
      key: _artKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: _artHidden,
        child: art,
        builder: (context, hidden, child) => Visibility(
          visible: !hidden,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: child!,
        ),
      ),
    );
  }

  /// What the flying art shows. [scale] is the screen's paint-time scale of
  /// the art (it shrinks while paused). Safe to call during build.
  void updateArt({
    required ImageProvider image,
    double scale = 1,
    double radius = 16,
  }) {
    _image = image;
    _artScale = scale;
    _artRadius = radius;
  }

  /// Slides down and merges back into the mini-player, then pops the route.
  void close() {
    if (_popped || (_closing && !_dragging && _p.isAnimating)) return;
    if (_reduceMotion) {
      _finish();
      return;
    }
    _runSpring(0, _kCloseSpring, 0);
  }

  void handleDragStart(DragStartDetails details) {
    if (_popped) return;
    _motion++;
    _p.stop();
    _dragging = true;
    _closing = false;
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (_popped || !_dragging) return;
    var dp = -details.delta.dy * _progressPerPoint;
    final p = _p.value;
    // Rubber band when pulled up past fully open.
    if (dp > 0 && p >= 1) dp *= 0.15;
    // A finger can take the player down to the bottom edge; the merge back
    // up is the release's job.
    final floor = _closePath ? kNowPlayingMergeStart : 0.0;
    _p.value = (p + dp).clamp(math.min(floor, p), 1.04);
  }

  void handleDragEnd(DragEndDetails details) {
    if (_popped || !_dragging) return;
    _dragging = false;
    final v = details.velocity.pixelsPerSecond.dy;
    final dragged = (1 - _p.value) / _progressPerPoint;
    final dismiss = v > _kDismissVelocity ||
        (dragged > _kDismissDistance && v > -300);
    if (_reduceMotion) {
      if (dismiss) {
        _finish();
      } else {
        _p.value = 1;
      }
      return;
    }
    _runSpring(dismiss ? 0 : 1, _kSettleSpring, -v * _progressPerPoint);
  }

  void handleDragCancel() => handleDragEnd(DragEndDetails());

  // --- Internals ---

  void _runSpring(double target, SpringDescription spring, double velocity) {
    if (_popped) return;
    final motion = ++_motion;
    _closing = target == 0;
    _measure();
    final sim = SpringSimulation(spring, _p.value, target, velocity,
        tolerance: _kTolerance);
    _p.animateWith(sim).then((_) {
      if (!mounted || motion != _motion) return;
      _p.value = target;
      if (target == 0) {
        _finish();
      } else {
        // Settled open: from now on, closing slides down and merges up.
        _closePath = true;
      }
    });
  }

  void _releaseAnchors() {
    if (_sourceIsAnchor) NowPlayingArtAnchor.sourceHidden.value = false;
    if (_capsuleIsAnchor) {
      NowPlayingCapsuleAnchor.gulp.value = 0;
      NowPlayingCapsuleAnchor.reach.value = 0;
    }
    _sourceIsAnchor = false;
    _capsuleIsAnchor = false;
  }

  void _finish() {
    if (_popped) return;
    _popped = true;
    _artHidden.value = false;
    _releaseAnchors();
    Navigator.of(context).pop();
  }

  void _onTick() {
    if (_popped) return;
    final p = _p.value;
    _measure();
    final f = _frameAt(p);
    _presence.value = f.glassPresence;
    // The art flies only on the open path; closing, it rides the player.
    final flying = !_closePath && _dest != null && (p - 1).abs() > 1e-4;
    _artHidden.value = flying;
    final hideSource = flying && _sourceIsAnchor;
    if (NowPlayingArtAnchor.sourceHidden.value != hideSource) {
      NowPlayingArtAnchor.sourceHidden.value = hideSource;
    }
    if (_capsuleIsAnchor) {
      NowPlayingCapsuleAnchor.gulp.value = f.gulp;
      NowPlayingCapsuleAnchor.reach.value =
          f.reach / math.max(1.0, _capsuleRect.height);
    }
  }

  /// Reads the capsule, the art's source and its destination from last
  /// frame's layout.
  void _measure() {
    final root = _box(_rootKey);
    if (root == null) return;

    final shape = NowPlayingCapsuleAnchor._current?.shapeIn(root);
    if (shape != null) {
      _capsule = shape.$1;
      _capsuleRadius = shape.$2;
      _capsuleIsAnchor = true;
    } else {
      _capsule = null;
      _capsuleRadius = 30;
      _capsuleIsAnchor = false;
    }

    final artAnchor = NowPlayingArtAnchor._current;
    final anchorBox = artAnchor?._box;
    if (anchorBox != null) {
      _source =
          root.globalToLocal(anchorBox.localToGlobal(Offset.zero)) &
              anchorBox.size;
      _sourceRadius = artAnchor!.widget.borderRadius;
      _sourceIsAnchor = true;
    } else {
      // No mini-player art: come from the bottom-right corner.
      _source = Rect.fromLTWH(_size.width - 64,
          _size.height - MediaQuery.paddingOf(context).bottom - 64, 44, 44);
      _sourceRadius = 10;
      _sourceIsAnchor = false;
    }

    final art = _box(_artKey);
    final content = _box(_contentKey);
    if (art == null || content == null) {
      _dest = null;
      return;
    }
    final rect = art.localToGlobal(Offset.zero, ancestor: content) & art.size;
    // On another page (lyrics, queue): no flight, the art just goes with
    // the sheet.
    final onScreen = rect.width > 0 &&
        rect.center.dx >= 0 &&
        rect.center.dx <= content.size.width;
    _dest = onScreen ? rect : null;
  }

  static RenderBox? _box(GlobalKey key) {
    final context = key.currentContext;
    return context == null ? null : _attachedBox(context);
  }

  Widget _buildFlyingArt(BuildContext context, Widget? _) {
    final p = _p.value;
    final source = _source;
    final dest = _dest;
    final image = _image;
    if (!_artHidden.value || source == null || dest == null || image == null) {
      return const SizedBox.shrink();
    }
    final scaledDest = NowPlayingTransition._scaled(dest, _artScale);
    final rect = NowPlayingTransition.artRect(
        p, source, scaledDest, math.max(120.0, _capsuleRect.top));
    final morph = p >= 1 ? 1.0 : NowPlayingTransition.artMorph(p);
    final radius = lerpDouble(_sourceRadius, _artRadius * _artScale, morph)!;
    return Stack(
      children: [
        Positioned.fromRect(
          key: NowPlayingTransition.flyingArtKey,
          rect: rect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35 * morph),
                  blurRadius: 24.0 * morph,
                  offset: Offset(0, 10 * morph),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: const Color(0xFF303030),
                child: Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _size = Size(math.max(1.0, size.width), math.max(1.0, size.height));
    return PopScope<Object?>(
      canPop: _popped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: _NowPlayingTransitionScope(
        state: this,
        child: Stack(
          key: _rootKey,
          fit: StackFit.expand,
          children: [
            widget.child,
            IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_p, _artHidden]),
                builder: _buildFlyingArt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades the player's controls and pages (not the backdrop) with the frame.
class _ContentFade extends StatelessWidget {
  const _ContentFade({required this.transition, required this.child});

  final NowPlayingTransitionState transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transition._p,
      child: child,
      builder: (context, child) => Opacity(
        opacity: transition._frameAt(transition._p.value).contentOpacity,
        child: child,
      ),
    );
  }
}

/// The sheet's clip, in the player's own (unscaled) coordinates.
class _SheetClipper extends CustomClipper<Path> {
  const _SheetClipper(this.frame);

  final NowPlayingFrame frame;

  @override
  Path getClip(Size size) => frame.clipPath();

  @override
  bool shouldReclip(_SheetClipper oldClipper) => true;
}

class _NowPlayingTransitionScope extends InheritedWidget {
  const _NowPlayingTransitionScope({required this.state, required super.child});

  final NowPlayingTransitionState state;

  @override
  bool updateShouldNotify(_NowPlayingTransitionScope oldWidget) => false;
}
