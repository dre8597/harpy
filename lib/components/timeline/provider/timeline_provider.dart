import 'dart:async';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/handle_posts.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

part 'timeline_provider.freezed.dart';

/// Response from a timeline request containing the posts and cursor for pagination.
class TimelineResponse {
  TimelineResponse(this.posts, this.cursor);

  final List<BlueskyPostData> posts;
  final String? cursor;
}

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
    _initialize();
  }

  @protected
  final Ref ref;

  @protected
  late final bsky.Bluesky blueskyApi;

  TimelineFilter? filter;

  void _initialize() {
    if (!mounted) return;

    blueskyApi = ref.watch(blueskyApiProvider);
    filter = currentFilter();

    ref.listen(
      timelineFilterProvider,
      (_, __) {
        if (!mounted) return;
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
  TimelineFilter? currentFilter();

  /// Abstract method that subclasses must implement to fetch their specific
  /// timeline data.
  @protected
  Future<TimelineResponse> request({String? cursor});

  /// Helper method to process feed views into a timeline response.
  ///
  /// This method handles the conversion of feed views into [BlueskyPostData]
  /// objects, including proper handling of reply chains and filtering.
  @protected
  Future<TimelineResponse> handleTimelinePosts(
    List<bsky.FeedView> posts,
    String? cursor,
  ) async {
    final processedPosts = await handlePosts(posts, filter);
    return TimelineResponse(processedPosts.toList(), cursor);
  }

  Future<void> load({bool clearPrevious = false}) async {
    if (!mounted) return;

    if (clearPrevious) {
      state = const TimelineState.loading();
    } else {
      state = state.copyWith(loadingMore: true);
    }

    if (!lock()) {
      try {
        final cursor = clearPrevious ? null : state.cursor;
        final response = await request(cursor: cursor);

        if (!mounted) return;

        if (response.posts.isEmpty) {
          if (clearPrevious) {
            state = const TimelineState.noData();
          } else {
            state = state.copyWith(loadingMore: false);
          }
        } else {
          if (clearPrevious) {
            state = TimelineState.data(
              tweets: BuiltList.of(response.posts),
              cursor: response.cursor,
              customData: buildCustomData(BuiltList.of(response.posts)),
            );
          } else {
            // Deduplicate posts based on both id and uri to ensure uniqueness
            final existingPosts = state.tweets.toSet();
            final newPosts = response.posts.where(
              (post) => !existingPosts.any(
                (existing) =>
                    existing.id == post.id || existing.uri == post.uri,
              ),
            );

            final allTweets = [...state.tweets, ...newPosts];
            state = state.copyWith(
              tweets: BuiltList.of(allTweets),
              cursor: response.cursor,
              loadingMore: false,
            );
          }
        }
      } catch (error, stackTrace) {
        if (!mounted) return;
        log.severe('error loading timeline', error, stackTrace);
        state = const TimelineState.error();
      }
    }
  }

  Future<void> loadMore() async {
    if (!mounted) return;

    final currentState = state;
    if (!currentState.canLoadMore) return;

    final cursor = currentState.cursor;
    if (cursor == null) return;

    if (!lock()) {
      try {
        state = TimelineState.loadingMore(
          data: currentState as TimelineStateData<T>,
        );

        final response = await request(cursor: cursor);

        if (!mounted) return;

        if (response.posts.isEmpty) {
          state = currentState.copyWith(loadingMore: false);
        } else {
          // Deduplicate posts by comparing post ids
          final existingPostIds =
              currentState.tweets.map((post) => post.id).toSet();
          final newPosts = response.posts
              .where((post) => !existingPostIds.contains(post.id))
              .toList();

          final allTweets = [...state.tweets, ...newPosts];
          state = state.copyWith(
            tweets: BuiltList.of(allTweets),
            cursor: response.cursor,
            loadingMore: false,
          );
        }
      } catch (error, stackTrace) {
        if (!mounted) return;
        log.severe('error loading more tweets', error, stackTrace);
        state = TimelineState.data(
          tweets: currentState.tweets,
          cursor: cursor,
        );
      }
    }
  }

  /// Refreshes the timeline by loading new posts since the newest post in the
  /// timeline.
  Future<void> refresh() async {
    if (state.tweets.isEmpty) {
      return load();
    }

    state = state.copyWith(refreshing: true);

    try {
      final response = await request();

      if (response.posts.isNotEmpty) {
        // Deduplicate posts by comparing post ids
        final existingPostIds = state.tweets.map((post) => post.id).toSet();
        final newPosts = response.posts
            .where((post) => !existingPostIds.contains(post.id))
            .toList();

        final allTweets = [...state.tweets, ...newPosts];
        state = TimelineState.data(
          tweets: BuiltList.of(allTweets),
          cursor: response.cursor,
          customData: buildCustomData(BuiltList.of(allTweets)),
        );
      } else {
        state = state.copyWith(refreshing: false);
      }
    } catch (error, stackTrace) {
      log.severe('error refreshing timeline', error, stackTrace);
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

  String? get cursor => when<String?>(
        initial: () => null,
        loading: () => null,
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
            cursor,
        noData: () => null,
        loadingMore: (data) => (data as TimelineStateData<T>).cursor,
        error: () => null,
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
