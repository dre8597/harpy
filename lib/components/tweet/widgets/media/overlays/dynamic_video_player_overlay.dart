import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/video_player/base_video_player_overlay.dart';
import 'package:rby/rby.dart';

/// Overlay for video players where the UI elements automatically hide to avoid
/// obscuring the content.
///
/// Used for fullscreen videos.
class DynamicVideoPlayerOverlay extends StatelessWidget {
  const DynamicVideoPlayerOverlay({
    required this.child,
    required this.tweet,
    required this.notifier,
    required this.data,
    required this.media,
    required this.delegates,
    this.mediaData,
    this.isFullscreen = false,
  });

  final Widget child;
  final BlueskyPostData tweet;
  final VideoPlayerNotifier notifier;
  final VideoPlayerStateData data;
  final BlueskyMediaData media;
  final TweetDelegates delegates;
  final VideoMediaData? mediaData;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    return BaseVideoPlayerOverlay(
      tweet: tweet,
      notifier: notifier,
      data: data,
      style: OverlayStyle.dynamic,
      media: media,
      delegates: delegates,
      mediaData: mediaData,
      child: child,
    );
  }
}
