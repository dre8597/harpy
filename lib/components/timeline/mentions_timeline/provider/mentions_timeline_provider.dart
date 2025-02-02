import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

final mentionsTimelineProvider =
    StateNotifierProvider.autoDispose<MentionsTimelineNotifier, TimelineState<bool>>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 15));

    return MentionsTimelineNotifier(
      ref: ref,
    );
  },
  name: 'MentionsTimelineProvider',
);

class MentionsTimelineNotifier extends TimelineNotifier<bool> {
  MentionsTimelineNotifier({
    required super.ref,
  });

  @override
  final log = Logger('MentionsTimelineNotifier');

  @override
  TimelineFilter? currentFilter() => null;

  @override
  Future<TimelineResponse> request({String? cursor}) async {
    final feed = await blueskyApi.notification.listNotifications(
      cursor: cursor,
      limit: 50,
    );

    final posts = feed.data.notifications
        .where(
          (notification) => notification.reason == bsky.NotificationReason.mention,
        )
        .map(
          (notification) => BlueskyPostData(
            id: notification.cid,
            uri: notification.uri,
            text: notification.reason.value,
            author: notification.author.displayName ?? '',
            handle: notification.author.handle,
            createdAt: notification.indexedAt,
            authorDid: notification.author.did,
            authorAvatar: notification.author.avatar ?? '',
          ),
        )
        .toList();

    return TimelineResponse(posts, feed.data.cursor);
  }

  @override
  bool? buildCustomData(BuiltList<BlueskyPostData> posts) {
    if (posts.isEmpty) return false;

    final newId = int.tryParse(posts.first.id) ?? 0;
    final lastId = ref.read(tweetVisibilityPreferencesProvider).lastViewedMention;

    return lastId < newId;
  }

  void updateViewedMentions() {
    log.fine('updating viewed mentions');

    final currentState = state;

    if (currentState is TimelineStateData<bool> && currentState.tweets.isNotEmpty) {
      final id = int.tryParse(currentState.tweets.first.id) ?? 0;
      ref.read(tweetVisibilityPreferencesProvider).lastViewedMention = id;
      state = currentState.copyWith(customData: false);
    }
  }
}

extension MentionsTimelineStateExtension on TimelineState<bool> {
  bool get hasNewMentions => maybeMap(
        data: (data) => data.customData ?? false,
        orElse: () => false,
      );
}
