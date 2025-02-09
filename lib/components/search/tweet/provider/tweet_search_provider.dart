import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:logging/logging.dart';
import 'package:rby/misc/logger/logger.dart';

part 'tweet_search_provider.freezed.dart';

final tweetSearchProvider =
    StateNotifierProvider.autoDispose<TweetSearchNotifier, TweetSearchState>(
  (ref) => TweetSearchNotifier(
    ref: ref,
  ),
  name: 'TweetSearchProvider',
);

class TweetSearchNotifier extends StateNotifier<TweetSearchState>
    with LoggerMixin {
  TweetSearchNotifier({
    required Ref ref,
  })  : _ref = ref,
        super(const TweetSearchState.initial());

  final Ref _ref;
  @override
  final log = Logger('TweetSearchNotifier');

  bool _isLoading = false;

  bool _matchesFilter(BlueskyPostData post, TweetSearchFilterData filter) {
    // Handle exclusions first
    if (filter.excludesRetweets && post.isRepost) return false;
    if (filter.excludesImages && post.hasImages) return false;
    if (filter.excludesVideo && post.hasVideo) return false;

    for (final phrase in filter.excludesPhrases) {
      if (post.text.toLowerCase().contains(phrase.toLowerCase())) return false;
    }

    for (final hashtag in filter.excludesHashtags) {
      if (post.text.toLowerCase().contains(hashtag.toLowerCase())) return false;
    }

    for (final mention in filter.excludesMentions) {
      if (post.text.toLowerCase().contains(mention.toLowerCase())) return false;
    }

    // Handle inclusions
    if (filter.includesRetweets && !post.isRepost) return false;
    if (filter.includesImages && !post.hasImages) return false;
    if (filter.includesVideo && !post.hasVideo) return false;

    var matchesAnyPhrase = filter.includesPhrases.isEmpty;
    for (final phrase in filter.includesPhrases) {
      if (post.text.toLowerCase().contains(phrase.toLowerCase())) {
        matchesAnyPhrase = true;
        break;
      }
    }
    if (!matchesAnyPhrase) return false;

    var matchesAnyHashtag = filter.includesHashtags.isEmpty;
    for (final hashtag in filter.includesHashtags) {
      if (post.text.toLowerCase().contains(hashtag.toLowerCase())) {
        matchesAnyHashtag = true;
        break;
      }
    }
    if (!matchesAnyHashtag) return false;

    var matchesAnyMention = filter.includesMentions.isEmpty;
    for (final mention in filter.includesMentions) {
      if (post.text.toLowerCase().contains(mention.toLowerCase())) {
        matchesAnyMention = true;
        break;
      }
    }
    if (!matchesAnyMention) return false;

    return true;
  }

  List<BlueskyPostData> _filterPosts(
    List<BlueskyPostData> posts,
    TweetSearchFilterData filter,
  ) {
    if (filter.isEmpty()) return posts;
    return posts.where((post) => _matchesFilter(post, filter)).toList();
  }

  Future<void> search({
    String? customQuery,
    String? hashTag,
    TweetSearchFilterData? filter,
  }) async {
    final query = customQuery ?? filter?.buildQuery();

    if ((query == null || query.isEmpty) && hashTag == null) {
      log.warning('built search query and hashtag are both empty');
      return;
    }

    log.fine('searching posts');

    state = TweetSearchState.loading(query: query ?? '', filter: filter);
    _isLoading = true;

    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      // Use API-level filtering where possible
      final searchResult = await blueskyApi.feed.searchPosts(
        query ?? '', // Query can be empty if we're searching by other filters
        tag: hashTag != null ? [hashTag] : filter?.includesHashtags ?? [],
        mentions: filter?.includesMentions.firstOrNull,
        author: filter?.author,
        cursor: state.cursor,
        limit: 100,
        url: filter?.url,
      );

      if (searchResult.data.posts.isEmpty) {
        log.fine('found no posts for query: $query');
        state = TweetSearchState.noData(query: query ?? '', filter: filter);
      } else {
        log.fine(
          'found ${searchResult.data.posts.length} posts for query: $query',
        );

        var posts = searchResult.data.posts
            .map(
              (post) => BlueskyPostData.fromFeedView(
                bsky.FeedView(post: post),
              ),
            )
            .toList();

        // Apply client-side filtering if needed
        if (filter != null) {
          posts = _filterPosts(posts, filter);
        }
        if (!mounted) return;
        state = TweetSearchState.data(
          tweets: posts.toBuiltList(),
          query: query ?? '',
          filter: filter,
          cursor: searchResult.data.cursor,
          hasReachedEnd: searchResult.data.cursor == null || posts.isEmpty,
        );
      }
    } catch (e, st) {
      log.severe('Error searching posts', e, st);
      state = TweetSearchState.error(query: query ?? '', filter: filter);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading) return;

    final currentState = state;
    if (!currentState.maybeMap(
      data: (data) => data.cursor != null && !data.hasReachedEnd,
      orElse: () => false,
    )) {
      return;
    }

    _isLoading = true;
    final query = currentState.query!;
    final filter = currentState.filter;
    final cursor = currentState.maybeMap(
      data: (data) => data.cursor,
      orElse: () => null,
    );

    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      final searchResult = await blueskyApi.feed.searchPosts(
        query,
        tag: filter?.includesHashtags ?? [],
        mentions: filter?.includesMentions.firstOrNull,
        author: filter?.author,
        cursor: cursor,
        url: filter?.url,
        limit: 100,
      );

      if (searchResult.data.posts.isNotEmpty) {
        var newPosts = searchResult.data.posts
            .map(
              (post) => BlueskyPostData.fromFeedView(
                bsky.FeedView(post: post),
              ),
            )
            .toList();

        // Apply client-side filtering if needed
        if (filter != null) {
          newPosts = _filterPosts(newPosts, filter);
        }

        state = currentState.maybeMap(
          data: (data) => TweetSearchState.data(
            tweets: data.tweets.rebuild((b) => b..addAll(newPosts)),
            query: query,
            filter: filter,
            cursor: searchResult.data.cursor,
            hasReachedEnd:
                searchResult.data.cursor == state.cursor || data.cursor == null,
          ),
          orElse: () => state,
        );
      } else {
        state = currentState.maybeMap(
          data: (data) => data.copyWith(hasReachedEnd: true),
          orElse: () => state,
        );
      }
    } catch (e, st) {
      log.severe('Error loading more posts', e, st);
      // Keep the current state on error
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() {
    return search(
      customQuery: state.query,
      filter: state.filter,
    );
  }

  void clear() => state = const TweetSearchState.initial();
}

@freezed
class TweetSearchState with _$TweetSearchState {
  const factory TweetSearchState.initial() = _Initial;

  const factory TweetSearchState.loading({
    required String query,
    required TweetSearchFilterData? filter,
    @Default(null) String? cursor,
  }) = _Loading;

  const factory TweetSearchState.data({
    required BuiltList<BlueskyPostData> tweets,
    required String query,
    required TweetSearchFilterData? filter,
    @Default(null) String? cursor,
    @Default(false) bool hasReachedEnd,
  }) = _Data;

  const factory TweetSearchState.noData({
    required String query,
    required TweetSearchFilterData? filter,
  }) = _NoData;

  const factory TweetSearchState.error({
    required String query,
    required TweetSearchFilterData? filter,
    @Default(null) String? cursor,
  }) = _Error;

  const TweetSearchState._();
}

extension TweetSearchStateExtension on TweetSearchState {
  BuiltList<BlueskyPostData> get tweets => maybeMap(
        data: (value) => value.tweets,
        orElse: BuiltList.new,
      );

  String? get query => mapOrNull(
        data: (value) => value.query,
        noData: (value) => value.query,
        loading: (value) => value.query,
        error: (value) => value.query,
      );

  TweetSearchFilterData? get filter => mapOrNull<TweetSearchFilterData?>(
        loading: (value) => value.filter,
        data: (value) => value.filter,
        noData: (value) => value.filter,
        error: (value) => value.filter,
      );

  String? get cursor => mapOrNull(
        data: (value) => value.cursor,
        loading: (value) => value.cursor,
        error: (value) => value.cursor,
      );

  bool get hasReachedEnd => maybeMap(
        data: (value) => value.hasReachedEnd,
        orElse: () => true,
      );
}
