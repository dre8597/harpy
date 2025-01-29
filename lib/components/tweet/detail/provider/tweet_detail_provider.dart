import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';

final tweetDetailProvider = StateNotifierProvider.family
    .autoDispose<TweetDetailNotifier, AsyncValue<BlueskyPostData>, String>(
  name: 'TweetDetailProvider',
  (ref, id) => TweetDetailNotifier(
    id: id,
    twitterApi: ref.watch(twitterApiV1Provider),
  ),
);

class TweetDetailNotifier extends StateNotifier<AsyncValue<BlueskyPostData>> {
  TweetDetailNotifier({
    required String id,
    required TwitterApi twitterApi,
  })  : _id = id,
        _twitterApi = twitterApi,
        super(const AsyncValue.loading());

  final String _id;
  final TwitterApi _twitterApi;

  Future<void> load([BlueskyPostData? tweet]) async {
    if (tweet != null) {
      state = AsyncData(tweet);
    } else {
      state = await AsyncValue.guard(
        () => _twitterApi.tweetService
            .show(id: _id)
            .then(BlueskyPostData.fromTweet),
      );
    }
  }
}
