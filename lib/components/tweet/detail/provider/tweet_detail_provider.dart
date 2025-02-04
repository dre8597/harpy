import 'package:bluesky/bluesky.dart';
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';

final tweetDetailProvider = StateNotifierProvider.family
    .autoDispose<TweetDetailNotifier, AsyncValue<BlueskyPostData>, String>(
  name: 'TweetDetailProvider',
  (ref, id) => TweetDetailNotifier(
    id: id,
    blueskyApi: ref.watch(blueskyApiProvider),
  ),
);

class TweetDetailNotifier extends StateNotifier<AsyncValue<BlueskyPostData>> {
  TweetDetailNotifier({
    required String id,
    required Bluesky blueskyApi,
  })  : _id = id,
        _blueskyApi = blueskyApi,
        super(const AsyncValue.loading());

  final String _id;
  final Bluesky _blueskyApi;

  Future<void> load([BlueskyPostData? post]) async {
    if (post != null) {
      state = AsyncData(post);
    } else {
      state = await AsyncValue.guard(() async {
        final uri = AtUri.parse(_id);
        final response = await _blueskyApi.feed.getPosts(uris: [uri]);
        if (response.data.posts.isEmpty) {
          throw Exception('Post not found');
        }

        final feedView = FeedView(
          post: response.data.posts.first,
        );

        return BlueskyPostData.fromFeedView(feedView);
      });
    }
  }
}
