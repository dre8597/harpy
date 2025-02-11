import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/thread/thread_view.dart';
import 'package:harpy/components/tweet/model/tweet_card_config.dart';
import 'package:rby/theme/spacing_theme.dart';

/// The content widget for the tweet detail page.
/// Uses the optimized ThreadView for showing the tweet and its parent.
class TweetDetailContent extends ConsumerWidget {
  const TweetDetailContent({
    required this.tweet,
    super.key,
  });

  final BlueskyPostData tweet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesState = ref.watch(repliesProvider(tweet));
    final repliesNotifier = ref.watch(repliesProvider(tweet).notifier);
    final theme = Theme.of(context);

    return ScrollDirectionListener(
      child: ScrollToTop(
        child: TweetList(
          repliesState.replies.toList(),
          beginSlivers: [
            const HarpySliverAppBar(title: Text('tweet')),
            // Use ThreadView in a sliver for the main tweet content
            SliverPadding(
              padding: theme.spacing.edgeInsets,
              sliver: SliverToBoxAdapter(
                child: ThreadView(
                  post: tweet,
                  config: _detailTweetCardConfig,
                  onParentLoaded: (parent) {
                    // Update replies state with parent if needed
                    if (repliesState.parent == null) {
                      repliesNotifier.setParent(parent);
                    }
                  },
                ),
              ),
            ),
            ...?repliesState.mapOrNull(
              loading: (_) => const [
                TweetListInfoMessageLoadingShimmer(),
                TweetListLoadingSliver(),
              ],
              data: (_) => const [
                SliverToBoxAdapter(
                  child: TweetListInfoMessage(
                    icon: Icon(CupertinoIcons.reply_all),
                    text: Text('replies'),
                  ),
                ),
              ],
              noData: (_) => const [
                SliverFillInfoMessage(
                  secondaryMessage: Text('no replies exist'),
                ),
              ],
              error: (_) => [
                SliverFillLoadingError(
                  message: const Text('error requesting replies'),
                  onRetry: repliesNotifier.load,
                ),
              ],
            ),
          ],
          onLayoutFinished: (firstIndex, lastIndex) {
            if (repliesState.hasMore && lastIndex >= repliesState.replies.length - 1) {
              repliesNotifier.loadMore();
            }
          },
          endSlivers: repliesState.maybeMap(
            data: (data) => data.hasMore
                ? [
                    SliverPadding(
                      padding: theme.spacing.edgeInsets,
                      sliver: const SliverToBoxAdapter(
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  ]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
        ),
      ),
    );
  }
}

/// Configuration for tweet cards in the detail view
final _detailTweetCardConfig = kDefaultTweetCardConfig.copyWith(
  elements: {
    ...kDefaultTweetCardConfig.elements,
    TweetCardElement.details,
  },
  actions: {
    TweetCardActionElement.retweet,
    TweetCardActionElement.favorite,
    TweetCardActionElement.reply,
    TweetCardActionElement.spacer,
    TweetCardActionElement.translate,
  },
);
