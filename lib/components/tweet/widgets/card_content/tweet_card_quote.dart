import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';

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

    // Early return if no repost
    if (widget.post.repostOf == null) {
      return const SizedBox();
    }

    final provider = tweetProvider(widget.post.repostOf!.id);
    final quotedPost = ref.watch(provider) ?? widget.post.repostOf!;
    final notifier = ref.watch(provider.notifier);

    final delegates = defaultTweetDelegates(quotedPost, notifier);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => delegates.onShowTweet?.call(ref),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TweetCardContent(
            tweet: quotedPost,
            notifier: notifier,
            delegates: delegates,
            outerPadding: 12,
            innerPadding: 6,
            config: kDefaultTweetCardQuoteConfig,
            index: widget.index,
          ),
        ),
      ),
    );
  }
}
