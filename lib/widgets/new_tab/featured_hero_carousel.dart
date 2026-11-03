import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:musly/models/album.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/common/album_artwork.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/common/shimmer_loading.dart';
import 'new_section.dart';

/// Section: a large, swipeable carousel of the most recently added albums.
///
/// Data: `getAlbumList2?type=newest`.
class FeaturedHeroCarousel extends StatefulWidget {
  const FeaturedHeroCarousel({super.key});

  /// How many albums the carousel features. Other sections showing recently
  /// added albums can skip this many to avoid repeating them.
  static const int albumCount = 6;

  @override
  State<FeaturedHeroCarousel> createState() => _FeaturedHeroCarouselState();
}

/// Widest the hero card gets (tablets, desktop).
const double _kMaxCardWidth = 420;

/// Gap between neighbouring cards.
const double _kPageGap = 12;

/// Height reserved for the eyebrow, title and artist above each card,
/// before text scaling.
const double _kCaptionHeight = 80;

class _FeaturedHeroCarouselState
    extends NewSectionState<FeaturedHeroCarousel, List<Album>> {
  PageController? _controller;
  double _viewportFraction = 0;
  final ValueNotifier<int> _page = ValueNotifier<int>(0);

  @override
  String get title => 'Featured';

  @override
  bool get showHeader => false;

  @override
  String get emptyMessage =>
      'Albums you add to your server will be featured here.';

  @override
  Future<List<Album>> fetch(SubsonicService api) => api.getAlbumList(
        type: 'newest',
        size: FeaturedHeroCarousel.albumCount,
      );

  @override
  bool isEmpty(List<Album> data) => data.isEmpty;

  @override
  void dispose() {
    _controller?.dispose();
    _page.dispose();
    super.dispose();
  }

  PageController _controllerFor(double viewportFraction) {
    if (_controller == null || _viewportFraction != viewportFraction) {
      final initial = _controller?.hasClients == true ? _page.value : 0;
      _controller?.dispose();
      _viewportFraction = viewportFraction;
      _controller = PageController(
        viewportFraction: viewportFraction,
        initialPage: initial,
      );
    }
    return _controller!;
  }

  /// Card width and the page view's viewport fraction for [maxWidth].
  ({double card, double fraction}) _geometry(double maxWidth) {
    final card = math.min(maxWidth - 2 * kNewTabGutter, _kMaxCardWidth);
    return (card: card, fraction: (card + _kPageGap) / maxWidth);
  }

  double _height(BuildContext context, double card) =>
      MediaQuery.textScalerOf(context).scale(_kCaptionHeight) + card;

  @override
  Widget buildPlaceholder(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final g = _geometry(constraints.maxWidth);
      return SizedBox(
        height: _height(context, g.card) + 22,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: AlbumArtworkShimmer(size: g.card, borderRadius: 16),
          ),
        ),
      );
    });
  }

  @override
  Widget buildContent(BuildContext context, List<Album> albums) {
    return LayoutBuilder(builder: (context, constraints) {
      final g = _geometry(constraints.maxWidth);
      final controller = _controllerFor(g.fraction);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _height(context, g.card),
            child: PageView.builder(
              controller: controller,
              itemCount: albums.length,
              onPageChanged: (i) => _page.value = i,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPageGap / 2),
                child: _HeroPage(album: albums[i], cardSize: g.card),
              ),
            ),
          ),
          if (albums.length > 1) ...[
            const SizedBox(height: 10),
            ValueListenableBuilder<int>(
              valueListenable: _page,
              builder: (context, page, _) =>
                  _PageDots(
                count: albums.length,
                current: math.min(page, albums.length - 1),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.album, required this.cardSize});

  final Album album;
  final double cardSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final details = [
      if (album.artist != null) album.artist!,
      if (album.year != null) '${album.year}',
    ].join(' · ');

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'RECENTLY ADDED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: secondary, fontSize: 15),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => openNewTabAlbum(context, album),
            child: SizedBox.square(
              dimension: cardSize,
              child: Stack(
                children: [
                  AlbumArtwork(
                    coverArt: album.coverArt,
                    size: cardSize,
                    borderRadius: 16,
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _HeroPlayButton(
                      onPressed: () => playNewTabAlbum(context, album),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Play" pill over the hero artwork: a glass capsule in Liquid Glass mode,
/// a solid white pill otherwise.
class _HeroPlayButton extends StatelessWidget {
  const _HeroPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Play';
    if (newTabUsesGlass(context)) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GlassContainer.capsule(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onTap: onPressed,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.play_fill, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const SizedBox(
          height: 40,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.play_fill, size: 16, color: Colors.black),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final on = isDark ? Colors.white : Colors.black;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: on.withValues(alpha: i == current ? 0.8 : 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
