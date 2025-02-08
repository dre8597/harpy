import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/bluesky_text.dart';
import 'package:harpy/core/core.dart';

class TweetCardQuote extends ConsumerStatefulWidget {
  const TweetCardQuote({
    required this.post,
    this.index,
    super.key,
  });

  final BlueskyPostData post;
  final int? index;

  @override
  ConsumerState<TweetCardQuote> createState() => _TweetCardQuoteState();
}

class _TweetCardQuoteState extends ConsumerState<TweetCardQuote> {
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
  void initState() {
    super.initState();

    if (widget.post.repostOf != null) {
      final provider = tweetProvider(widget.post.repostOf!.id);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Initialize with a non-null repost
          final repost = widget.post.repostOf;
          if (repost != null) {
            ref.read(provider.notifier).initialize(repost);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final router = ref.watch(routerProvider);
    final launcher = ref.watch(launcherProvider);

    final repost = widget.post.repostOf;
    if (repost == null) return const SizedBox.shrink();

    final entities = _buildEntities(repost);
    final provider = tweetProvider(repost.id);
    final notifier = ref.watch(provider.notifier);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(repost.authorAvatar),
                ),
                const SizedBox(width: 8),
                Text(
                  repost.author,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${repost.handle}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BlueskyText(
              repost.text,
              entities: entities,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
              entityStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
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
            if (repost.media != null && repost.media!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TweetCardMedia(
                tweet: repost,
                delegates: defaultTweetDelegates(repost, notifier),
                index: widget.index,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
