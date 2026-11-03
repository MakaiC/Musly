import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/models/album.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/screens/detail/album_screen.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/utils/navigation_helper.dart';
import 'package:musly/widgets/common/album_artwork.dart';
import 'package:musly/widgets/common/shimmer_loading.dart';

// Shared plumbing for the New tab's sections. Each section is a standalone
// widget that fetches its own data, so any one of them can be dropped from
// `NewScreen` without touching the others.

/// Side gutter of the New tab, matching the Home tab on phones.
const double kNewTabGutter = 16;

/// Space between two sections.
const double kNewSectionGap = 32;

/// How long a section waits for the server before showing its error state.
const Duration _kFetchTimeout = Duration(seconds: 30);

/// Whether New tab surfaces should be Liquid Glass: glass mode is on and the
/// phone layout is showing (glass is phone-only; see `MainScreen`, whose
/// large-screen breakpoint this mirrors).
bool newTabUsesGlass(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final phone = size.width < 650 && size.shortestSide < 600;
  return phone && Provider.of<ThemeService>(context).liquidGlass;
}

/// Lets the page's pull-to-refresh reload every section currently mounted,
/// without the page knowing which sections exist.
class NewTabRefreshScope extends InheritedWidget {
  const NewTabRefreshScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final NewTabRefreshRegistry registry;

  static NewTabRefreshRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NewTabRefreshScope>()
      ?.registry;

  @override
  bool updateShouldNotify(NewTabRefreshScope oldWidget) =>
      oldWidget.registry != registry;
}

class NewTabRefreshRegistry {
  final Set<Future<void> Function()> _loaders = {};

  void add(Future<void> Function() loader) => _loaders.add(loader);
  void remove(Future<void> Function() loader) => _loaders.remove(loader);

  /// Reloads every registered section; completes when all have finished
  /// (successfully or not).
  Future<void> refreshAll() =>
      Future.wait(_loaders.map((load) => load())).then((_) {});
}

/// Base state for a New tab section: fetches `T` and shows a header plus a
/// loading placeholder, the content, an empty message or an error with Retry.
///
/// A reload keeps the current content on screen until new data arrives, so
/// pull-to-refresh doesn't flash the placeholders.
abstract class NewSectionState<W extends StatefulWidget, T> extends State<W> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  NewTabRefreshRegistry? _registry;

  /// Section title shown in the header.
  String get title;

  /// Optional line under the title. Can depend on the loaded data.
  String? subtitleFor(T? data) => null;

  /// "See All" action for the header, or null for none.
  VoidCallback? get onSeeAll => null;

  /// Fetches the section's data. Throw to show the error state.
  Future<T> fetch(SubsonicService api);

  bool isEmpty(T data);

  /// Shown instead of content when [isEmpty] is true.
  String get emptyMessage;

  IconData get emptyIcon => CupertinoIcons.music_albums;

  /// Placeholder shown during the first load.
  Widget buildPlaceholder(BuildContext context);

  Widget buildContent(BuildContext context, T data);

  /// Whether the header sits above the content (the hero carousel has none).
  bool get showHeader => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = NewTabRefreshScope.maybeOf(context);
    if (!identical(registry, _registry)) {
      _registry?.remove(_load);
      _registry = registry?..add(_load);
    }
  }

  @override
  void dispose() {
    _registry?.remove(_load);
    super.dispose();
  }

  /// Fetches (again). Safe to call while a fetch is in flight: only the
  /// latest result is kept.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    final api = Provider.of<SubsonicService>(context, listen: false);
    // Only the error state swaps back to the placeholder; existing content
    // stays up while it reloads.
    if (_error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await fetch(api).timeout(_kFetchTimeout);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('New tab: "$title" failed to load: $e\n$st');
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final Widget body;
    if (data != null && _error == null) {
      body = isEmpty(data)
          ? NewSectionMessage(icon: emptyIcon, message: emptyMessage)
          : buildContent(context, data);
    } else if (_loading) {
      body = buildPlaceholder(context);
    } else {
      final l10n = AppLocalizations.of(context)!;
      body = NewSectionMessage(
        icon: CupertinoIcons.exclamationmark_triangle,
        message: l10n.errorLoadingAlbums,
        actionLabel: l10n.retry,
        onAction: _load,
      );
    }

    if (!showHeader) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NewSectionHeader(
          title: title,
          subtitle: subtitleFor(data),
          onSeeAll: data != null && !isEmpty(data) ? onSeeAll : null,
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }
}

/// Apple Music style section header: bold title, a chevron when it leads
/// somewhere, and an optional secondary line.
class NewSectionHeader extends StatelessWidget {
  const NewSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;

    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_right, size: 18, color: secondary),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onSeeAll != null)
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: titleRow,
              ),
            )
          else
            titleRow,
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: secondary, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline empty or error message inside a section, with an optional action.
///
/// Deliberately not glass: it sits on the flat page background, where clear
/// glass has nothing to refract and would read as an empty outline.
class NewSectionMessage extends StatelessWidget {
  const NewSectionMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Square album artwork with title and a secondary line; opens the album.
class NewAlbumTile extends StatelessWidget {
  const NewAlbumTile({
    super.key,
    required this.album,
    required this.size,
    this.subtitle,
  });

  final Album album;
  final double size;

  /// Defaults to the album artist.
  final String? subtitle;

  /// Height of a tile row for a given artwork [size].
  static double rowHeight(BuildContext context, double size) =>
      size + 8 + MediaQuery.textScalerOf(context).scale(38);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final line2 = subtitle ?? album.artist;

    return Semantics(
      button: true,
      label: [album.name, if (line2 != null) line2].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openNewTabAlbum(context, album),
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtwork(
                coverArt: album.coverArt,
                size: size,
                borderRadius: 10,
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              if (line2 != null)
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: secondary, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [NewAlbumTile]s.
class NewAlbumRow extends StatelessWidget {
  const NewAlbumRow({
    super.key,
    required this.albums,
    this.tileSize = kNewAlbumTileSize,
    this.subtitleFor,
  });

  final List<Album> albums;
  final double tileSize;
  final String? Function(Album album)? subtitleFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NewAlbumTile.rowHeight(context, tileSize),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => NewAlbumTile(
          album: albums[i],
          size: tileSize,
          subtitle: subtitleFor?.call(albums[i]),
        ),
      ),
    );
  }
}

/// Artwork size of album tiles in New tab rows.
const double kNewAlbumTileSize = 150;

/// Loading placeholder matching [NewAlbumRow].
class NewAlbumRowPlaceholder extends StatelessWidget {
  const NewAlbumRowPlaceholder({super.key, this.tileSize = kNewAlbumTileSize});

  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NewAlbumTile.rowHeight(context, tileSize),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => AlbumArtworkShimmer(
          size: tileSize,
          borderRadius: 10,
        ),
      ),
    );
  }
}

void openNewTabAlbum(BuildContext context, Album album) {
  NavigationHelper.push(context, AlbumScreen(albumId: album.id));
}

/// Plays an album from its first track. Shows a snackbar if it can't.
Future<void> playNewTabAlbum(BuildContext context, Album album) async {
  final api = Provider.of<SubsonicService>(context, listen: false);
  final player = Provider.of<PlayerProvider>(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final errorText = AppLocalizations.of(context)!.errorLoadingSongs;
  try {
    final songs = await api.getAlbumSongs(album.id);
    if (songs.isEmpty) throw StateError('Album ${album.id} has no songs');
    await player.playSong(songs.first, playlist: songs, startIndex: 0);
  } catch (e) {
    debugPrint('New tab: could not play album ${album.id}: $e');
    messenger?.showSnackBar(SnackBar(content: Text(errorText)));
  }
}

/// Newest first by release year, then by date added.
int compareAlbumsNewestFirst(Album a, Album b) {
  final byYear = (b.year ?? 0).compareTo(a.year ?? 0);
  if (byYear != 0) return byYear;
  final ca = a.created?.millisecondsSinceEpoch ?? 0;
  final cb = b.created?.millisecondsSinceEpoch ?? 0;
  return cb.compareTo(ca);
}
