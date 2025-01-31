import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/find_post_replies.dart';
import 'package:logging/logging.dart';
import 'package:rby/rby.dart';

part 'replies_provider.freezed.dart';

final repliesProvider = StateNotifierProvider.autoDispose
    .family<RepliesNotifier, RepliesState, BlueskyPostData>(
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
        super(const RepliesState.loading()) {
    load();
  }

  final FindPostReplies _findPostReplies;
  final BlueskyPostData _tweet;
  @override
  final log = Logger('RepliesNotifier');

  Future<void> load() async {
    log.fine('loading replies for ${_tweet.id}');

    state = const RepliesState.loading();

    try {
      final thread = await _findPostReplies.findThread(_tweet);

      // The first post in the thread is the parent (if it exists)
      BlueskyPostData? parent;
      if (thread.isNotEmpty && thread.first.id != _tweet.id) {
        parent = thread.first;
      }

      // Get replies (all posts after the original tweet)
      final replies = <BlueskyPostData>[];
      var foundOriginal = false;
      for (final post in thread) {
        if (foundOriginal) {
          replies.add(post);
        } else if (post.id == _tweet.id) {
          foundOriginal = true;
        }
      }

      if (replies.isNotEmpty) {
        log.fine('found ${replies.length} replies');
        state = RepliesState.data(
          replies: replies.toBuiltList(),
          parent: parent,
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
}

@freezed
class RepliesState with _$RepliesState {
  const factory RepliesState.loading() = _Loading;

  const factory RepliesState.data({
    required BuiltList<BlueskyPostData> replies,

    /// When the tweet is a reply itself, the [parent] will contain the parent
    /// reply chain.
    final BlueskyPostData? parent,
  }) = _Data;

  const factory RepliesState.noData({final BlueskyPostData? parent}) = _NoData;
  const factory RepliesState.error({final BlueskyPostData? parent}) = _Error;
}

extension RepliesStateExtension on RepliesState {
  BlueskyPostData? get parent => mapOrNull<BlueskyPostData?>(
        data: (value) => value.parent,
        noData: (value) => value.parent,
        error: (value) => value.parent,
      );

  BuiltList<BlueskyPostData> get replies => maybeMap(
        data: (value) => value.replies,
        orElse: BuiltList.new,
      );
}
