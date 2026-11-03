import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/services/local_music_service.dart';
import '../../widgets/navigation/tv_remote_scope.dart';
import '../../services/tv_detection_service.dart';
import 'package:musly/services/recommendation_service.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/services/usage_time_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/utils/navigation_helper.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'main_tabs.dart';
import 'new_screen.dart';
import 'search_screen.dart';
import 'tv_main_screen.dart';
import 'package:musly/screens/media/fantasy_screen.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class _PlayPauseAction extends Action<PlayPauseIntent> {
  final BuildContext context;
  _PlayPauseAction(this.context);

  @override
  bool isEnabled(PlayPauseIntent intent) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null) {
      final focusedContext = primaryFocus.context;
      if (focusedContext != null &&
          focusedContext.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return false;
      }
    }
    return true;
  }

  @override
  Object? invoke(PlayPauseIntent intent) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.togglePlayPause();
    return null;
  }
}

/// Collapse progress below which the travelling tab buttons aren't built
/// (see `_MainScreenState._buildCollapsibleChrome`).
const double _kTrailStart = 0.02;

/// Breathing room between a page's last item and the floating glass chrome.
const double _kScrollEndGap = 16;

/// Collapse/expand of the floating glass chrome: a soft, slightly
/// underdamped spring, so the morph takes ~0.5s and overshoots a few percent
/// before settling (a liquid bounce). Reversing mid-way keeps its speed.
final SpringDescription _kChromeCollapseSpring =
    SpringDescription.withDampingRatio(mass: 1, stiffness: 170, ratio: 0.68);

class MainScreen extends StatefulWidget {
  final bool isOfflineMode;

  const MainScreen({super.key, this.isOfflineMode = false});

  /// How much of the bottom of the page at [context] is covered by the
  /// floating Liquid Glass mini-player + tab bar, measured from the bottom of
  /// the screen.
  ///
  /// `0` in the classic layout, and for anything shown full-screen above
  /// [MainScreen] (root-navigator routes).
  static double floatingChromeOverlap(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_FloatingChromeScope>()
          ?.overlap ??
      0;

  /// Padding to leave after the last item of a page's scrollable content.
  ///
  /// Returns [base] unchanged unless glass chrome floats over the page, in
  /// which case it is enough to scroll the last item fully clear of the
  /// chrome (and never less than [base]).
  static double scrollEndPadding(BuildContext context, double base) {
    final overlap = floatingChromeOverlap(context);
    return overlap > 0 ? math.max(base, overlap + _kScrollEndGap) : base;
  }

  /// For widgets that size themselves from the bottom [MediaQuery] padding,
  /// such as a [ListView] without explicit padding or a [SafeArea]: extends
  /// that padding to cover the floating glass chrome. Returns [child]
  /// untouched when no chrome floats over the page.
  static Widget clearFloatingChrome(BuildContext context, Widget child) {
    final overlap = floatingChromeOverlap(context);
    if (overlap <= 0) return child;
    final mq = MediaQuery.of(context);
    if (mq.padding.bottom >= overlap) return child;
    return MediaQuery(
      data: mq.copyWith(padding: mq.padding.copyWith(bottom: overlap)),
      child: child,
    );
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// Publishes how far the floating glass chrome overlaps the pages of the
/// inner navigator. Read through [MainScreen.floatingChromeOverlap].
class _FloatingChromeScope extends InheritedWidget {
  const _FloatingChromeScope({required this.overlap, required super.child});

  final double overlap;

  @override
  bool updateShouldNotify(_FloatingChromeScope oldWidget) =>
      oldWidget.overlap != overlap;
}

/// Tracks whether a bottom sheet is the topmost route of the inner navigator.
///
/// Sheets opened from a page land on the inner navigator, which now runs
/// underneath the floating glass chrome. While one is on top, the chrome
/// steps aside so the sheet isn't covered (as on iOS, where a sheet covers
/// the tab bar).
class _SheetOnTopObserver extends NavigatorObserver {
  final ValueNotifier<bool> sheetOnTop = ValueNotifier<bool>(false);
  Route<dynamic>? _top;

  static bool _isSheet(Route<dynamic>? route) =>
      route is ModalBottomSheetRoute || route is CupertinoModalPopupRoute;

  void _setTop(Route<dynamic>? route) {
    _top = route;
    if (sheetOnTop.value == _isSheet(route)) return;
    // Route changes can be reported mid-build; never notify listeners then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
          (_) => sheetOnTop.value = _isSheet(_top));
    } else {
      sheetOnTop.value = _isSheet(route);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _setTop(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _setTop(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _top)) _setTop(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(oldRoute, _top)) _setTop(newRoute);
  }

  void dispose() => sheetOnTop.dispose();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = MainTabs.home;
  int _searchTapCount = 0;
  DateTime _lastSearchTap = DateTime.fromMillisecondsSinceEpoch(0);

  // Order must match MainTabs.
  final List<Widget> _screens = const [
    HomeScreen(),
    NewScreen(),
    LibraryScreen(),
    SearchScreen(),
  ];

  // While a dialog, sheet or page on the root navigator (now playing, for one)
  // covers this screen, the back swipe goes to that instead of a hidden page
  // in the inner navigator. Shared by both layouts' inner navigators.
  final _backGuard = CoveredBackGestureGuard();

  // Phone layout only: hides the floating glass chrome under bottom sheets.
  final _sheetObserver = _SheetOnTopObserver();

  // Glass phone layout only: the floating chrome collapses into a compact row
  // once the user scrolls down a page, and stays that way until a tab is
  // pressed or a page reaches its top. 0 = full chrome, 1 = collapsed.
  // Unbounded, so the spring's overshoot reaches the morph.
  late final AnimationController _chromeCollapse =
      AnimationController.unbounded(vsync: this);
  bool _chromeCollapsed = false;
  final _chromeScrollTracker = GlassChromeScrollTracker();

  /// Whether the floating glass chrome is on screen (last build).
  bool _floatingChromeShown = false;

  @override
  void dispose() {
    UsageTimeService().disposeService();
    _backGuard.dispose();
    _sheetObserver.dispose();
    _chromeCollapse.dispose();
    super.dispose();
  }

  /// Collapses or expands the floating glass chrome. Safe to call mid-build.
  void _setChromeCollapsed(bool collapsed) {
    _chromeScrollTracker.reset();
    if (_chromeCollapsed == collapsed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setChromeCollapsed(collapsed);
      });
      return;
    }
    setState(() => _chromeCollapsed = collapsed);
    final target = collapsed ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _chromeCollapse.value = target;
    } else {
      _chromeCollapse.animateWith(SpringSimulation(
        _kChromeCollapseSpring,
        _chromeCollapse.value,
        target,
        _chromeCollapse.velocity,
        tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        // Land exactly on 0 or 1: the layer that's out of the way is only
        // dropped (not painted) at exactly the end.
        snapToEnd: true,
      ));
    }
  }

  /// Scroll updates from any page in the inner navigator.
  bool _onPageScroll(ScrollNotification notification) {
    if (!_floatingChromeShown || _sheetObserver.sheetOnTop.value) return false;
    final collapse = _chromeScrollTracker.handle(notification);
    if (collapse != null) _setChromeCollapsed(collapse);
    return false;
  }

  @override
  void initState() {
    super.initState();

    NavigationHelper.registerTabChangeCallback((index) {
      _setChromeCollapsed(false);
      setState(() => _currentIndex = index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final playerProvider = Provider.of<PlayerProvider>(
        context,
        listen: false,
      );
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );

      playerProvider.setLibraryProvider(libraryProvider);
      playerProvider.setRecommendationService(recommendationService);

      playerProvider.onAudioFocusDenied = () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.audioFocusDenied),
          ),
        );
      };

      if (authProvider.isLocalOnlyMode) {
        final localMusicService = Provider.of<LocalMusicService>(
          context,
          listen: false,
        );

        libraryProvider.setLocalMusicService(localMusicService);

        if (localMusicService.isEmpty && !localMusicService.isScanning) {
          localMusicService.scanForMusic();
        } else if (!localMusicService.isScanning) {
          libraryProvider.initialize();
        }
      } else {
        libraryProvider.setLocalOnlyMode(false);
        libraryProvider.setServerOfflineMode(widget.isOfflineMode);
        libraryProvider.initialize();
      }

      UsageTimeService().initialize();

      _startUsageTimeChecker();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _checkForUpdate();
      });
    });
  }

  void _startUsageTimeChecker() {
    Future.delayed(const Duration(minutes: 2), () {
      if (!mounted) return;

      final usageService = UsageTimeService();
      if (usageService.shouldShowDialog) {
        _showSupportDialog();
      } else {
        _startUsageTimeChecker();
      }
    });
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => const SupportDialog(),
      barrierDismissible: true,
    );
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    await UpdateDialog.checkAndShow(context);
  }

  bool _isLargeScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 650 || size.shortestSide >= 600;
  }

  @override
  Widget build(BuildContext context) =>
      CoveredBackGestureScope(guard: _backGuard, child: _buildScreen(context));

  Widget _buildScreen(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLocalMode = authProvider.isLocalOnlyMode;
    final isTv = Provider.of<TvDetectionService>(context).isTvMode;

    if (isTv) {
      return TvMainScreen(isOfflineMode: widget.isOfflineMode);
    }

    if (_isLargeScreen(context)) {
      final content = Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  DesktopNavigationSidebar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                      NavigationHelper.appNavigatorKey.currentState
                          ?.popUntil((route) => route.isFirst);
                    },
                    navigatorKey: NavigationHelper.appNavigatorKey,
                  ),
                  Expanded(
                    child: Navigator(
                      key: NavigationHelper.appNavigatorKey,
                      observers: [_backGuard],
                      onGenerateRoute: (settings) {
                        return PageRouteBuilder(
                          pageBuilder: (ctx, anim, _) => LazyIndexedStack(
                            index: _currentIndex,
                            children: _screens,
                          ),
                          transitionsBuilder: (ctx, animation, _, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavigationHelper.isDesktopLyricsOpen,
                    builder: (context, isLyricsOpen, _) {
                      if (!isLyricsOpen) return const SizedBox.shrink();
                      return Selector<PlayerProvider, bool>(
                        selector: (_, p) =>
                            p.currentSong != null || p.isPlayingRadio,
                        builder: (context, hasCurrentSong, _) {
                          return hasCurrentSong
                              ? DesktopLyricsPanel(
                                  onClose: () => NavigationHelper
                                      .isDesktopLyricsOpen.value = false,
                                )
                              : const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavigationHelper.isDesktopQueueOpen,
                    builder: (context, isQueueOpen, _) {
                      if (!isQueueOpen) return const SizedBox.shrink();
                      return Selector<PlayerProvider, bool>(
                        selector: (_, p) =>
                            p.currentSong != null || p.isPlayingRadio,
                        builder: (context, hasCurrentSong, _) {
                          return hasCurrentSong
                              ? RightSidebar(
                                  onClose: () => NavigationHelper
                                      .isDesktopQueueOpen.value = false,
                                )
                              : const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Selector<PlayerProvider, bool>(
              selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
              builder: (context, hasCurrentSong, _) {
                return hasCurrentSong
                    ? SafeArea(
                        top: false,
                        child: DesktopPlayerBar(
                          navigatorKey: NavigationHelper.appNavigatorKey,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      );

      return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.space):
              const PlayPauseIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: _PlayPauseAction(context),
          },
          child: TvRemoteScope(
            child: Focus(
              autofocus: true,
              child: content,
            ),
          ),
        ),
      );
    }

    final bool liquidGlass = Provider.of<ThemeService>(context).liquidGlass;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bool keyboardVisible = mediaQuery.viewInsets.bottom != 0;
    return Selector<PlayerProvider, bool>(
      selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
      builder: (context, hasCurrentSong, _) {
        // Liquid Glass: the mini-player + tab bar float over the pages, which
        // run edge-to-edge underneath so the glass has real content to blur.
        // Classic: they sit below the pages, as before.
        final Widget? floatingChrome = liquidGlass && !keyboardVisible
            ? _buildFloatingGlassChrome(context, hasCurrentSong)
            : null;
        _floatingChromeShown = floatingChrome != null;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackButton();
          },
          child: TvRemoteScope(
            child: Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBackground
                : AppTheme.lightBackground,
            resizeToAvoidBottomInset: false,
            extendBody: floatingChrome != null,
            bottomNavigationBar: floatingChrome,
            body: Builder(builder: (bodyContext) {
              // With extendBody the Scaffold reports the chrome's height as
              // the body's bottom padding. Pages get it via
              // _FloatingChromeScope; the inner navigator itself keeps the
              // real system inset, so sheets, dialogs and SafeAreas pushed
              // there lay out exactly as before. (Classic: a no-op.)
              final bodyMediaQuery = MediaQuery.of(bodyContext);
              return MediaQuery(
                data: bodyMediaQuery.copyWith(
                  padding: bodyMediaQuery.padding
                      .copyWith(bottom: mediaQuery.padding.bottom),
                ),
                child: _FloatingChromeScope(
                  overlap: floatingChrome != null
                      ? bodyMediaQuery.padding.bottom
                      : 0,
                  child: _buildPhoneBody(
                    context,
                    isLocalMode: isLocalMode,
                    inlineChrome: !liquidGlass && !keyboardVisible,
                    hasCurrentSong: hasCurrentSong,
                  ),
                ),
              );
            }),
          ),
          ),
        );
      },
    );
  }

  /// The phone layout's page column: status banners, the inner navigator and,
  /// in the classic layout only, the inline mini-player + tab bar.
  Widget _buildPhoneBody(
    BuildContext context, {
    required bool isLocalMode,
    required bool inlineChrome,
    required bool hasCurrentSong,
  }) {
    return Column(
      children: [
        if (widget.isOfflineMode || isLocalMode)
          Container(
            width: double.infinity,
            color: isLocalMode ? Colors.indigo : Colors.orange,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Icon(
                    isLocalMode
                        ? CupertinoIcons.folder_fill
                        : CupertinoIcons.wifi_slash,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLocalMode
                          ? AppLocalizations.of(
                              context,
                            )!
                              .localFilesModeBanner
                          : AppLocalizations.of(
                              context,
                            )!
                              .offlineModeBanner,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isLocalMode)
          Selector<LocalMusicService, (bool, double, String)>(
            selector: (_, s) =>
                (s.isScanning, s.scanProgress, s.scanStatus),
            builder: (context, data, _) {
              final (isScanning, progress, status) = data;
              if (!isScanning) return const SizedBox.shrink();
              return Container(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (progress > 0)
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        Expanded(
          // Scroll direction on any page drives the glass chrome's collapse.
          child: NotificationListener<ScrollNotification>(
            onNotification: _onPageScroll,
            child: Navigator(
              key: NavigationHelper.appNavigatorKey,
              observers: [_backGuard, _sheetObserver],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => LazyIndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                );
              },
            ),
          ),
        ),
        if (inlineChrome)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCurrentSong) const MiniPlayer(),
              _buildBottomNav(context),
            ],
          ),
      ],
    );
  }

  /// Liquid Glass chrome floating over the pages: mini-player + tab bar.
  Widget _buildFloatingGlassChrome(BuildContext context, bool hasCurrentSong) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _sheetObserver.sheetOnTop,
      builder: (context, sheetOnTop, child) {
        // Slide out of the way while a bottom sheet is open over the pages.
        // Layout size is kept, so pages don't reflow underneath the sheet.
        return IgnorePointer(
          ignoring: sheetOnTop,
          child: AnimatedSlide(
            offset: sheetOnTop ? const Offset(0, 1.4) : Offset.zero,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: sheetOnTop ? Curves.easeInCubic : Curves.easeOutCubic,
            child: child,
          ),
        );
      },
      // One shared backdrop for every glass surface in the chrome, so the
      // engine snapshots the content behind it once rather than per surface.
      child: BackdropGroup(
        child: AnimatedBuilder(
          animation: _chromeCollapse,
          builder: (context, _) =>
              _buildCollapsibleChrome(context, hasCurrentSong),
        ),
      ),
    );
  }

  /// The floating chrome, morphing between its full and collapsed forms as
  /// one continuous move ([_chromeCollapse]: 0 full, 1 collapsed).
  ///
  /// Every piece is placed by interpolating its rect between the two
  /// layouts:
  ///  * The tab bar's glass shrinks toward its leading end into a circle for
  ///    the current tab ([GlassTabBar.collapse]).
  ///  * The mini-player drops down into the gap between the corner buttons
  ///    and narrows, keeping its artwork, title and artist, while its other
  ///    controls fold away so play/pause ends at its trailing edge
  ///    ([MiniPlayer.collapse]). It starts a beat after the tab bar, so the
  ///    tab bar has made room for it.
  ///  * Tabs that move to another spot travel there: the leading tab glides
  ///    into the shrinking bar's circle, and each trailing tab detaches from
  ///    its slot in the bar (crossfading from the bar's icon, glass forming
  ///    around it) and travels to its corner. Start points come from
  ///    [GlassTabBar.slotCentre], so this works for any number of tabs.
  ///
  /// The chrome's own box keeps the full height throughout, so the overlap
  /// reported to pages (and their end padding) never changes and nothing
  /// reflows mid-scroll. No glass is faded with a fractional Opacity.
  Widget _buildCollapsibleChrome(BuildContext context, bool hasCurrentSong) {
    final raw = _chromeCollapse.value;
    final t = raw.clamp(0.0, 1.0);
    // The spring's overshoot past either end, carried into the geometry so
    // every piece bounces as it settles.
    final over = raw - t;
    final tabT =
        const Interval(0, 0.85, curve: Curves.easeInOut).transform(t) + over;
    final miniT =
        const Interval(0.1, 1, curve: Curves.easeInOut).transform(t) + over;
    // Trailing buttons' glass forms early in their trip.
    final trailGlass =
        const Interval(0.05, 0.6, curve: Curves.easeOut).transform(t);
    // Hand-off of a travelling tab between the bar and its own button: a
    // short crossfade at the start of the trip (the end, coming back). A
    // hard switch blinked the bar's label when the spring's bounce dipped
    // past fully expanded and back.
    //
    // The button only exists past _kTrailStart. A glass surface left built
    // at ~0 visibility isn't invisible on Impeller: over the bar it hid the
    // Search icon under it (measured ~8% darker; a dark disc in dark mode),
    // and the spring's small rebound at the end of expanding kept it there
    // for ~0.2s. Below the threshold the bar alone draws the tab.
    const trailStart = _kTrailStart;
    final handoff = ((t - trailStart) / 0.13).clamp(0.0, 1.0);

    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottom = safeBottom > 0 ? safeBottom : 12.0;
    const side = 12.0, gap = 8.0;
    const tabHeight = 62.0, miniHeight = 60.0, miniPad = 4.0;
    const row = kGlassCollapsedBarHeight;
    final height = (hasCurrentSong ? miniHeight + 2 * miniPad : 0) +
        miniPad +
        tabHeight +
        bottom;

    final l10n = AppLocalizations.of(context)!;
    final items = _glassTabItems(l10n);
    final layout = _collapsedLayout();
    final trailing = layout.trailing;

    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final rowTop = height - bottom - row;
        final tabTop = height - bottom - tabHeight;

        // Trailing buttons' final spots, right to left from the corner.
        Rect trailingRect(int i) {
          final fromEnd = trailing.length - 1 - i;
          final right = width - side - fromEnd * (row + gap);
          return Rect.fromLTRB(right - row, rowTop, right, rowTop + row);
        }

        // Where the full bar draws tab [tab]'s icon: each trailing button
        // starts its trip there, centred on the icon.
        Rect slotRect(int tab) => Rect.fromCenter(
              center: Offset(
                side +
                    GlassTabBar.slotCentre(
                        width - 2 * side, items.length, tab),
                tabTop + tabHeight / 2 + GlassTabBar.iconCentreOffset,
              ),
              width: row,
              height: row,
            );

        final miniFull = Rect.fromLTWH(side, tabTop - 2 * miniPad - miniHeight,
            width - 2 * side, miniHeight);
        final miniCollapsed = Rect.fromLTRB(side + row + gap, rowTop,
            trailingRect(0).left - gap, rowTop + row);
        final mini = Rect.lerp(miniFull, miniCollapsed, miniT)!;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: side,
              right: side,
              bottom: bottom,
              height: tabHeight,
              child: GlassTabBar(
                currentIndex: _currentIndex,
                onTabSelected: _onGlassTabSelected,
                items: items,
                height: tabHeight,
                collapse: tabT,
                collapsedSize: row,
                collapsedIndex: layout.leading,
                detachedTabs: trailing.toSet(),
                detachProgress: handoff,
              ),
            ),
            if (t > trailStart)
              for (var i = 0; i < trailing.length; i++)
                Positioned.fromRect(
                  // Travels with the bar's collapse (overshoot included, so
                  // it bounces into its corner).
                  rect: Rect.lerp(
                      slotRect(trailing[i]), trailingRect(i), tabT)!,
                  child: IgnorePointer(
                    ignoring: !_chromeCollapsed,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * trailGlass + over,
                      // Its own backdrop read, not the chrome's shared one:
                      // that snapshot predates the tab bar, so while the
                      // button passes over the bar it would paint the raw
                      // page there (a dark disc in dark mode). This reads
                      // the finished bar behind it instead.
                      child: BackdropGroup(
                        child: GlassTabButton(
                        visibility: trailGlass,
                        glyphVisibility: handoff,
                        tab: GlassCollapsedTab(
                          item: items[trailing[i]],
                          selected: trailing[i] == _currentIndex,
                          onTap: () => _onGlassTabSelected(trailing[i]),
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
            // Above the tab bar, so it passes over the shrinking bar's end.
            if (hasCurrentSong)
              Positioned(
                left: mini.left - side,
                width: mini.width + 2 * side,
                top: mini.top - miniPad,
                height: mini.height + 2 * miniPad,
                child: MiniPlayer(collapse: miniT),
              ),
          ],
        );
      }),
    );
  }

  /// Which tabs the collapsed chrome shows where. **The one place to edit
  /// when tabs change:** everything else (start points, the glide into the
  /// circle, travel to the corners) follows from this and [_glassTabItems].
  ///
  ///  * `leading`: the tab the collapsed tab bar's circle stands for: the
  ///    current tab, or Home while on Search.
  ///  * `trailing`: round buttons in the trailing corner, left to right:
  ///    always Search (accented while current), so it's reachable from
  ///    every page.
  ({int leading, List<int> trailing}) _collapsedLayout() => (
        leading:
            _currentIndex == MainTabs.search ? MainTabs.home : _currentIndex,
        trailing: const [MainTabs.search],
      );

  void _handleBackButton() {
    final navigatorState = NavigationHelper.appNavigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
      return;
    }

    if (_currentIndex != MainTabs.home) {
      _setChromeCollapsed(false);
      setState(() => _currentIndex = MainTabs.home);
      return;
    }

    SystemNavigator.pop();
  }

  /// The glass tabs, in [_screens] (MainTabs) order. Shared by the tab bar
  /// and the collapsed row.
  List<GlassTabItem> _glassTabItems(AppLocalizations l10n) => [
        GlassTabItem(
          icon: CupertinoIcons.music_house,
          activeIcon: CupertinoIcons.music_house_fill,
          label: l10n.home,
        ),
        GlassTabItem(
          icon: CupertinoIcons.square_grid_2x2,
          activeIcon: CupertinoIcons.square_grid_2x2_fill,
          label: l10n.newTab,
        ),
        GlassTabItem(
          icon: CupertinoIcons.collections,
          activeIcon: CupertinoIcons.collections_solid,
          label: l10n.library,
        ),
        GlassTabItem(
          icon: CupertinoIcons.search,
          activeIcon: CupertinoIcons.search,
          label: l10n.search,
        ),
      ];

  /// Glass tab bar selection (a tap, or a drag released over another tab).
  /// Same behaviour as the classic tab bar's onTap.
  void _onGlassTabSelected(int idx) {
    // Any tab press (including the collapsed chrome's buttons) expands it.
    _setChromeCollapsed(false);
    final navigatorState = NavigationHelper.appNavigatorKey.currentState;
    navigatorState?.popUntil((route) => route.isFirst);

    if (idx == MainTabs.search) {
      final now = DateTime.now();
      if (now.difference(_lastSearchTap).inSeconds > 3) {
        _searchTapCount = 0;
      }
      _searchTapCount++;
      _lastSearchTap = now;
      if (_searchTapCount >= 11) {
        _searchTapCount = 0;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FantasyScreen()),
        );
        return;
      }
    } else {
      _searchTapCount = 0;
    }

    setState(() => _currentIndex = idx);
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            final navigatorState =
                NavigationHelper.appNavigatorKey.currentState;
            navigatorState?.popUntil((route) => route.isFirst);

            if (index == MainTabs.search) {
              final now = DateTime.now();
              if (now.difference(_lastSearchTap).inSeconds > 3) {
                _searchTapCount = 0;
              }
              _searchTapCount++;
              _lastSearchTap = now;
              if (_searchTapCount >= 11) {
                _searchTapCount = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FantasyScreen()),
                );
                return;
              }
            } else {
              _searchTapCount = 0;
            }

            setState(() => _currentIndex = index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.music_house),
              activeIcon: const Icon(CupertinoIcons.music_house_fill),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.square_grid_2x2),
              activeIcon: const Icon(CupertinoIcons.square_grid_2x2_fill),
              label: l10n.newTab,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.collections),
              activeIcon: const Icon(CupertinoIcons.collections_solid),
              label: l10n.library,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.search),
              activeIcon: const Icon(CupertinoIcons.search),
              label: l10n.search,
            ),
          ],
        ),
      ),
    );
  }
}
