import 'package:flutter/material.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/video_player/base_video_player_overlay.dart';
import 'package:rby/rby.dart';

/// Overlay for video players that builds compact actions and icons.
///
/// Used for videos in the media timeline.
class SmallVideoPlayerOverlay extends StatelessWidget {
  const SmallVideoPlayerOverlay({
    required this.child,
    required this.tweet,
    required this.notifier,
    required this.data,
    required this.media,
    required this.delegates,
    this.mediaData,
    this.onVideoTap,
    this.onVideoLongPress,
  });

  final Widget child;
  final BlueskyPostData tweet;
  final VideoPlayerNotifier notifier;
  final VideoPlayerStateData data;
  final BlueskyMediaData media;
  final TweetDelegates delegates;
  final VideoMediaData? mediaData;
  final VoidCallback? onVideoTap;
  final VoidCallback? onVideoLongPress;

  @override
  Widget build(BuildContext context) {
    return BaseVideoPlayerOverlay(
      tweet: tweet,
      notifier: notifier,
      data: data,
      style: OverlayStyle.compact,
      media: media,
      delegates: delegates,
      mediaData: mediaData,
      onVideoTap: onVideoTap,
      onVideoLongPress: onVideoLongPress,
      child: child,
    );
  }
}
