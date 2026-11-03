import 'package:flutter/cupertino.dart';
import 'package:musly/models/album.dart';
import 'package:musly/services/subsonic_service.dart';
import 'new_section.dart';

/// The section's data: the albums, plus the artists they came from (most
/// played first) for the subtitle.
typedef FreshFromArtists = ({List<Album> albums, List<String> artists});

/// Section: "Fresh From Artists You Play", the newest albums by your
/// most-played artists that you haven't been playing yourself.
///
/// Data:
/// 1. `getAlbumList2?type=frequent` gives your most-played albums. Their
///    artists, weighted by rank, give your most-played artists.
/// 2. `getArtist` for each of the top artists lists their albums.
/// 3. Albums already in your most-played list are dropped (they aren't news
///    to you). The newest remaining ones per artist, by release year then
///    date added, are shown.
class FreshFromArtistsSection extends StatefulWidget {
  const FreshFromArtistsSection({super.key});

  @override
  State<FreshFromArtistsSection> createState() =>
      _FreshFromArtistsSectionState();
}

/// Most-played albums considered when ranking artists.
const int _kFrequentSample = 60;

/// Artists whose catalogues are looked up.
const int _kTopArtists = 8;

/// Albums shown per artist, at most.
const int _kAlbumsPerArtist = 2;

/// Albums shown in total, at most.
const int _kMaxAlbums = 14;

class _FreshFromArtistsSectionState
    extends NewSectionState<FreshFromArtistsSection, FreshFromArtists> {
  @override
  String get title => 'Fresh From Artists You Play';

  @override
  String? subtitleFor(FreshFromArtists? data) {
    final names = data?.artists ?? const <String>[];
    if (names.isEmpty) return null;
    if (names.length == 1) return 'New from ${names.first}';
    if (names.length == 2) return 'New from ${names[0]} and ${names[1]}';
    return 'New from ${names[0]}, ${names[1]} and more';
  }

  @override
  String get emptyMessage =>
      'Play more music and new albums from your favourite artists will '
      'show up here.';

  @override
  IconData get emptyIcon => CupertinoIcons.person_2;

  @override
  bool isEmpty(FreshFromArtists data) => data.albums.isEmpty;

  @override
  Future<FreshFromArtists> fetch(SubsonicService api) async {
    final frequent =
        await api.getAlbumList(type: 'frequent', size: _kFrequentSample);
    if (frequent.isEmpty) return (albums: <Album>[], artists: <String>[]);

    // Rank artists: an album near the top of the most-played list counts
    // for more than one near the bottom.
    final scores = <String, double>{};
    final names = <String, String>{};
    for (var i = 0; i < frequent.length; i++) {
      final album = frequent[i];
      final id = album.artistId;
      if (id == null || id.isEmpty || _isCompilationArtist(album.artist)) {
        continue;
      }
      scores[id] = (scores[id] ?? 0) + (frequent.length - i);
      names.putIfAbsent(id, () => album.artist ?? '');
    }
    final topArtists = (scores.keys.toList()
          ..sort((a, b) => scores[b]!.compareTo(scores[a]!)))
        .take(_kTopArtists)
        .toList();

    final played = {for (final a in frequent) a.id};
    final catalogues = await Future.wait(topArtists.map((id) async {
      try {
        return await api.getArtistAlbums(id);
      } catch (e) {
        debugPrint('New tab: albums for artist $id failed: $e');
        return <Album>[];
      }
    }));

    final albums = <Album>[];
    final artists = <String>[];
    for (var i = 0; i < topArtists.length; i++) {
      final fresh = catalogues[i]
          .where((a) => !played.contains(a.id))
          .toList()
        ..sort(compareAlbumsNewestFirst);
      if (fresh.isEmpty) continue;
      albums.addAll(fresh.take(_kAlbumsPerArtist));
      final name = names[topArtists[i]];
      if (name != null && name.isNotEmpty) artists.add(name);
    }
    albums.sort(compareAlbumsNewestFirst);
    return (albums: albums.take(_kMaxAlbums).toList(), artists: artists);
  }

  static bool _isCompilationArtist(String? name) {
    final n = name?.trim().toLowerCase();
    return n == null || n.isEmpty || n == 'various artists' || n == 'various';
  }

  @override
  Widget buildPlaceholder(BuildContext context) =>
      const NewAlbumRowPlaceholder();

  @override
  Widget buildContent(BuildContext context, FreshFromArtists data) {
    return NewAlbumRow(
      albums: data.albums,
      subtitleFor: (album) => [
        if (album.artist != null) album.artist!,
        if (album.year != null) '${album.year}',
      ].join(' · '),
    );
  }
}
