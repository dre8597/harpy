import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/button/replies_button.dart';
import 'package:rby/rby.dart';

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
    // Delay video player state changes to avoid modifying providers during widget lifecycle
    Future(() {
      if (_currentNotifier != null) {
        _currentNotifier!.pause();
      }
      if (_previousNotifier != null) {
        _previousNotifier!.pause();
      }
    });
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

  // Helper method to safely perform video player operations
  void _safeVideoOperation(
    VideoPlayerNotifier? notifier,
    void Function(VideoPlayerNotifier notifier) operation,
  ) {
    if (notifier == null) return;

    try {
      if (!mounted) return;
      final controller = notifier.controller;
      if (controller.value.isInitialized) {
        operation(notifier);
      }
    } catch (e) {
      // Ignore errors from disposed controllers
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

    // Schedule video operations for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Handle previous video
      if (_previousNotifier != null) {
        try {
          final controller = _previousNotifier!.controller;
          if (!controller.value.isPlaying) return;
          _previousNotifier!.pause();
        } catch (e) {
          // Ignore errors from disposed controllers
        }
      }

      // Handle current video
      if (_currentNotifier != null) {
        try {
          final controller = _currentNotifier!.controller;
          if (!controller.value.isInitialized) return;
          if (!mounted) return;
          controller.play();
        } catch (e) {
          // Ignore errors from disposed controllers
        }
      }
    });

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
      _safeVideoOperation(_currentNotifier, (notifier) {
        if (_isManuallyPaused) {
          notifier.pause();
        } else {
          notifier.controller.play();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<RbySpacingTheme>() ??
        const RbySpacingTheme(base: 8, small: 4, large: 16);

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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            tweetNotifier.initialize(tweet);
          });

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
                            imageFilter:
                                ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                  bottom:
                      _isCaptionVisible ? spacing.base : -(spacing.large * 4),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.base,
                        vertical: spacing.small,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0),
                          ],
                          stops: const [0.0, 0.8],
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
                      builder: (context) => FavoriteButton(
                        tweet: tweet,
                        onFavorite: delegates.onFavorite,
                        onUnfavorite: delegates.onUnfavorite,
                        onShowLikes: delegates.onShowLikes,
                        sizeDelta: 2,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: spacing.large),
                    Builder(
                      builder: (context) => RetweetButton(
                        tweet: tweet,
                        onRetweet: delegates.onRetweet,
                        onUnretweet: delegates.onUnretweet,
                        onShowRetweeters: delegates.onShowRetweeters,
                        onComposeQuote: delegates.onComposeQuote,
                        sizeDelta: 2,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: spacing.large),
                    Repliesbutton(
                      tweet: tweet,
                      onShowReplies: delegates.onShowTweet,
                      sizeDelta: 2,
                    ),
                    SizedBox(height: spacing.large),
                    MoreActionsButton(
                      tweet: tweet,
                      sizeDelta: 2,
                      foregroundColor: Colors.white,
                      onViewMoreActions: (ref) => showTweetActionsBottomSheet(
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
