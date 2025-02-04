import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';
import 'package:video_player/video_player.dart';

const _qualityNames = ['best', 'normal', 'small'];

typedef OverlayBuilder = Widget Function(
  VideoPlayerStateData data,
  VideoPlayerNotifier notifier,
  Widget child,
);

VideoPlayerArguments _videoArguments(VideoMediaData mediaData) {
  return VideoPlayerArguments(
    urls: BuiltMap({
      for (var i = 0; i < min(3, mediaData.variants.length); i++)
        _qualityNames[i]: mediaData.variants[i],
    }),
    loop: false,
    isVideo: true,
  );
}

class TweetVideo extends ConsumerWidget {
  const TweetVideo({
    required this.tweet,
    required this.overlayBuilder,
    required this.heroTag,
    this.placeholderBuilder,
    this.onVideoLongPress,
    this.compact = false,
    this.mediaData,
  });

  final BlueskyPostData tweet;
  final OverlayBuilder overlayBuilder;
  final Object heroTag;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool compact;
  final VoidCallback? onVideoLongPress;
  final VideoMediaData? mediaData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaPreferences = ref.watch(mediaPreferencesProvider);
    final connectivity = ref.watch(connectivityProvider);

    final videoData = mediaData ??
        tweet.media
            ?.firstWhereOrNull(
              (m) => m.type == MediaType.video,
            )
            ?.toVideoMediaData();

    if (videoData == null) {
      return const SizedBox();
    }

    final arguments = _videoArguments(videoData);
    final provider = videoPlayerProvider(arguments);
    final state = ref.watch(provider);
    final notifier = ref.watch(provider.notifier);

    return VisibilityChangeListener(
      detectorKey: ObjectKey(heroTag),
      onVisibilityChanged: (visible) {
        if (visible && mediaPreferences.shouldPreloadVideos(connectivity)) {
          // Start preloading when video becomes visible and allowed by preferences
          notifier.preload();
        }
      },
      child: MediaAutoplay(
        state: state,
        notifier: notifier,
        enableAutoplay: mediaPreferences.shouldAutoplayVideos(connectivity),
        child: Hero(
          tag: heroTag,
          placeholderBuilder: placeholderBuilder,
          flightShuttleBuilder: (
            _,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) =>
              borderRadiusFlightShuttleBuilder(
            theme.shape.borderRadius,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ),
          child: AspectRatio(
            aspectRatio: videoData.aspectRatioDouble,
            child: state.maybeMap(
              data: (data) => overlayBuilder(
                data,
                notifier,
                Stack(
                  children: [
                    OverflowBox(
                      maxHeight: double.infinity,
                      child: AspectRatio(
                        aspectRatio: videoData.aspectRatioDouble,
                        child: VideoPlayer(notifier.controller),
                      ),
                    ),
                    if (data.isBuffering)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              loading: (_) => MediaThumbnail(
                thumbnail: videoData.thumbnail,
                duration: videoData.duration,
                center: MediaThumbnailIcon(
                  icon: const CircularProgressIndicator(),
                  compact: compact,
                ),
              ),
              error: (error) => MediaThumbnail(
                thumbnail: videoData.thumbnail,
                duration: videoData.duration,
                center: MediaThumbnailIcon(
                  icon: const Icon(Icons.error_outline),
                  compact: compact,
                ),
                onTap: notifier.initialize,
                onLongPress: onVideoLongPress,
              ),
              orElse: () => MediaThumbnail(
                thumbnail: videoData.thumbnail,
                duration: videoData.duration,
                center: MediaThumbnailIcon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  compact: compact,
                ),
                onTap: notifier.initialize,
                onLongPress: onVideoLongPress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TweetGalleryVideo extends ConsumerWidget {
  const TweetGalleryVideo({
    required this.tweet,
    required this.heroTag,
    this.onVideoLongPress,
    this.mediaData,
  });

  final BlueskyPostData tweet;
  final Object heroTag;
  final VoidCallback? onVideoLongPress;
  final VideoMediaData? mediaData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TweetVideo(
      tweet: tweet,
      mediaData: mediaData,
      heroTag: heroTag,
      overlayBuilder: (data, notifier, child) => DynamicVideoPlayerOverlay(
        notifier: notifier,
        tweet: tweet,
        data: data,
        child: child,
      ),
    );
  }
}

class TweetFullscreenVideo extends ConsumerStatefulWidget {
  const TweetFullscreenVideo({
    required this.tweet,
    this.mediaData,
  });

  final BlueskyPostData tweet;
  final VideoMediaData? mediaData;

  @override
  ConsumerState<TweetFullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends ConsumerState<TweetFullscreenVideo> {
  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final videoData = widget.mediaData ??
        widget.tweet.media
            ?.firstWhereOrNull(
              (m) => m.type == MediaType.video,
            )
            ?.toVideoMediaData();

    if (videoData == null) {
      return const SizedBox();
    }

    final arguments = _videoArguments(videoData);
    final state = ref.watch(videoPlayerProvider(arguments));
    final notifier = ref.watch(videoPlayerProvider(arguments).notifier);

    final quarterTurns = videoData.aspectRatioDouble > 1
        ? orientation == Orientation.portrait
            ? 1
            : 0
        : orientation == Orientation.portrait
            ? 0
            : 1;

    return Stack(
      children: [
        const ColoredBox(color: Colors.black87),
        GestureDetector(onTap: Navigator.of(context).pop),
        RotatedBox(
          quarterTurns: quarterTurns,
          child: Center(
            child: AspectRatio(
              aspectRatio: videoData.aspectRatioDouble,
              child: state.maybeMap(
                data: (data) => DynamicVideoPlayerOverlay(
                  notifier: notifier,
                  tweet: widget.tweet,
                  data: data,
                  isFullscreen: true,
                  child: VideoPlayer(notifier.controller),
                ),
                loading: (_) => MediaThumbnail(
                  thumbnail: videoData.thumbnail,
                  center: const MediaThumbnailIcon(
                    icon: CircularProgressIndicator(),
                  ),
                ),
                orElse: () => MediaThumbnail(
                  thumbnail: videoData.thumbnail,
                  center: const MediaThumbnailIcon(
                    icon: Icon(Icons.play_arrow_rounded),
                  ),
                  onTap: notifier.initialize,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
