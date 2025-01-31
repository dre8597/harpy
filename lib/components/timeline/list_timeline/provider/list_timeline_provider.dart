import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final listTimelineProvider = StateNotifierProvider.autoDispose
    .family<ListTimelineNotifier, TimelineState, String>(
  (ref, listId) {
    ref.cacheFor(const Duration(minutes: 5));

    return ListTimelineNotifier(
      ref: ref,
      blueskyApi: ref.watch(blueskyApiProvider),
      listId: listId,
    );
  },
  name: 'ListTimelineProvider',
);

class ListTimelineNotifier extends TimelineNotifier {
  ListTimelineNotifier({
    required super.ref,
    required super.blueskyApi,
    required String listId,
  }) : _listId = listId {
    loadInitial();
  }

  final String _listId;
  @override
  final log = Logger('ListTimelineNotifier');

  @override
  TimelineFilter? currentFilter() => null; // Lists don't use filters in Bluesky

  @override
  Future<List<BlueskyPostData>> request({
    String? cursor,
  }) async {
    final feed = await blueskyApi.feed.getFeed(
      generatorUri: AtUri.parse(_listId),
      cursor: cursor,
      limit: 50,
    );

    return feed.data.feed.map(BlueskyPostData.fromFeedView).toList();
  }
}
