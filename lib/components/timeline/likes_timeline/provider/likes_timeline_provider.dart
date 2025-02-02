import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final likesTimelineProvider =
    StateNotifierProvider.autoDispose.family<LikesTimelineNotifier, TimelineState, String>(
  (ref, userId) {
    ref.cacheFor(const Duration(minutes: 15));

    return LikesTimelineNotifier(
      ref: ref,
      userId: userId,
    );
  },
  name: 'LikesTimelineProvider',
);

class LikesTimelineNotifier extends TimelineNotifier {
  LikesTimelineNotifier({
    required super.ref,
    required String userId,
  }) : _userId = userId {
    load();
  }

  final String _userId;
  @override
  final log = Logger('LikesTimelineNotifier');

  @override
  TimelineFilter? currentFilter() => null;

  @override
  Future<TimelineResponse> request({String? cursor}) async {
    final feed = await blueskyApi.feed.getActorLikes(
      actor: _userId,
      cursor: cursor,
      limit: 50,
    );

    return TimelineResponse(
      feed.data.feed.map(BlueskyPostData.fromFeedView).toList(),
      feed.data.cursor,
    );
  }
}
