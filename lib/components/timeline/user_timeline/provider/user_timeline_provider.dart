import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';

final userTimelineProvider = StateNotifierProvider.autoDispose
    .family<UserTimelineNotifier, TimelineState, String>(
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
    if (state.tweets.isEmpty) {
      state = const TimelineState.loading();
    }

    try {
      final feed = await blueskyApi.feed.getAuthorFeed(
        actor: _userId,
        cursor: cursor,
        limit: 100,
        includePins: true,
      );

      if (!mounted) return TimelineResponse([], null);

      // Process the posts using the timeline helper for proper filtering
      final processedPosts = await handleTimelinePosts(
        feed.data.feed,
        feed.data.cursor,
      );

      // For each post that is a reply, fetch its parent post
      for (var i = 0; i < processedPosts.posts.length; i++) {
        final post = processedPosts.posts[i];
        if (post.parentPostId != null) {
          try {
            final threadResponse = await blueskyApi.feed.getPostThread(
              uri: post.uri,
            );

            if (threadResponse.data.thread is bsky.UPostThreadViewRecord) {
              final threadView =
                  (threadResponse.data.thread as bsky.UPostThreadViewRecord)
                      .data;
              if (threadView.parent != null) {
                threadView.parent!.map(
                  record: (record) {
                    final parentFeedView = bsky.FeedView(
                      post: record.data.post,
                    );
                    final parentPost =
                        BlueskyPostData.fromFeedView(parentFeedView);
                    processedPosts.posts[i] = post.copyWith(
                      parentPost: parentPost,
                    );
                  },
                  notFound: (_) {},
                  blocked: (_) {},
                  unknown: (_) {},
                );
              }
            }
          } catch (e, stack) {
            log.warning('Error fetching parent post', e, stack);
          }
        }
      }

      return processedPosts;
    } catch (e, stack) {
      log.severe('Error fetching user timeline', e, stack);
      rethrow;
    }
  }
}
