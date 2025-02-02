import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/atproto.dart';
import 'package:bluesky/core.dart';

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
    final blueskyApi = ref.read(blueskyApiProvider);

    try {
      // Get the user's likes using the listRecords endpoint
      final response = await blueskyApi.atproto.repo.listRecords(
        collection: NSID.parse('app.bsky.feed.like'),
        repo: _userId,
        cursor: cursor,
        limit: 50,
      );

      if (!mounted) return TimelineResponse([], null);

      // Extract the liked post URIs and fetch their details
      final likedPostUris = response.data.records
          .map((record) => record.value['subject']['uri'] as String?)
          .whereType<String>()
          .map(AtUri.parse)
          .toList();

      if (likedPostUris.isEmpty) {
        return TimelineResponse([], response.data.cursor);
      }

      // Fetch the actual posts using getPosts
      final postsResponse = await blueskyApi.feed.getPosts(uris: [likedPostUris.first]);

      if (!mounted) return TimelineResponse([], null);

      // Convert the posts to feed views for compatibility with handleTimelinePosts
      final feedViews = postsResponse.data.posts
          .map(
            (post) => bsky.FeedView(
              post: post,
            ),
          )
          .toList();

      // Process the posts using the timeline helper
      final processedPosts = await handleTimelinePosts(
        feedViews,
        response.data.cursor,
      );
//TODO: Finish figuring out how to properly map all likes
      return processedPosts;
    } catch (e, stack) {
      log.severe('Error fetching likes timeline', e, stack);
      rethrow;
    }
  }
}
