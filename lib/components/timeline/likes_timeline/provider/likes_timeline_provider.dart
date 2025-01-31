import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final likesTimelineProvider = StateNotifierProvider.autoDispose
    .family<LikesTimelineNotifier, TimelineState, String>(
  (ref, userId) {
    ref.cacheFor(const Duration(minutes: 15));

    return LikesTimelineNotifier(
      ref: ref,
      blueskyApi: ref.watch(blueskyApiProvider),
      userId: userId,
    );
  },
  name: 'LikesTimelineProvider',
);

class LikesTimelineNotifier extends TimelineNotifier {
  LikesTimelineNotifier({
    required super.ref,
    required super.blueskyApi,
    required String userId,
  }) : _userId = userId {
    loadInitial();
  }

  final String _userId;
  @override
  final log = Logger('LikesTimelineNotifier');

  @override
  TimelineFilter? currentFilter() => null;

  @override
  Future<List<BlueskyPostData>> request({
    String? cursor,
  }) async {
    final feed = await blueskyApi.feed.getActorLikes(
      actor: _userId,
      cursor: cursor,
      limit: 50,
    );

    return feed.data.feed.map(BlueskyPostData.fromFeedView).toList();
  }
}
