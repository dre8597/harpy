import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

class TweetCardMedia extends ConsumerWidget {
  const TweetCardMedia({
    required this.tweet,
    required this.delegates,
    this.index,
  });

  final BlueskyPostData tweet;
  final TweetDelegates delegates;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final media = tweet.media?.single;

    Widget child;

    void onMediaLongPress(BlueskyMediaData? media) {
      if (media == null) return;
      showMediaActionsBottomSheet(
        ref,
        media: media,
        delegates: delegates,
      );
    }

    if (media == null) {
      return const SizedBox();
    }

    switch (media.type) {
      case MediaType.image:
        child = TweetImages(
          tweet: tweet,
          delegates: delegates,
          tweetIndex: index,
          onImageLongPress: (index) => onMediaLongPress(media),
        );
      case MediaType.gif:
        final heroTag = 'tweet${mediaHeroTag(
          context,
          tweet: tweet,
          media: media,
          index: index,
        )}';

        child = TweetGif(
          tweet: tweet,
          heroTag: heroTag,
          onGifTap: () => Navigator.of(context).push<void>(
            HeroDialogRoute(
              builder: (_) => MediaGalleryOverlay(
                tweet: tweet,
                media: media,
                delegates: delegates,
                child: TweetGif(tweet: tweet, heroTag: heroTag),
              ),
            ),
          ),
          onGifLongPress: () => onMediaLongPress(media),
        );
      case MediaType.video:
        final heroTag = 'tweet${mediaHeroTag(
          context,
          tweet: tweet,
          media: media,
          index: index,
        )}';

        child = TweetVideo(
          tweet: tweet,
          heroTag: heroTag,
          onVideoLongPress: () => onMediaLongPress(media),
          overlayBuilder: (data, notifier, child) => StaticVideoPlayerOverlay(
            tweet: tweet,
            data: data,
            notifier: notifier,
            onVideoTap: () => Navigator.of(context).push<void>(
              HeroDialogRoute(
                builder: (_) => MediaGalleryOverlay(
                  tweet: tweet,
                  media: media,
                  delegates: delegates,
                  child: TweetGalleryVideo(tweet: tweet, heroTag: heroTag),
                ),
              ),
            ),
            onVideoLongPress: () => onMediaLongPress(media),
            child: child,
          ),
        );
    }

    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: theme.shape.borderRadius,
      child: SensitiveMediaOverlay(
        tweet: tweet,
        child: _MediaConstrainedHeight(
          tweet: tweet,
          child: child,
        ),
      ),
    );
  }
}

class _MediaConstrainedHeight extends ConsumerWidget {
  const _MediaConstrainedHeight({
    required this.tweet,
    required this.child,
  });

  final BlueskyPostData tweet;
  final Widget child;

  Widget _constrainedAspectRatio(double aspectRatio) {
    return LayoutBuilder(
      builder: (_, constraints) => aspectRatio > constraints.biggest.aspectRatio
          ? AspectRatio(
              aspectRatio: aspectRatio,
              child: child,
            )
          : AspectRatio(
              aspectRatio: min(constraints.biggest.aspectRatio, 16 / 9),
              child: child,
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final mediaPreferences = ref.watch(mediaPreferencesProvider);
    final media = tweet.media?.single;

    if (media == null) {
      return const SizedBox();
    }

    final aspectRatio = media.aspectRatioDouble;
    final isSingleImage =
        tweet.media?.length == 1 && media.type == MediaType.image;

    switch (media.type) {
      case MediaType.image:
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * .8),
          child: isSingleImage && !mediaPreferences.cropImage
              ? _constrainedAspectRatio(
                  mediaPreferences.cropImage
                      ? min(aspectRatio, 16 / 9)
                      : aspectRatio,
                )
              : _constrainedAspectRatio(16 / 9),
        );

      case MediaType.gif:
      case MediaType.video:
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * .8),
          child: _constrainedAspectRatio(aspectRatio),
        );
    }
  }
}

/// Creates a hero tag for the media which is unique for each [RbyPage].
///
/// Note: One tweet can have the same media data (e.g. a retweet and the
///       original tweet). To avoid having the same hero tag we need to
///       differentiate based on the tweet as well.
String mediaHeroTag(
  BuildContext context, {
  required BlueskyPostData tweet,
  required BlueskyMediaData media,
  int? index,
}) {
  final routeSettings = ModalRoute.of(context)?.settings;

  final buffer = StringBuffer('${tweet.hashCode}${media.hashCode}');

  if (routeSettings is RbyPage && routeSettings.key is ValueKey) {
    final key = routeSettings.key! as ValueKey;
    // key = current route path
    buffer.write('${key.value}');
  }

  if (index != null) buffer.write('$index');

  return '$buffer';
}
