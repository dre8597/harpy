import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

final _currentMediaIndexProvider =
    StateProvider.autoDispose.family<int, String>(
  (ref, tweetId) => 0,
);

class TweetCardMedia extends ConsumerWidget {
  const TweetCardMedia({
    required this.tweet,
    required this.delegates,
    this.index,
  });

  final BlueskyPostData tweet;
  final TweetDelegates delegates;
  final int? index;

  Widget _buildMediaItem(
    BuildContext context,
    BlueskyMediaData media,
    int mediaIndex,
    void Function(BlueskyMediaData?) onMediaLongPress,
  ) {
    final heroTag = 'tweet${mediaHeroTag(
      context,
      tweet: tweet,
      media: media,
      index: index,
    )}';

    switch (media.type) {
      case MediaType.image:
        return TweetImages(
          tweet: tweet,
          delegates: delegates,
          tweetIndex: index,
          onImageLongPress: (index) => onMediaLongPress(media),
        );
      case MediaType.gif:
        return TweetGif(
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
        final videoData = media.toVideoMediaData();
        if (videoData == null) return const SizedBox();

        return TweetVideo(
          tweet: tweet,
          mediaData: videoData,
          heroTag: heroTag,
          onVideoLongPress: () => onMediaLongPress(media),
          overlayBuilder: (data, notifier, child) => StaticVideoPlayerOverlay(
            tweet: tweet,
            data: data,
            notifier: notifier,
            media: media,
            delegates: delegates,
            mediaData: videoData,
            onVideoTap: () => Navigator.of(context).push<void>(
              HeroDialogRoute(
                builder: (_) => MediaGalleryOverlay(
                  tweet: tweet,
                  media: media,
                  delegates: delegates,
                  child: TweetGalleryVideo(
                    tweet: tweet,
                    media: media,
                    delegates: delegates,
                    mediaData: videoData,
                    heroTag: heroTag,
                  ),
                ),
              ),
            ),
            onVideoLongPress: () => onMediaLongPress(media),
            child: child,
          ),
        );
    }
  }

  Widget _buildPageIndicator(int itemCount, int currentIndex, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaItems = tweet.media;
    final currentIndex =
        ref.watch(_currentMediaIndexProvider(tweet.uri.toString()));

    Widget buildGridLayout(
      List<BlueskyMediaData> mediaItems,
      void Function(BlueskyMediaData?) onMediaLongPress,
    ) {
      final itemCount = mediaItems.length;

      if (itemCount <= 2) {
        return Row(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: _buildMediaItem(
                  context,
                  mediaItems[i],
                  i,
                  onMediaLongPress,
                ),
              ),
            ],
          ],
        );
      } else {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: [
            for (var i = 0; i < min(4, itemCount); i++)
              _buildMediaItem(context, mediaItems[i], i, onMediaLongPress),
          ],
        );
      }
    }

    void onMediaLongPress(BlueskyMediaData? media) {
      if (media == null) return;
      showMediaActionsBottomSheet(
        ref,
        media: media,
        delegates: delegates,
      );
    }

    if (mediaItems == null || mediaItems.isEmpty) {
      return const SizedBox();
    }

    Widget mediaWidget;
    if (mediaItems.length == 1) {
      mediaWidget =
          _buildMediaItem(context, mediaItems.first, 0, onMediaLongPress);
    } else if (mediaItems.length <= 4) {
      mediaWidget = buildGridLayout(mediaItems, onMediaLongPress);
    } else {
      mediaWidget = CarouselSlider.builder(
        itemCount: mediaItems.length,
        itemBuilder: (context, index, realIndex) => _buildMediaItem(
          context,
          mediaItems[index],
          index,
          onMediaLongPress,
        ),
        options: CarouselOptions(
          viewportFraction: 1,
          enableInfiniteScroll: false,
          height: MediaQuery.of(context).size.height * 0.4,
          onPageChanged: (index, _) => ref
              .read(_currentMediaIndexProvider(tweet.uri.toString()).notifier)
              .state = index,
        ),
      );
    }

    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: theme.shape.borderRadius,
      child: SensitiveMediaOverlay(
        tweet: tweet,
        child: Column(
          children: [
            _MediaConstrainedHeight(
              tweet: tweet,
              child: mediaWidget,
            ),
            if (mediaItems.length > 4) ...[
              const SizedBox(height: 8),
              _buildPageIndicator(mediaItems.length, currentIndex, theme),
              const SizedBox(height: 8),
            ],
          ],
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
    final media = tweet.media?.firstOrNull;

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
