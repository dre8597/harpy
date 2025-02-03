import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Validates a batch of post URIs to ensure they are accessible
  Future<List<AtUri>> _validatePosts(
    List<AtUri> uris,
    bsky.Bluesky blueskyApi,
  ) async {
    try {
      final response = await blueskyApi.feed.getPosts(uris: uris);
      // Only return URIs for posts that were successfully fetched
      return response.data.posts.map((post) => post.uri).toList();
    } catch (e, stack) {
      log.warning(
        'Error validating posts batch, skipping invalid posts',
        e,
        stack,
      );
      return [];
    }
  }

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

      // Extract the liked post URIs
      final likedPostUris = response.data.records
          .map((record) => record.value['subject']['uri'] as String?)
          .whereType<String>()
          .map(AtUri.parse)
          .toList();

      if (likedPostUris.isEmpty) {
        return TimelineResponse([], response.data.cursor);
      }

      // Process URIs in smaller batches to handle potential invalid posts
      final validatedUris = <AtUri>[];
      const batchSize = 25;

      for (var i = 0; i < likedPostUris.length; i += batchSize) {
        final end = (i + batchSize < likedPostUris.length)
            ? i + batchSize
            : likedPostUris.length;
        final batch = likedPostUris.sublist(i, end);

        if (!mounted) return TimelineResponse([], null);

        final validBatch = await _validatePosts(batch, blueskyApi);
        validatedUris.addAll(validBatch);
      }

      if (validatedUris.isEmpty) {
        return TimelineResponse([], response.data.cursor);
      }

      // Fetch the validated posts
      final postsResponse =
          await blueskyApi.feed.getPosts(uris: validatedUris.sublist(0, 4));

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

      return processedPosts;
    } catch (e, stack) {
      log.severe('Error fetching likes timeline', e, stack);
      rethrow;
    }
  }
}
