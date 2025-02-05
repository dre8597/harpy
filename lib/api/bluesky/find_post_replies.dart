import 'package:bluesky/bluesky.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';

/// A service to find replies to a post.
class FindPostReplies {
  FindPostReplies(this._ref);

  final Ref _ref;

  /// Finds replies to the [parentPost] with pagination support.
  ///
  /// Returns a [PostRepliesResult] containing the replies and cursor for pagination.
  Future<PostRepliesResult> findRepliesWithPagination(
    BlueskyPostData parentPost, {
    int? limit,
    String? cursor,
  }) async {
    final blueskyApi = _ref.read(blueskyApiProvider);
    final replies = <BlueskyPostData>[];

    try {
      // Get thread view for the post
      final response = await blueskyApi.feed.getPostThread(
        uri: parentPost.uri,
        depth: limit ?? 20,
      );

      // Handle replies based on thread type
      final thread = response.data;
      if (thread.thread.data is PostThreadViewRecord) {
        final threadView = thread.thread.data as PostThreadViewRecord;

        // Add the replies if they exist
        if (threadView.replies != null) {
          for (final reply in threadView.replies!) {
            reply.map(
              record: (record) {
                final feedView = FeedView(
                  post: record.data.post,
                );
                replies.add(BlueskyPostData.fromFeedView(feedView));
              },
              notFound: (_) => null,
              blocked: (_) => null,
              unknown: (_) => null,
            );
          }
        }
      }

      return PostRepliesResult(
        replies: replies,
      );
    } catch (e) {
      return PostRepliesResult(replies: []);
    }
  }

  /// Finds the parent post for a given post.
  ///
  /// Returns the parent [BlueskyPostData] if it exists, null otherwise.
  Future<BlueskyPostData?> findParentPost(BlueskyPostData post) async {
    if (post.parentPostId == null) return null;

    final blueskyApi = _ref.read(blueskyApiProvider);

    try {
      // Get thread view for the post
      final response = await blueskyApi.feed.getPostThread(
        uri: post.uri,
      );

      // Process the thread based on its type
      final threadView = response.data;
      if (threadView.thread is PostThreadViewRecord) {
        final view = threadView.thread as PostThreadViewRecord;

        // Return parent post if it exists
        if (view.parent != null) {
          return view.parent!.map(
            record: (record) {
              final feedView = FeedView(
                post: record.data.post,
              );
              return BlueskyPostData.fromFeedView(feedView);
            },
            notFound: (_) => null,
            blocked: (_) => null,
            unknown: (_) => null,
          );
        }
      }
    } catch (e) {
      // TODO: Implement proper error handling
      return null;
    }

    return null;
  }

  /// Finds the conversation thread for a post.
  ///
  /// Returns a list of [BlueskyPostData] that represents the conversation thread,
  /// including parent posts and replies.
  Future<List<BlueskyPostData>> findThread(BlueskyPostData post) async {
    final blueskyApi = _ref.read(blueskyApiProvider);
    final thread = <BlueskyPostData>[];

    try {
      // Get full thread view
      final response = await blueskyApi.feed.getPostThread(
        uri: post.uri,
        depth: 10, // Get a reasonable depth of replies
      );

      // Process the thread based on its type
      final threadView = response.data;
      if (threadView.thread is PostThreadViewRecord) {
        final view = threadView.thread as PostThreadViewRecord;

        // Add parent posts if they exist
        if (view.parent != null) {
          view.parent!.map(
            record: (record) {
              final feedView = FeedView(
                post: record.data.post,
              );
              thread.add(BlueskyPostData.fromFeedView(feedView));
            },
            notFound: (_) => null,
            blocked: (_) => null,
            unknown: (_) => null,
          );
        }

        // Add the post itself
        thread.add(post);

        // Add replies if they exist
        if (view.replies != null) {
          for (final reply in view.replies!) {
            reply.map(
              record: (record) {
                final feedView = FeedView(
                  post: record.data.post,
                );
                thread.add(BlueskyPostData.fromFeedView(feedView));
              },
              notFound: (_) => null,
              blocked: (_) => null,
              unknown: (_) => null,
            );
          }
        }
      } else {
        // Return only the original post for other thread types
        return [post];
      }

      return thread;
    } catch (e) {
      // TODO: Implement proper error handling
      return [post];
    }
  }
}

/// Result class for paginated replies.
class PostRepliesResult {
  PostRepliesResult({
    required this.replies,
    this.cursor,
  });

  final List<BlueskyPostData> replies;
  final String? cursor;

  bool get hasMore => cursor != null;
}

/// The provider for the [FindPostReplies] service.
final findPostRepliesProvider = Provider<FindPostReplies>(
  name: 'findPostRepliesProvider',
  FindPostReplies.new,
);
