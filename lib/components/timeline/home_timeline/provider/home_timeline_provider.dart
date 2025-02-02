import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/timeline/provider/timeline_provider.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final homeTimelineProvider =
    StateNotifierProvider.autoDispose<HomeTimelineNotifier, TimelineState>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 15));

    return HomeTimelineNotifier(
      ref: ref,
    );
  },
  name: 'HomeTimelineProvider',
);

class HomeTimelineNotifier extends TimelineNotifier {
  HomeTimelineNotifier({
    required super.ref,
  });

  @override
  final log = Logger('HomeTimelineNotifier');

  @override
  TimelineFilter? currentFilter() {
    final state = ref.read(timelineFilterProvider);
    return state.filterByUuid(state.activeHomeFilter()?.uuid);
  }

  @override
  Future<TimelineResponse> request({String? cursor}) async {
    final blueskyApi = ref.read(blueskyApiProvider);

    print('requesting home timeline ${blueskyApi.session?.active}');

    final feed = await blueskyApi.feed.getTimeline(
      cursor: cursor,
      limit: 50,
    );

    return handleTimelinePosts(feed.data.feed, feed.data.cursor);
  }

  @override
  bool get restoreInitialPosition =>
      ref.read(generalPreferencesProvider).keepLastHomeTimelinePosition;

  @override
  bool get restoreRefreshPosition =>
      ref.read(generalPreferencesProvider).homeTimelineRefreshBehavior;

  int get restoredTweetId =>
      ref.read(tweetVisibilityPreferencesProvider).lastVisibleTweet;

  void addTweet(BlueskyPostData post) {
    final currentState = state;

    if (currentState is TimelineStateData) {
      final posts = List.of(currentState.tweets);
      posts.insert(0, post);

      state = currentState.copyWith(
        tweets: posts.toBuiltList(),
        isInitialResult: false,
      );
    }
  }

  void removeTweet(BlueskyPostData post) {
    final currentState = state;

    if (currentState is TimelineStateData) {
      final posts = List.of(currentState.tweets);
      posts.removeWhere((element) => element.id == post.id);

      state = currentState.copyWith(
        tweets: posts.toBuiltList(),
        isInitialResult: false,
      );
    }
  }
}
