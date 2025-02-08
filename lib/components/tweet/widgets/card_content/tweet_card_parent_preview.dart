import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:harpy/api/bluesky/find_post_replies.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/bluesky_text.dart';
import 'package:harpy/core/core.dart';
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

  List<BlueskyTextEntity> _buildEntities(BlueskyPostData post) {
    final entities = <BlueskyTextEntity>[];

    // Add mentions
    if (post.mentions != null) {
      for (final mention in post.mentions!) {
        final index = post.text.indexOf('@$mention');
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'mention',
              value: mention,
              start: index,
              end: index + mention.length + 1,
            ),
          );
        }
      }
    }

    // Add tags
    if (post.tags != null) {
      for (final tag in post.tags!) {
        final index = post.text.indexOf('#$tag');
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'hashtag',
              value: tag,
              start: index,
              end: index + tag.length + 1,
            ),
          );
        }
      }
    }

    // Add external URLs
    if (post.externalUrls != null) {
      for (final url in post.externalUrls!) {
        final index = post.text.indexOf(url);
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'url',
              value: url,
              start: index,
              end: index + url.length,
            ),
          );
        }
      }
    }

    return entities;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repliesProvider = ref.watch(findPostRepliesProvider);
    final router = ref.watch(routerProvider);
    final launcher = ref.watch(launcherProvider);

    return FutureBuilder<BlueskyPostData?>(
      future: repliesProvider.findParentPost(tweet),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final parent = snapshot.data!;
        final entities = _buildEntities(parent);

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
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
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
            BlueskyText(
              parent.text,
              entities: entities,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
              entityStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              onMentionTap: (mention) {
                router.push('/user/$mention');
              },
              onHashtagTap: (hashtag) {
                router.push(
                  '/harpy_search/tweets',
                  extra: {
                    'hashTag': hashtag,
                  },
                );
              },
              onUrlTap: launcher,
            ),
          ],
        );
      },
    );
  }
}
