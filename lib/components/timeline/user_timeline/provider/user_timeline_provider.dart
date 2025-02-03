import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final userTimelineProvider =
    StateNotifierProvider.autoDispose.family<UserTimelineNotifier, TimelineState, String>(
  (ref, userId) {
    ref.cacheFor(const Duration(minutes: 5));

    return UserTimelineNotifier(
      ref: ref,
      userId: userId,
    );
  },
  name: 'UserTimelineProvider',
);

class UserTimelineNotifier extends TimelineNotifier {
  UserTimelineNotifier({
    required super.ref,
    required String userId,
  }) : _userId = userId {
    load();
  }

  final String _userId;
  @override
  final log = Logger('UserTimelineNotifier');

  @override
  TimelineFilter? currentFilter() {
    final state = ref.read(timelineFilterProvider);
    return state.filterByUuid(state.activeUserFilter(_userId)?.uuid);
  }

  @override
  Future<TimelineResponse> request({String? cursor}) async {
    final blueskyApi = ref.read(blueskyApiProvider);
    final feed = await blueskyApi.feed.getAuthorFeed(
      actor: _userId,
      cursor: cursor,
      limit: 100,
    );
    final posts = feed.data.feed.map(BlueskyPostData.fromFeedView).toList();
    return TimelineResponse(posts, feed.data.cursor);
  }
}
