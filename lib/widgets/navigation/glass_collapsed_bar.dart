import 'package:flutter/material.dart';

import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/navigation/glass_tab_bar.dart';

/// Size of the collapsed Liquid Glass chrome's round tab buttons, and the
/// height of the collapsed mini-player.
const double kGlassCollapsedBarHeight = 52;

/// Distance a page must be scrolled down (without reversing) before the
/// floating chrome collapses. Keeps small jiggles from collapsing it.
const double kGlassChromeScrollThreshold = 24;

/// A tab shown as a round glass button in the collapsed chrome.
@immutable
class GlassCollapsedTab {
  const GlassCollapsedTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassTabItem item;

  /// The page currently shown: accent, filled icon. Otherwise neutral.
  final bool selected;
  final VoidCallback onTap;
}

/// A round glass button for one tab, as in the collapsed chrome's trailing
/// corner. Same colours as [GlassTabBar]'s selected and unselected tabs.
///
/// [visibility] (0..1) dissolves the glass and its glyph, for transitions
/// (see [GlassContainer.visibility]; never fade glass with an [Opacity]).
class GlassTabButton extends StatelessWidget {
  const GlassTabButton({
    super.key,
    required this.tab,
    this.size = kGlassCollapsedBarHeight,
    this.visibility = 1,
  });

  final GlassCollapsedTab tab;
  final double size;
  final double visibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final v = visibility.clamp(0.0, 1.0);
    final color = tab.selected
        ? theme.colorScheme.primary
        : (isDark ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73));

    return Semantics(
      button: true,
      selected: tab.selected,
      label: tab.item.label,
      onTap: tab.onTap,
      excludeSemantics: true,
      child: GlassContainer.capsule(
        width: size,
        height: size,
        visibility: v,
        onTap: tab.onTap,
        child: Center(
          // The glyph isn't glass, so a plain Opacity is fine for it.
          child: Opacity(
            opacity: v,
            child: Icon(
              tab.selected ? tab.item.activeIcon : tab.item.icon,
              color: color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decides, from a page's scroll notifications, when the floating chrome
/// should collapse or expand.
///
///  * Scrolling **down** by more than [threshold] without reversing
///    collapses it.
///  * It then stays collapsed while the page scrolls either way. It only
///    expands on reaching the **top** of the page (including pulling down
///    against the top). Tab presses expand it too, but that's up to the
///    caller.
///
/// Only vertical, top-to-bottom scrollables count (not horizontal carousels
/// or reversed lists). Overscroll at the end of a list (the iOS bounce) is
/// ignored.
class GlassChromeScrollTracker {
  GlassChromeScrollTracker({this.threshold = kGlassChromeScrollThreshold});

  final double threshold;

  /// Distance scrolled down without reversing.
  double _run = 0;

  void reset() => _run = 0;

  /// Returns `true` to collapse, `false` to expand, `null` for no change.
  bool? handle(ScrollNotification n) {
    final m = n.metrics;
    if (m.axisDirection != AxisDirection.down) return null;

    // Pulling down against the top (Android's clamping physics reports this
    // instead of moving past the top).
    if (n is OverscrollNotification) {
      if (n.overscroll < 0 && m.pixels <= m.minScrollExtent) {
        _run = 0;
        return false;
      }
      return null;
    }
    if (n is! ScrollUpdateNotification) return null;

    // At (or bounced past) the top: show everything. (Half a point of
    // slack for rounding in programmatic scrolls.)
    if (m.pixels <= m.minScrollExtent + 0.5) {
      _run = 0;
      return false;
    }
    final delta = n.scrollDelta ?? 0;
    if (m.outOfRange || delta == 0) return null;
    if (delta < 0) {
      _run = 0;
      return null;
    }
    _run += delta;
    if (_run > threshold && m.pixels > m.minScrollExtent + threshold) {
      return true;
    }
    return null;
  }
}
