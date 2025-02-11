import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A widget that displays a thread view for a post.
/// Handles lazy loading of parent posts and replies.
class ThreadView extends HookConsumerWidget {
  const ThreadView({
    required this.post,
    this.showParent = true,
    this.config,
    this.onParentLoaded,
    super.key,
  });

  final BlueskyPostData post;
  final bool showParent;
  final TweetCardConfig? config;
  final void Function(BlueskyPostData parent)? onParentLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load parent post when thread view is opened and showParent is true
    useEffect(
      () {
        if (showParent && post.parentPostId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final notifier = ref.read(userTimelineProvider(post.authorDid).notifier);
            await notifier.loadParentPost(post.uri.toString());

            // Notify parent loaded if callback provided
            if (onParentLoaded != null && post.parentPost != null) {
              onParentLoaded!(post.parentPost!);
            }
          });
        }
        return null;
      },
      [post.uri],
    );

    // Watch for parent post updates
    final parentPost = post.parentPost;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showParent && post.parentPostId != null) ...[
          if (parentPost != null)
            _ThreadPostTile(
              post: parentPost,
              isParent: true,
              config: config,
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
          const Divider(),
        ],
        _ThreadPostTile(
          post: post,
          isHighlighted: true,
          config: config,
        ),
      ],
    );
  }
}

class _ThreadPostTile extends StatelessWidget {
  const _ThreadPostTile({
    required this.post,
    this.isParent = false,
    this.isHighlighted = false,
    this.config,
  });

  final BlueskyPostData post;
  final bool isParent;
  final bool isHighlighted;
  final TweetCardConfig? config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tweetConfig = config?.copyWith(
          actions: isParent ? const {} : config?.actions,
        ) ??
        kDefaultTweetCardConfig.copyWith(
          actions: isParent
              ? const {}
              : const {
                  TweetCardActionElement.retweet,
                  TweetCardActionElement.favorite,
                  TweetCardActionElement.showReplies,
                  TweetCardActionElement.translate,
                },
        );

    return Container(
      padding: const EdgeInsets.all(16),
      color: isHighlighted ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
      child: TweetCard(
        tweet: post,
        config: tweetConfig,
      ),
    );
  }
}
