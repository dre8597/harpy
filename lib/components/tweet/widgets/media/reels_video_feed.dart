import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/button/tweet_action_menu.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

/// Shows a like action menu with options to like/unlike and show likes.
Future<void> _showLikeActionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required BlueskyPostData tweet,
  required TweetDelegates delegates,
  required RenderBox renderBox,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final theme = Theme.of(context);
  final onBackground = theme.colorScheme.onSurface;

  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final result = await showRbyMenu(
    context: context,
    position: position,
    items: [
      RbyPopupMenuListTile(
        value: 0,
        leading: const Icon(CupertinoIcons.heart_fill),
        title: Text(
          tweet.isLiked ? 'unlike' : 'like',
          style: TextStyle(color: onBackground),
        ),
      ),
      if (delegates.onShowLikes != null)
        RbyPopupMenuListTile(
          value: 1,
          leading: const Icon(CupertinoIcons.person_2_fill),
          title: Text(
            'show likes',
            style: TextStyle(color: onBackground),
          ),
        ),
    ],
  );

  if (result == 0) {
    tweet.isLiked ? delegates.onUnfavorite?.call(ref) : delegates.onFavorite?.call(ref);
  } else if (result == 1) {
    delegates.onShowLikes?.call(ref);
  }
}

/// Shows a repost action menu with options to repost/unrepost, quote, and view retweeters.
Future<void> _showRepostActionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required BlueskyPostData tweet,
  required TweetDelegates delegates,
  required RenderBox renderBox,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final theme = Theme.of(context);
  final onBackground = theme.colorScheme.onSurface;

  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final result = await showRbyMenu(
    context: context,
    position: position,
    items: [
      RbyPopupMenuListTile(
        value: 0,
        leading: const Icon(CupertinoIcons.repeat),
        title: Text(
          tweet.isReposted ? 'unretweet' : 'retweet',
          style: TextStyle(color: onBackground),
        ),
      ),
      if (delegates.onComposeQuote != null)
        RbyPopupMenuListTile(
          value: 1,
          leading: const Icon(CupertinoIcons.pencil),
          title: Text(
            'quote tweet',
            style: TextStyle(color: onBackground),
          ),
        ),
      if (delegates.onShowRetweeters != null)
        RbyPopupMenuListTile(
          value: 2,
          leading: const Icon(CupertinoIcons.person_2_fill),
          title: Text(
            'view retweeters',
            style: TextStyle(color: onBackground),
          ),
        ),
    ],
  );

  if (result == 0) {
    tweet.isReposted ? delegates.onUnretweet?.call(ref) : delegates.onRetweet?.call(ref);
  } else if (result == 1) {
    delegates.onComposeQuote?.call(ref);
  } else if (result == 2) {
    delegates.onShowRetweeters?.call(ref);
  }
}

/// A TikTok/Instagram Reels style video feed that displays videos in fullscreen
/// with like, retweet & comment buttons on the side.
class ReelsVideoFeed extends ConsumerStatefulWidget {
  const ReelsVideoFeed({
    required this.entries,
    required this.onRefresh,
    this.onLoadMore,
    super.key,
  });

  final List<MediaTimelineEntry> entries;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;

  @override
  ConsumerState<ReelsVideoFeed> createState() => _ReelsVideoFeedState();
}

class _ReelsVideoFeedState extends ConsumerState<ReelsVideoFeed> {
  late final PageController _pageController;
  int _currentIndex = 0;
  VideoPlayerNotifier? _currentNotifier;
  VideoPlayerNotifier? _previousNotifier;
  bool _isActive = true;
  bool _isManuallyPaused = false;
  bool _isCaptionVisible = true;
  Timer? _captionTimer;

  // Increased duration for better readability
  static const _captionDisplayDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startCaptionTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentNotifier?.pause();
    _previousNotifier?.pause();
    _captionTimer?.cancel();
    super.dispose();
  }

  void _startCaptionTimer() {
    _captionTimer?.cancel();
    if (_isCaptionVisible) {
      _captionTimer = Timer(_captionDisplayDuration, () {
        if (mounted) {
          setState(() => _isCaptionVisible = false);
        }
      });
    }
  }

  void _showCaption() {
    setState(() => _isCaptionVisible = true);
    _startCaptionTimer();
  }

  void _handleOverlayTap(TapUpDetails details, BoxConstraints constraints) {
    // Calculate the center zone (30% of width and height)
    final centerWidth = constraints.maxWidth * 0.3;
    final centerHeight = constraints.maxHeight * 0.3;
    final centerX = (constraints.maxWidth - centerWidth) / 2;
    final centerY = (constraints.maxHeight - centerHeight) / 2;

    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    // If tap is outside center zone or in blurred area, show caption
    if (tapX < centerX ||
        tapX > centerX + centerWidth ||
        tapY < centerY ||
        tapY > centerY + centerHeight) {
      _showCaption();
    } else {
      _handleTap();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get the current media view mode
    final mediaPreferences = ref.watch(mediaPreferencesProvider);
    final isReelsMode = mediaPreferences.useReelsVideoMode;

    // If we're switching out of reels mode, pause the video
    if (_isActive && !isReelsMode) {
      _currentNotifier?.pause();
      _isActive = false;
    }
    // If we're switching back to reels mode, resume the video unless manually paused
    else if (!_isActive && isReelsMode) {
      _isActive = true;
      if (_currentNotifier != null && !_isManuallyPaused) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _currentNotifier!.controller.play();
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Reset manual pause state when changing videos
      _isManuallyPaused = false;
      // Show caption for new video
      _isCaptionVisible = true;
    });

    // Reset caption timer for new video
    _startCaptionTimer();

    // Only handle video state changes if reels mode is active
    if (!_isActive) return;

    // Pause previous video and mute it
    if (_previousNotifier != null) {
      _previousNotifier!.pause();
      _previousNotifier!.controller.setVolume(0);
    }

    // Start playing current video and unmute it (reels mode always unmutes)
    if (_currentNotifier != null) {
      _currentNotifier!.controller.setVolume(1);
      if (!mounted) return;
      _currentNotifier!.controller.play();
    }

    // Load more content when reaching the end
    if (index == widget.entries.length - 1 && widget.onLoadMore != null) {
      widget.onLoadMore!();
    }
  }

  void _handleVideoPlayer(VideoPlayerNotifier notifier, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (index == _currentIndex) {
        _currentNotifier = notifier;
        // Listen to player state changes to detect manual pause/play
        notifier.controller.addListener(() {
          if (!mounted) return;
          final isPlaying = notifier.controller.value.isPlaying;
          if (!isPlaying && _isActive && !_isManuallyPaused) {
            setState(() => _isManuallyPaused = true);
          }
        });

        // Only start playing if reels mode is active and not manually paused
        if (_isActive && !_isManuallyPaused) {
          notifier.controller.setVolume(1);
          notifier.controller.play();
        }
      } else if (index == _currentIndex - 1) {
        _previousNotifier = notifier;
      }
    });
  }

  void _handleTap() {
    if (!mounted || !_isActive) return;
    setState(() {
      _isManuallyPaused = !_isManuallyPaused;
      if (_currentNotifier != null) {
        if (_isManuallyPaused) {
          _currentNotifier!.pause();
        } else {
          _currentNotifier!.controller.play();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<RbySpacingTheme>() ?? const RbySpacingTheme(base: 8, small: 4, large: 16);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.entries.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final entry = widget.entries[index];
          final provider = tweetProvider(entry.tweet.id);
          final tweet = ref.watch(provider) ?? entry.tweet;
          final tweetNotifier = ref.watch(provider.notifier);
          final delegates = defaultTweetDelegates(tweet, tweetNotifier);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video player with tap gesture
              LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapUp: (details) => _handleOverlayTap(details, constraints),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blurred background (always present)
                      if (entry.media.thumb != null)
                        Positioned.fill(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: HarpyImage(
                              imageUrl: entry.media.thumb!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),

                      // Centered video container
                      if (entry.media.aspectRatio != null)
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                              maxHeight: constraints.maxHeight,
                            ),
                            child: AspectRatio(
                              aspectRatio: entry.media.aspectRatio!,
                              child: TweetVideo(
                                tweet: tweet,
                                heroTag: 'reels${mediaHeroTag(
                                  context,
                                  tweet: tweet,
                                  media: entry.media,
                                )}',
                                overlayBuilder: (data, notifier, child) {
                                  _handleVideoPlayer(notifier, index);
                                  return DynamicVideoPlayerOverlay(
                                    tweet: tweet,
                                    data: data,
                                    notifier: notifier,
                                    media: entry.media,
                                    delegates: delegates,
                                    child: child,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Caption overlay
              if (tweet.text.isNotEmpty)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: _isCaptionVisible ? spacing.large * 4 : -(spacing.large * 4),
                  child: GestureDetector(
                    onTap: () {
                      // Pause video before navigating
                      if (_currentNotifier != null) {
                        _currentNotifier!.pause();
                      }

                      // Navigate to tweet details
                      delegates.onShowTweet?.call(ref);
                    },
                    child: Container(
                      padding: EdgeInsets.all(spacing.base),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tweet.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tweet.replyCount > 0) ...[
                              SizedBox(height: spacing.small),
                              Text(
                                'View ${tweet.replyCount} ${tweet.replyCount == 1 ? 'comment' : 'comments'}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Overlay with tweet actions
              Positioned(
                right: spacing.base,
                bottom: spacing.large * 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (context) => _ActionButton(
                        icon: const Icon(CupertinoIcons.heart_fill),
                        label: tweet.likeCount.toString(),
                        onTap: () async {
                          final renderBox = context.findRenderObject()! as RenderBox;
                          if (mounted) {
                            await showLikeActionMenu(
                              context: context,
                              ref: ref,
                              tweet: tweet,
                              delegates: delegates,
                              renderBox: renderBox,
                            );
                          }
                        },
                        isActive: tweet.isLiked,
                        activeColor: theme.colorScheme.error,
                      ),
                    ),
                    SizedBox(height: spacing.large),
                    Builder(
                      builder: (context) => _ActionButton(
                        icon: const Icon(CupertinoIcons.repeat),
                        label: tweet.repostCount.toString(),
                        onTap: () async {
                          final renderBox = context.findRenderObject()! as RenderBox;
                          if (mounted) {
                            await showRepostActionMenu(
                              context: context,
                              ref: ref,
                              tweet: tweet,
                              delegates: delegates,
                              renderBox: renderBox,
                            );
                          }
                        },
                        isActive: tweet.isReposted,
                        activeColor: theme.colorScheme.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.large),
                    _ActionButton(
                      icon: const Icon(CupertinoIcons.chat_bubble_fill),
                      label: tweet.replyCount.toString(),
                      onTap: () => delegates.onComposeReply?.call(ref),
                    ),
                    SizedBox(height: spacing.large),
                    _ActionButton(
                      icon: const Icon(CupertinoIcons.ellipsis_vertical),
                      label: '',
                      onTap: () => showTweetActionsBottomSheet(
                        ref,
                        tweet: tweet,
                        delegates: delegates,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? activeColor ?? theme.colorScheme.primary : Colors.white;

    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: IconTheme(
            data: IconThemeData(
              color: color,
              size: 30,
            ),
            child: icon,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}
