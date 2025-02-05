import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/find_post_replies.dart';
import 'package:logging/logging.dart';
import 'package:rby/rby.dart';

part 'replies_provider.freezed.dart';

final repliesProvider =
    StateNotifierProvider.autoDispose.family<RepliesNotifier, RepliesState, BlueskyPostData>(
  (ref, tweet) => RepliesNotifier(
    findPostReplies: ref.watch(findPostRepliesProvider),
    tweet: tweet,
  ),
  name: 'RepliesProvider',
);

class RepliesNotifier extends StateNotifier<RepliesState> with LoggerMixin {
  RepliesNotifier({
    required FindPostReplies findPostReplies,
    required BlueskyPostData tweet,
  })  : _findPostReplies = findPostReplies,
        _tweet = tweet,
        super(const RepliesState.loading(parent: null)) {
    load();
  }

  final FindPostReplies _findPostReplies;
  final BlueskyPostData _tweet;
  String? _cursor;
  bool _hasMore = true;

  @override
  final log = Logger('RepliesNotifier');

  Future<void> load() async {
    log.fine('loading replies for ${_tweet.id}');

    // Keep the parent in loading state if we have it
    final currentParent = state.parent;
    state = RepliesState.loading(parent: currentParent);

    try {
      // First get the parent post if this is a reply
      BlueskyPostData? parent;
      if (_tweet.parentPostId != null) {
        parent = await _findPostReplies.findParentPost(_tweet);
      }

      // Then get the first page of replies
      final result = await _findPostReplies.findRepliesWithPagination(_tweet);
      _cursor = result.cursor;
      _hasMore = result.hasMore;

      if (result.replies.isNotEmpty) {
        log.fine('found ${result.replies.length} replies');
        state = RepliesState.data(
          replies: result.replies.toBuiltList(),
          parent: parent,
          hasMore: _hasMore,
        );
      } else {
        log.fine('no replies found');
        state = RepliesState.noData(parent: parent);
      }
    } catch (e, st) {
      log.warning('error loading replies', e, st);
      state = const RepliesState.error();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;

    final currentState = state;
    if (!currentState.maybeMap(
      data: (_) => true,
      orElse: () => false,
    )) {
      return;
    }

    try {
      final result = await _findPostReplies.findRepliesWithPagination(
        _tweet,
        cursor: _cursor,
      );

      _cursor = result.cursor;
      _hasMore = result.hasMore;

      if (result.replies.isNotEmpty) {
        state = currentState.maybeMap(
          data: (data) => RepliesState.data(
            replies: (data.replies.toList()..addAll(result.replies)).toBuiltList(),
            parent: data.parent,
            hasMore: _hasMore,
          ),
          orElse: () => currentState,
        );
      }
    } catch (e, st) {
      log.warning('error loading more replies', e, st);
      // Don't update state on error, keep existing replies
    }
  }
}

@freezed
class RepliesState with _$RepliesState {
  const factory RepliesState.loading({
    BlueskyPostData? parent,
  }) = _Loading;

  const factory RepliesState.data({
    required BuiltList<BlueskyPostData> replies,
    BlueskyPostData? parent,
    required bool hasMore,
  }) = _Data;

  const factory RepliesState.noData({
    BlueskyPostData? parent,
  }) = _NoData;

  const factory RepliesState.error({
    BlueskyPostData? parent,
  }) = _Error;
}

extension RepliesStateExtension on RepliesState {
  BlueskyPostData? get parent => mapOrNull<BlueskyPostData?>(
        data: (value) => value.parent,
        noData: (value) => value.parent,
        error: (value) => value.parent,
        loading: (value) => value.parent,
      );

  BuiltList<BlueskyPostData> get replies => maybeMap(
        data: (value) => value.replies,
        orElse: BuiltList.new,
      );

  bool get hasMore => maybeMap(
        data: (value) => value.hasMore,
        orElse: () => false,
      );
}
