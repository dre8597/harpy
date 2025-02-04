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

  static const _batchSize = 25;

  @override
  TimelineFilter? currentFilter() {
    final activeFilter =
        ref.read(timelineFilterProvider).activeUserFilter(_userId);
    return ref.read(timelineFilterProvider).filterByUuid(activeFilter?.uuid);
  }

  /// Processes a batch of posts and returns valid feed views
  Future<List<bsky.FeedView>> _processBatch(
    List<AtUri> uris,
    bsky.Bluesky blueskyApi,
  ) async {
    if (!mounted) return [];

    try {
      final response = await blueskyApi.feed.getPosts(uris: uris);

      return response.data.posts
          .map((post) => bsky.FeedView(post: post))
          .toList();
    } catch (e, stack) {
      log.warning('Error processing batch of ${uris.length} posts', e, stack);

      // If batch fails and has more than one post, try processing individually
      if (uris.length > 1) {
        final individualResults = <bsky.FeedView>[];

        for (final uri in uris) {
          if (!mounted) return individualResults;

          try {
            final singleResponse = await blueskyApi.feed.getPosts(uris: [uri]);
            individualResults.addAll(
              singleResponse.data.posts
                  .map((post) => bsky.FeedView(post: post)),
            );
          } catch (e, stack) {
            log.fine('Skipping inaccessible post: $uri', e, stack);
          }
        }

        return individualResults;
      }
    }

    return [];
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
          .map((uri) {
            try {
              return AtUri.parse(uri);
            } catch (e) {
              log.warning('Invalid URI format: $uri');
              return null;
            }
          })
          .whereType<AtUri>()
          .toList();

      if (likedPostUris.isEmpty) {
        return TimelineResponse([], response.data.cursor);
      }

      // Process URIs in batches
      final allFeedViews = <bsky.FeedView>[];

      for (var i = 0; i < likedPostUris.length; i += _batchSize) {
        if (!mounted) break;

        final end = (i + _batchSize < likedPostUris.length)
            ? i + _batchSize
            : likedPostUris.length;

        final batch = likedPostUris.sublist(i, end);
        final batchResults = await _processBatch(batch, blueskyApi);

        allFeedViews.addAll(batchResults);
      }

      if (!mounted) return TimelineResponse([], null);

      if (allFeedViews.isEmpty) {
        return TimelineResponse([], response.data.cursor);
      }

      // Process the posts using the timeline helper
      final processedPosts = await handleTimelinePosts(
        allFeedViews,
        response.data.cursor,
      );

      return processedPosts;
    } catch (e, stack) {
      log.severe('Error fetching likes timeline', e, stack);
      rethrow;
    }
  }
}
