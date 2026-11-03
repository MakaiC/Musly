import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:musly/models/album.dart';
import 'package:musly/services/subsonic_service.dart';
import 'new_section.dart';

/// Section: "Rediscover", albums you loved but haven't played in a while.
///
/// Data:
/// - "Loved" = starred albums (`getAlbumList2?type=starred`).
/// - "Not in a while" = not among your most recently played albums
///   (`getAlbumList2?type=recent`, the last [_kRecentWindow]).
/// - If you've starred fewer than [_kMinAlbums] such albums, it tops up with
///   your most-played albums (`type=frequent`) that also aren't recent.
///
/// The order is shuffled on each load so the row changes over time.
class RediscoverSection extends StatefulWidget {
  const RediscoverSection({super.key});

  @override
  State<RediscoverSection> createState() => _RediscoverSectionState();
}

/// Recently played albums treated as "played lately".
const int _kRecentWindow = 60;

/// Starred albums considered.
const int _kStarredSample = 200;

/// Below this many starred candidates, most-played albums are added.
const int _kMinAlbums = 6;

/// Albums shown, at most.
const int _kMaxAlbums = 14;

class _RediscoverSectionState
    extends NewSectionState<RediscoverSection, List<Album>> {
  @override
  String get title => 'Rediscover';

  @override
  String? subtitleFor(List<Album>? data) =>
      data == null || data.isEmpty ? null : "Loved, but not played lately";

  @override
  String get emptyMessage =>
      'Star albums you love. When you haven\'t played them for a while, '
      'they\'ll come back here.';

  @override
  IconData get emptyIcon => CupertinoIcons.heart;

  @override
  bool isEmpty(List<Album> data) => data.isEmpty;

  @override
  Future<List<Album>> fetch(SubsonicService api) async {
    final results = await Future.wait([
      api.getAlbumList(type: 'starred', size: _kStarredSample),
      api.getAlbumList(type: 'recent', size: _kRecentWindow),
    ]);
    final starred = results[0];
    final recent = {for (final a in results[1]) a.id};
    final random = math.Random();

    final picks = starred.where((a) => !recent.contains(a.id)).toList()
      ..shuffle(random);

    if (picks.length < _kMinAlbums) {
      final frequent = await api.getAlbumList(type: 'frequent', size: 40);
      final have = {for (final a in picks) a.id};
      final extra = frequent
          .where((a) => !recent.contains(a.id) && !have.contains(a.id))
          .toList()
        ..shuffle(random);
      picks.addAll(extra);
    }
    return picks.take(_kMaxAlbums).toList();
  }

  @override
  Widget buildPlaceholder(BuildContext context) =>
      const NewAlbumRowPlaceholder();

  @override
  Widget buildContent(BuildContext context, List<Album> data) =>
      NewAlbumRow(albums: data);
}
