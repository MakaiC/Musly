import 'package:flutter/cupertino.dart';
import 'package:musly/models/album.dart';
import 'package:musly/screens/media/album_collection_screen.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/utils/navigation_helper.dart';
import 'new_section.dart';

/// Section: "Recently Added", a horizontal row of the newest albums, with a
/// See All that opens the full New Releases list.
///
/// Data: `getAlbumList2?type=newest`, starting at [skip].
class RecentlyAddedSection extends StatefulWidget {
  const RecentlyAddedSection({super.key, this.skip = 0});

  /// Newest albums to leave out, e.g. the ones the hero carousel already
  /// features. Use 0 if the carousel is removed.
  final int skip;

  @override
  State<RecentlyAddedSection> createState() => _RecentlyAddedSectionState();
}

class _RecentlyAddedSectionState
    extends NewSectionState<RecentlyAddedSection, List<Album>> {
  @override
  String get title => 'Recently Added';

  @override
  String get emptyMessage => 'Nothing new on your server yet.';

  @override
  IconData get emptyIcon => CupertinoIcons.sparkles;

  @override
  VoidCallback? get onSeeAll => () => NavigationHelper.push(
        context,
        const AlbumCollectionScreen.newReleases(),
      );

  @override
  bool isEmpty(List<Album> data) => data.isEmpty;

  @override
  Future<List<Album>> fetch(SubsonicService api) =>
      api.getAlbumList(type: 'newest', size: 20, offset: widget.skip);

  @override
  Widget buildPlaceholder(BuildContext context) =>
      const NewAlbumRowPlaceholder();

  @override
  Widget buildContent(BuildContext context, List<Album> data) =>
      NewAlbumRow(albums: data);
}
