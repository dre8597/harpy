import 'dart:async';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

part 'timeline_provider.freezed.dart';

/// Implements common functionality for notifiers that handle timelines.
///
/// Implementations can use the generic type to build their own custom data
/// which available in [TimelineStateData].
///
/// Listens to the [timelineFilterProvider] and updates the timeline when the
/// filter changes.
///
/// For example implementations, see:
/// * [HomeTimelineNotifier]
/// * [LikesTimelineNotifier]
/// * [ListTimelineNotifier]
/// * [MentionsTimelineNotifier]
/// * [UserTimelineNotifier]
abstract class TimelineNotifier<T extends Object>
    extends StateNotifier<TimelineState<T>> with RequestLock, LoggerMixin {
  TimelineNotifier({
    required this.ref,
  }) : super(const TimelineState.initial()) {
    blueskyApi = ref.watch(blueskyApiProvider);
    filter = currentFilter();

    ref.listen(
      timelineFilterProvider,
      (_, __) {
        final newFilter = currentFilter();

        if (filter != newFilter) {
          log.fine('updated timeline filter');
          filter = newFilter;
          load(clearPrevious: true);
        }
      },
    );
  }

  @protected
  final Ref ref;

  @protected
  late final bsky.Bluesky blueskyApi;

  /// The current filter for the timeline.
  TimelineFilter? filter;

  /// Returns the current filter for this timeline.
  TimelineFilter? currentFilter();

  /// Makes a request to get the posts for this timeline.
  /// [cursor] is used for pagination in Bluesky's API.
  Future<List<BlueskyPostData>> request({String? cursor});

  /// Loads the initial posts for this timeline.
  Future<void> loadInitial() => load(clearPrevious: true);

  /// Loads more posts for this timeline.
  ///
  /// When [clearPrevious] is `true`, the previous posts are removed and the
  /// timeline starts fresh.
  Future<void> load({bool clearPrevious = false}) async {
    if (clearPrevious) {
      state = TimelineState.loading();
    } else {
      state = state.copyWith(loadingMore: true);
    }

    try {
      final cursor = clearPrevious ? null : state.tweets.lastOrNull?.id;
      final posts = await request(cursor: cursor);

      if (posts.isEmpty) {
        if (clearPrevious) {
          state = TimelineState.noData();
        } else {
          state = state.copyWith(loadingMore: false);
        }
      } else {
        if (clearPrevious) {
          state = TimelineState.data(
            tweets: BuiltList.of(posts),
            cursor: posts.lastOrNull?.id,
            customData: buildCustomData(BuiltList.of(posts)),
          );
        } else {
          final allTweets = [...state.tweets, ...posts];
          state = state.copyWith(
            tweets: BuiltList.of(allTweets),
            cursor: posts.lastOrNull?.id,
            loadingMore: false,
          );
        }
      }
    } catch (e, st) {
      log.severe('error loading timeline', e, st);
      state = TimelineState.error();
    }
  }

  /// Loads older posts for this timeline.
  Future<void> loadOlder() => load();

  /// Refreshes the timeline by loading new posts since the newest post in the
  /// timeline.
  Future<void> refresh() async {
    if (state.tweets.isEmpty) {
      return loadInitial();
    }

    state = state.copyWith(refreshing: true);

    try {
      final posts = await request();

      if (posts.isNotEmpty) {
        state = TimelineState.data(
          tweets: BuiltList.of(posts),
          cursor: posts.lastOrNull?.id,
          customData: buildCustomData(BuiltList.of(posts)),
        );
      } else {
        state = state.copyWith(refreshing: false);
      }
    } catch (e, st) {
      log.severe('error refreshing timeline', e, st);
      state = state.copyWith(refreshing: false);
    }
  }

  @protected
  bool get restoreInitialPosition => false;

  @protected
  bool get restoreRefreshPosition => false;

  @protected
  String get restoredPostId => '';

  @protected
  T? buildCustomData(BuiltList<BlueskyPostData> posts) => null;

  Future<void> loadAndRestore(String postId) async {
    final posts = await _loadPostsSince(postId);

    if (posts.isNotEmpty) {
      log.fine('found ${posts.length} posts');

      final cursor = posts.lastOrNull?.id;

      BlueskyPostData? restoredPost;
      int? restoredPostIndex;

      for (var i = 0; i < posts.length; i++) {
        final id = posts[i].rootPostId;
        if (id == null) continue;

        if (id == postId) {
          restoredPost = posts[i];
          restoredPostIndex = i;
          break;
        }
      }

      if (restoredPostIndex != null && restoredPostIndex > 1) {
        final data = TimelineStateData(
          tweets: BuiltList.of(posts.sublist(0, restoredPostIndex)),
          cursor: cursor,
          initialResultsCount: restoredPostIndex,
          initialResultsLastId: restoredPost!.rootPostId ?? '',
          isInitialResult: true,
          customData: buildCustomData(BuiltList.of(posts)),
        );

        state = TimelineState.loadingMore(data: data);
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        state = data.copyWith(
          tweets: BuiltList.of(
            data.tweets.followedBy(posts.sublist(restoredPostIndex)),
          ),
          cursor: cursor,
          isInitialResult: false,
        );
      } else {
        state = TimelineState.data(
          tweets: BuiltList.of(posts),
          cursor: cursor,
          customData: buildCustomData(BuiltList.of(posts)),
        );
      }
    } else {
      state = const TimelineState.error();
    }
  }

  Future<List<BlueskyPostData>> _loadPostsSince(String postId) async {
    final timelinePosts = <BlueskyPostData>[];
    String? cursor;

    for (var i = 0; i < 3; i++) {
      try {
        final morePosts = await request(cursor: cursor);
        if (morePosts.isEmpty) break;

        if (morePosts.isNotEmpty) {
          cursor = morePosts.last.id;
        }

        timelinePosts.addAll(morePosts);

        if (morePosts.any((post) => post.rootPostId == postId)) break;
      } catch (e, st) {
        log.severe('error loading posts', e, st);
        break;
      }
    }

    return timelinePosts;
  }
}

@freezed
class TimelineState<T extends Object> with _$TimelineState<T> {
  const factory TimelineState.initial() = TimelineStateInitial<T>;

  const factory TimelineState.loading() = TimelineStateLoading<T>;

  const factory TimelineState.data({
    required BuiltList<BlueskyPostData> tweets,
    required String? cursor,
    String? initialResultsLastId,
    int? initialResultsCount,
    @Default(false) bool isInitialResult,
    @Default(false) bool refreshing,
    @Default(false) bool loadingMore,
    @Default(false) bool clearPrevious,
    T? customData,
  }) = TimelineStateData<T>;

  const factory TimelineState.noData() = TimelineStateNoData<T>;

  const factory TimelineState.loadingMore({
    required TimelineStateData<T> data,
  }) = TimelineStateLoadingOlder<T>;

  const factory TimelineState.error() = TimelineStateError<T>;
}

extension TimelineStateExtension<T extends Object> on TimelineState<T> {
  bool get canLoadMore => when<bool>(
        initial: () => false,
        loading: () => false,
        data: (
          tweets,
          cursor,
          initialResultsLastId,
          initialResultsCount,
          isInitialResult,
          refreshing,
          loadingMore,
          clearPrevious,
          customData,
        ) =>
            cursor != null,
        noData: () => false,
        loadingMore: (data) => data.cursor != null,
        error: () => false,
      );

  BuiltList<BlueskyPostData> get tweets => when<BuiltList<BlueskyPostData>>(
        initial: () => BuiltList<BlueskyPostData>.of([]),
        loading: () => BuiltList<BlueskyPostData>.of([]),
        data: (
          tweets,
          cursor,
          initialResultsLastId,
          initialResultsCount,
          isInitialResult,
          refreshing,
          loadingMore,
          clearPrevious,
          customData,
        ) =>
            tweets,
        noData: () => BuiltList<BlueskyPostData>.of([]),
        loadingMore: (data) => data.tweets as BuiltList<BlueskyPostData>,
        error: () => BuiltList<BlueskyPostData>.of([]),
      );

  int get initialResultsCount => when<int>(
        initial: () => 0,
        loading: () => 0,
        data: (
          tweets,
          cursor,
          initialResultsLastId,
          initialResultsCount,
          isInitialResult,
          refreshing,
          loadingMore,
          clearPrevious,
          customData,
        ) =>
            initialResultsCount ?? 0,
        noData: () => 0,
        loadingMore: (data) =>
            (data as TimelineStateData<T>).initialResultsCount ?? 0,
        error: () => 0,
      );

  bool showNewTweetsExist(String? originalIdStr) => when<bool>(
        initial: () => false,
        loading: () => false,
        data: (
          tweets,
          cursor,
          initialResultsLastId,
          initialResultsCount,
          isInitialResult,
          refreshing,
          loadingMore,
          clearPrevious,
          customData,
        ) =>
            initialResultsLastId == originalIdStr &&
            (initialResultsCount ?? 0) > 1,
        noData: () => false,
        loadingMore: (data) =>
            (data as TimelineStateData<T>).initialResultsLastId ==
                originalIdStr &&
            (data.initialResultsCount ?? 0) > 1,
        error: () => false,
      );

  bool get scrollToEnd => when<bool>(
        initial: () => false,
        loading: () => false,
        data: (
          tweets,
          cursor,
          initialResultsLastId,
          initialResultsCount,
          isInitialResult,
          refreshing,
          loadingMore,
          clearPrevious,
          customData,
        ) =>
            isInitialResult && (initialResultsCount ?? 0) > 0,
        noData: () => false,
        loadingMore: (data) =>
            (data as TimelineStateData<T>).isInitialResult &&
            (data.initialResultsCount ?? 0) > 0,
        error: () => false,
      );

  TimelineState<T> copyWith({
    BuiltList<BlueskyPostData>? tweets,
    String? cursor,
    String? initialResultsLastId,
    int? initialResultsCount,
    bool? isInitialResult,
    bool? refreshing,
    bool? loadingMore,
    bool? clearPrevious,
    T? customData,
  }) =>
      when<TimelineState<T>>(
        initial: () => this,
        loading: () => this,
        data: (
          currentTweets,
          currentCursor,
          currentInitialResultsLastId,
          currentInitialResultsCount,
          currentIsInitialResult,
          currentRefreshing,
          currentLoadingMore,
          currentClearPrevious,
          currentCustomData,
        ) =>
            TimelineState<T>.data(
          tweets: tweets ?? currentTweets,
          cursor: cursor ?? currentCursor,
          initialResultsLastId:
              initialResultsLastId ?? currentInitialResultsLastId,
          initialResultsCount:
              initialResultsCount ?? currentInitialResultsCount,
          isInitialResult: isInitialResult ?? currentIsInitialResult,
          refreshing: refreshing ?? currentRefreshing,
          loadingMore: loadingMore ?? currentLoadingMore,
          clearPrevious: clearPrevious ?? currentClearPrevious,
          customData: customData ?? currentCustomData,
        ),
        noData: () => this,
        loadingMore: (data) => this,
        error: () => this,
      );
}
