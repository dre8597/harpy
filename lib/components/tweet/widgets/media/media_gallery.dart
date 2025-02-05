import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/media/utils/video_utils.dart';

typedef GalleryEntryBuilder = MediaGalleryEntry? Function(int index);

class MediaGalleryEntry {
  const MediaGalleryEntry({
    required this.tweet,
    required this.delegates,
    required this.media,
    required this.builder,
  });

  final BlueskyPostData tweet;
  final TweetDelegates delegates;
  final BlueskyMediaData media;
  final WidgetBuilder builder;
}

/// Shows multiple tweet media in a [HarpyPhotoGallery].
///
/// * Used by [TweetImages] to showcase all images for a tweet in one gallery.
/// * Used by [MediaTimeline] to show all media entries in a single gallery.
class MediaGallery extends ConsumerStatefulWidget {
  const MediaGallery({
    required this.builder,
    required this.itemCount,
    this.initialIndex = 0,
    this.actions = kDefaultOverlayActions,
  });

  final GalleryEntryBuilder builder;
  final int itemCount;
  final int initialIndex;
  final Set<MediaOverlayActions> actions;

  @override
  ConsumerState<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends ConsumerState<MediaGallery> {
  late int _index;
  final Map<int, bool> _previousMuteStates = {};

  @override
  void initState() {
    super.initState();

    _index = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVideoEntry(_index);
    });
  }

  void _handleVideoEntry(int index) {
    final entry = widget.builder(index);
    if (entry == null) return;

    // Only handle mute state for videos
    if (entry.media.type != MediaType.video) return;

    final videoData = entry.media.toVideoMediaData();
    if (videoData == null) return;

    final arguments = createVideoArguments(videoData);
    final notifier = ref.read(videoPlayerProvider(arguments).notifier);
    final state = ref.read(videoPlayerProvider(arguments));

    state.maybeMap(
      data: (data) {
        _previousMuteStates[index] = data.isMuted;
        if (data.isMuted) {
          notifier.controller.setVolume(1);
        }
      },
      orElse: () {},
    );
  }

  void _restoreMuteState(int index) {
    final previousMuteState = _previousMuteStates[index];
    if (previousMuteState == null) return;

    final entry = widget.builder(index);
    if (entry == null) return;

    // Only handle mute state for videos
    if (entry.media.type != MediaType.video) return;

    final videoData = entry.media.toVideoMediaData();
    if (videoData == null) return;

    final arguments = createVideoArguments(videoData);
    final notifier = ref.read(videoPlayerProvider(arguments).notifier);
    final state = ref.read(videoPlayerProvider(arguments));

    state.maybeMap(
      data: (data) {
        if (data.isMuted != previousMuteState) {
          notifier.controller.setVolume(previousMuteState ? 0 : 1);
        }
      },
      orElse: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.builder(_index);

    if (entry == null) return const SizedBox();

    return MediaGalleryOverlay(
      tweet: entry.tweet,
      media: entry.media,
      delegates: entry.delegates,
      actions: widget.actions,
      child: HarpyPhotoGallery(
        initialIndex: widget.initialIndex,
        itemCount: widget.itemCount,
        // disallow zooming in on videos
        enableGestures: entry.media.type != MediaType.video,
        builder: (context, index) => widget.builder(index)?.builder(context) ?? const SizedBox(),
        onPageChanged: (index) {
          setState(() => _index = index);
          // Restore mute state of previous video before pausing all videos
          _restoreMuteState(_index);
          ref.read(videoPlayerHandlerProvider).act((notifier) => notifier.pause());
          // Handle mute state of new video after a small delay to allow state to settle
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _handleVideoEntry(index);
            }
          });
        },
      ),
    );
  }
}
