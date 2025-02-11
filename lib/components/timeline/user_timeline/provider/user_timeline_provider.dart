import 'package:at_uri/at_uri.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

/// Provider for loading parent posts on demand when viewing thread details
final parentPostProvider =
    FutureProvider.autoDispose.family<BlueskyPostData?, String>(
  (ref, postUri) async {
    try {
      final blueskyApi = ref.read(blueskyApiProvider);
      final threadResponse = await blueskyApi.feed.getPostThread(
        uri: AtUri.parse(postUri),
      );

      if (threadResponse.data.thread is bsky.UPostThreadViewRecord) {
        final threadView =
            (threadResponse.data.thread as bsky.UPostThreadViewRecord).data;
        if (threadView.parent != null) {
          return threadView.parent!.map(
            record: (record) {
              final parentFeedView = bsky.FeedView(post: record.data.post);
              return BlueskyPostData.fromFeedView(parentFeedView);
            },
            notFound: (_) => null,
            blocked: (_) => null,
            unknown: (_) => null,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  },
  name: 'ParentPostProvider',
);

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

  static const int _postsPerPage = 50;

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
        limit: _postsPerPage,
        includePins: true,
      );

      if (!mounted) return TimelineResponse([], null);

      // Process the posts using the timeline helper for proper filtering
      final processedPosts = await handleTimelinePosts(
        feed.data.feed,
        feed.data.cursor,
      );

      return processedPosts;
    } catch (e, stack) {
      log.severe('Error fetching user timeline', e, stack);
      rethrow;
    }
  }

  /// Loads the parent post for a given post URI.
  /// This should be called when viewing thread details or when needed.
  Future<void> loadParentPost(String postUri) async {
    try {
      final parentPost = await ref.read(parentPostProvider(postUri).future);
      if (parentPost != null && mounted) {
        // Update the post in the timeline with its parent
        state = state.copyWith(
          tweets: BuiltList<BlueskyPostData>.of(
            state.tweets.map((post) {
              if (post.uri == postUri) {
                return post.copyWith(parentPost: parentPost);
              }
              return post;
            }),
          ),
        );
      }
    } catch (e, stack) {
      log.warning('Error loading parent post', e, stack);
    }
  }
}
