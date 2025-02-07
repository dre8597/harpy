import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/media/reels_video_feed.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

/// Builds a [SliverWaterfallFlow] for the media of the [MediaTimeline].
class MediaTimelineMediaList extends ConsumerWidget {
  const MediaTimelineMediaList({
    required this.entries,
    required this.provider,
  });

  final BuiltList<MediaTimelineEntry> entries;
  final AutoDisposeStateNotifierProvider<TimelineNotifier, TimelineState>
      provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(layoutPreferencesProvider);
    final media = ref.watch(mediaPreferencesProvider);

    if (media.useReelsVideoMode && !layout.mediaTiled) {
      // Filter only video entries
      final videoEntries = entries
          .where(
            (entry) => entry.media.type == MediaType.video,
          )
          .toList();

      if (videoEntries.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox());
      }

      return SliverFillRemaining(
        child: ReelsVideoFeed(
          entries: videoEntries,
          onRefresh: () async {
            final timelineNotifier = ref.read(provider.notifier);
            await timelineNotifier.load(clearPrevious: true);
          },
        ),
      );
    }

    return SliverWaterfallFlow(
      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.mediaTiled ? 2 : 1,
        mainAxisSpacing: theme.spacing.small,
        crossAxisSpacing: theme.spacing.small,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _MediaEntryItem(
          entries: entries,
          index: index,
        ),
        childCount: entries.length,
      ),
    );
  }
}

class _MediaEntryItem extends ConsumerStatefulWidget {
  const _MediaEntryItem({
    required this.entries,
    required this.index,
  });

  final BuiltList<MediaTimelineEntry> entries;
  final int index;

  @override
  _MediaEntryItemState createState() => _MediaEntryItemState();
}

class _MediaEntryItemState extends ConsumerState<_MediaEntryItem> {
  @override
  void initState() {
    super.initState();

    final entry = widget.entries[widget.index];

    final provider = tweetProvider(
      entry.tweet.id,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(provider.notifier).initialize(entry.tweet);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entries[widget.index];
    final provider = tweetProvider(entry.tweet.id);

    var tweet = ref.watch(provider) ?? entry.tweet;
    var tweetNotifier = ref.watch(provider.notifier);

    final delegates = defaultTweetDelegates(tweet, tweetNotifier);

    return MediaTimelineMedia(
      entry: entry,
      delegates: delegates,
      onTap: () => Navigator.of(context).push<void>(
        HeroDialogRoute(
          builder: (_) => MediaGallery(
            initialIndex: widget.index,
            itemCount: widget.entries.length,
            actions: _mediaTimelineOverlayActions,
            builder: (index) {
              final provider = tweetProvider(
                widget.entries[index].tweet.id,
              );
              tweet = ref.read(provider) ?? widget.entries[index].tweet;

              // We need to initialize the tweet in case it's not yet
              // initialized. This can happen if the user scroll the gallery and
              // reaches uninitialized tweets.
              SchedulerBinding.instance.addPostFrameCallback((_) {
                tweetNotifier = ref.read(provider.notifier)
                  ..initialize(widget.entries[index].tweet);
              });

              final delegates = defaultTweetDelegates(
                tweet,
                tweetNotifier,
              );

              return MediaGalleryEntry(
                tweet: tweet,
                delegates: delegates,
                media: widget.entries[index].media,
                builder: (_) {
                  final heroTag = 'media${mediaHeroTag(
                    context,
                    tweet: tweet,
                    media: widget.entries[index].media,
                  )}';

                  switch (widget.entries[index].media.type) {
                    case MediaType.image:
                      return TweetGalleryImage(
                        media: widget.entries[index].media,
                        heroTag: heroTag,
                        borderRadius: theme.shape.borderRadius,
                      );
                    case MediaType.gif:
                      return TweetGif(tweet: tweet, heroTag: heroTag);
                    case MediaType.video:
                      return TweetGalleryVideo(
                        tweet: tweet,
                        media: widget.entries[index].media,
                        delegates: delegates,
                        heroTag: heroTag,
                      );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

const _mediaTimelineOverlayActions = {
  MediaOverlayActions.retweet,
  MediaOverlayActions.favorite,
  MediaOverlayActions.spacer,
  MediaOverlayActions.show,
  MediaOverlayActions.actionsButton,
};
