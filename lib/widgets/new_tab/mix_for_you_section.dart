import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/song.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/common/album_artwork.dart';
import 'package:musly/widgets/common/glass_container.dart';
import 'package:musly/widgets/common/glass_icon_button.dart';
import 'new_section.dart';

/// Section: "Mix For You", a randomly generated song mix with a Play button
/// and a button that rolls a new mix.
///
/// Data: `getRandomSongs` ([mixSize] songs).
class MixForYouSection extends StatefulWidget {
  const MixForYouSection({super.key, this.mixSize = 25});

  final int mixSize;

  @override
  State<MixForYouSection> createState() => _MixForYouSectionState();
}

const double _kCardHeight = 148;
const double _kMosaicSize = 120;

class _MixForYouSectionState
    extends NewSectionState<MixForYouSection, List<Song>> {
  bool _rolling = false;

  @override
  String get title => 'Mix For You';

  @override
  String? subtitleFor(List<Song>? data) =>
      data == null || data.isEmpty ? null : 'A random mix from your library';

  @override
  String get emptyMessage => 'Add some music to your server to get a mix.';

  @override
  IconData get emptyIcon => CupertinoIcons.shuffle;

  @override
  bool isEmpty(List<Song> data) => data.isEmpty;

  @override
  Future<List<Song>> fetch(SubsonicService api) =>
      api.getRandomSongs(size: widget.mixSize);

  Future<void> _rollNewMix() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    await reload();
    if (mounted) setState(() => _rolling = false);
  }

  Future<void> _play(List<Song> songs) async {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    await player.playSong(songs.first, playlist: songs, startIndex: 0);
  }

  @override
  Widget buildPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
      child: Container(
        height: _kCardHeight,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context, List<Song> songs) {
    final covers = _distinctCovers(songs);
    final artists = _artistPreview(songs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Backdrop: the first cover, heavily blurred, under a scrim.
            Positioned.fill(child: _BlurredCover(coverArt: covers.firstOrNull)),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kCardHeight),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _Mosaic(covers: covers),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${songs.length} songs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (artists.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              artists,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _MixPlayButton(onPressed: () => _play(songs)),
                              const SizedBox(width: 8),
                              _NewMixButton(
                                busy: _rolling,
                                onPressed: _rollNewMix,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _distinctCovers(List<Song> songs) {
    final seen = <String>{};
    final covers = <String>[];
    for (final s in songs) {
      final art = s.coverArt;
      if (art == null || art.isEmpty) continue;
      if (seen.add(s.albumId ?? art)) covers.add(art);
      if (covers.length == 4) break;
    }
    return covers;
  }

  static String _artistPreview(List<Song> songs) {
    final names = <String>[];
    for (final s in songs) {
      final a = s.artist;
      if (a != null && a.isNotEmpty && !names.contains(a)) names.add(a);
      if (names.length == 3) break;
    }
    if (names.isEmpty) return '';
    return names.length < 3
        ? names.join(' and ')
        : '${names[0]}, ${names[1]}, ${names[2]} and more';
  }
}

class _BlurredCover extends StatelessWidget {
  const _BlurredCover({required this.coverArt});

  final String? coverArt;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2C2C2E)),
        if (coverArt != null)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 30,
              sigmaY: 30,
              tileMode: TileMode.mirror,
            ),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: AlbumArtwork(
                coverArt: coverArt,
                size: 96,
                borderRadius: 0,
                shadow: const BoxShadow(color: Colors.transparent),
              ),
            ),
          ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
      ],
    );
  }
}

/// 2×2 grid of distinct covers from the mix (one cover fills it if that's
/// all there is).
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.covers});

  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    const half = _kMosaicSize / 2;
    Widget tile(String? art, double size) => AlbumArtwork(
          coverArt: art,
          size: size,
          borderRadius: 0,
          shadow: const BoxShadow(color: Colors.transparent),
        );

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: _kMosaicSize,
          child: covers.length < 4
              ? tile(covers.firstOrNull, _kMosaicSize)
              : Column(
                  children: [
                    Row(children: [tile(covers[0], half), tile(covers[1], half)]),
                    Row(children: [tile(covers[2], half), tile(covers[3], half)]),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MixPlayButton extends StatelessWidget {
  const _MixPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Play';
    const content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.play_fill, size: 16, color: Colors.white),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (newTabUsesGlass(context)) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GlassContainer.capsule(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          style: GlassStyle.control,
          onTap: onPressed,
          child: content,
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const SizedBox(
          height: 40,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _NewMixButton extends StatelessWidget {
  const _NewMixButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'New mix';
    if (newTabUsesGlass(context)) {
      return GlassIconButton(
        icon: CupertinoIcons.arrow_2_squarepath,
        size: 40,
        iconSize: 18,
        color: Colors.white,
        semanticLabel: label,
        onPressed: busy ? null : onPressed,
      );
    }
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: label,
        onPressed: busy ? null : onPressed,
        icon: const Icon(
          CupertinoIcons.arrow_2_squarepath,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}
