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

  List<BlueskyMediaData>? _processEmbed(bsky.EmbedView? embed) {
    if (embed == null) return null;

    return embed.map(
      record: (_) => null,
      images: (images) => images.data.images
          .map(
            (img) => BlueskyMediaData(
              url: img.fullsize,
              alt: img.alt,
            ),
          )
          .toList(),
      external: (_) => null,
      recordWithMedia: (recordWithMedia) {
        return recordWithMedia.data.media.map(
          images: (images) => images.data.images
              .map(
                (img) => BlueskyMediaData(
                  url: img.fullsize,
                  alt: img.alt,
                ),
              )
              .toList(),
          external: (_) => null,
          video: (video) => [
            BlueskyMediaData.fromUEmbedViewMediaVideo(video),
          ],
          unknown: (_) => null,
        );
      },
      video: (video) => [
        BlueskyMediaData(
          url: video.data.playlist,
          alt: video.data.alt ?? '',
          type: MediaType.video,
          thumb: video.data.thumbnail,
        ),
      ],
      unknown: (_) => null,
    );
  }

  Future<void> search({
    String? customQuery,
    TweetSearchFilterData? filter,
  }) async {
    final query = customQuery ?? filter?.buildQuery();

    if (query == null || query.isEmpty) {
      log.warning('built search query is empty');
      return;
    }

    log.fine('searching posts');

    state = TweetSearchState.loading(query: query, filter: filter);

    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      final searchResult = await blueskyApi.feed.searchPosts(query);

      if (searchResult.data.posts.isEmpty) {
        log.fine('found no posts for query: $query');
        state = TweetSearchState.noData(query: query, filter: filter);
      } else {
        log.fine(
          'found ${searchResult.data.posts.length} posts for query: $query',
        );

        final posts = searchResult.data.posts
            .map(
              (post) => BlueskyPostData(
                authorAvatar: post.author.avatar ?? '',
                authorDid: post.author.did,
                id: post.cid,
                uri: post.uri,
                text: post.record.text,
                author: post.author.displayName ?? '',
                handle: post.author.handle,
                createdAt: post.indexedAt,
                likeCount: post.likeCount,
                repostCount: post.repostCount,
                replyCount: post.replyCount,
                isLiked: post.viewer.like != null,
                isReposted: post.viewer.repost != null,
                media: _processEmbed(post.embed),
              ),
            )
            .toBuiltList();

        state = TweetSearchState.data(
          tweets: posts,
          query: query,
          filter: filter,
        );
      }
    } catch (e, st) {
      log.severe('Error searching posts', e, st);
      state = TweetSearchState.error(query: query, filter: filter);
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
  }) = _Loading;

  const factory TweetSearchState.data({
    required BuiltList<BlueskyPostData> tweets,
    required String query,
    required TweetSearchFilterData? filter,
  }) = _Data;

  const factory TweetSearchState.noData({
    required String query,
    required TweetSearchFilterData? filter,
  }) = _NoData;

  const factory TweetSearchState.error({
    required String query,
    required TweetSearchFilterData? filter,
  }) = _Error;
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
}
