import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/find_post_replies.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

/// A widget that shows a preview of the parent post that this post is replying to.
class TweetCardParentPreview extends ConsumerWidget {
  const TweetCardParentPreview({
    required this.tweet,
    required this.style,
    super.key,
  });

  final BlueskyPostData tweet;
  final TweetCardElementStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repliesProvider = ref.watch(findPostRepliesProvider);

    return FutureBuilder<BlueskyPostData?>(
      future: repliesProvider.findParentPost(tweet),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final parent = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: theme.spacing.edgeInsets.copyWith(
                top: 0,
                bottom: theme.spacing.small,
              ),
              child: Row(
                children: [
                  Text(
                    'Replying to ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    '@${parent.handle}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TweetCard(
                  tweet: parent,
                  config: kDefaultTweetCardQuoteConfig.copyWith(
                    elements: {
                      TweetCardElement.avatar,
                      TweetCardElement.name,
                      TweetCardElement.handle,
                      TweetCardElement.text,
                      TweetCardElement.media,
                    },
                    styles: {
                      ...kDefaultTweetCardQuoteConfig.styles,
                      TweetCardElement.media:
                          const TweetCardElementStyle(sizeDelta: -2),
                    },
                  ),
                  createDelegates: (tweet, notifier) =>
                      defaultTweetDelegates(tweet, notifier).copyWith(
                    onShowTweet: null,
                    onComposeQuote: null,
                    onComposeReply: null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
