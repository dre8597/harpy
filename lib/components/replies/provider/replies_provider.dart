import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:logging/logging.dart';
import 'package:rby/rby.dart';

part 'replies_provider.freezed.dart';

final repliesProvider =
    StateNotifierProvider.autoDispose.family<RepliesNotifier, RepliesState, BlueskyPostData>(
  (ref, post) => RepliesNotifier(
    ref: ref,
    post: post,
  ),
  name: 'RepliesProvider',
);

class RepliesNotifier extends StateNotifier<RepliesState> with LoggerMixin {
  RepliesNotifier({
    required Ref ref,
    required BlueskyPostData post,
  })  : _ref = ref,
        _post = post,
        super(const RepliesState.loading()) {
    load();
  }

  final Ref _ref;
  final BlueskyPostData _post;

  @override
  final log = Logger('RepliesNotifier');

  final bool _hasMore = true;

  Future<void> load() async {
    final currentParent = state.parent;
    state = RepliesState.loading(parent: currentParent);

    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      final response = await blueskyApi.feed.getPostThread(
        uri: _post.uri,
        parentHeight: 0,
        depth: 1,
      );

      if (!mounted) return;

      if (response.data.thread is bsky.UPostThreadViewRecord) {
        final threadView = (response.data.thread as bsky.UPostThreadViewRecord).data;

        final replies = threadView.replies
            ?.map(
              (reply) => reply.map(
                record: (record) => BlueskyPostData.fromFeedView(
                  bsky.FeedView(post: record.data.post),
                ),
                notFound: (_) => null,
                blocked: (_) => null,
                unknown: (_) => null,
              ),
            )
            .whereType<BlueskyPostData>()
            .toList();

        if (replies == null || replies.isEmpty) {
          state = RepliesState.noData(parent: currentParent);
        } else {
          state = RepliesState.data(
            replies: BuiltList<BlueskyPostData>.of(replies),
            hasMore: false,
            parent: currentParent,
          );
        }
      } else {
        state = RepliesState.noData(parent: currentParent);
      }
    } catch (e, stack) {
      log.severe('error loading replies', e, stack);
      state = RepliesState.error(error: e, parent: state.parent);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;

    final currentState = state;
    if (currentState is! _Data) return;

    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      final response = await blueskyApi.feed.getPostThread(
        uri: _post.uri,
        parentHeight: 0,
        depth: 1,
      );

      if (!mounted) return;

      if (response.data.thread is bsky.UPostThreadViewRecord) {
        final threadView = (response.data.thread as bsky.UPostThreadViewRecord).data;

        final newReplies = threadView.replies
            ?.map(
              (reply) => reply.map(
                record: (record) => BlueskyPostData.fromFeedView(
                  bsky.FeedView(post: record.data.post),
                ),
                notFound: (_) => null,
                blocked: (_) => null,
                unknown: (_) => null,
              ),
            )
            .whereType<BlueskyPostData>()
            .toList();

        if (newReplies != null && newReplies.isNotEmpty) {
          state = RepliesState.data(
            replies: currentState.replies.rebuild((b) => b.addAll(newReplies)),
            hasMore: false,
            parent: currentState.parent,
          );
        }
      }
    } catch (e, stack) {
      log.severe('error loading more replies', e, stack);
    }
  }

  /// Updates the parent post in the replies state.
  /// This is called when a parent post is loaded by the ThreadView.
  void setParent(BlueskyPostData parent) {
    state = state.map(
      loading: (s) => RepliesState.loading(parent: parent),
      data: (s) => RepliesState.data(
        replies: s.replies,
        hasMore: s.hasMore,
        parent: parent,
      ),
      noData: (s) => RepliesState.noData(parent: parent),
      error: (_) => RepliesState.error(parent: parent),
    );
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
    Object? error,
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
