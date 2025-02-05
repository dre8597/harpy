import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

const _qualityNames = ['best', 'normal', 'small'];

/// Creates video player arguments from video media data.
VideoPlayerArguments createVideoArguments(VideoMediaData mediaData) {
  return VideoPlayerArguments(
    urls: BuiltMap({
      for (var i = 0; i < min(3, mediaData.variants.length); i++)
        _qualityNames[i]: mediaData.variants[i],
    }),
    loop: false,
    isVideo: true,
  );
}

/// Navigate to the video in fullscreen mode, using the MediaGalleryOverlay
/// to provide consistent UI and interactions.
void navigateToVideo(
  BuildContext context, {
  required BlueskyPostData tweet,
  required BlueskyMediaData media,
  required TweetDelegates delegates,
  VideoMediaData? mediaData,
}) {
  Navigator.of(context).push<void>(
    HeroDialogRoute(
      builder: (_) => MediaGalleryOverlay(
        tweet: tweet,
        media: media,
        delegates: delegates,
        child: TweetGalleryVideo(
          tweet: tweet,
          media: media,
          delegates: delegates,
          mediaData: mediaData,
          heroTag: '${tweet.id}_video',
        ),
      ),
    ),
  );
}
