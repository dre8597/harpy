import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/button/replies_button.dart';
import 'package:harpy/components/widgets/video_player/video_player_provider.dart';
import 'package:harpy/components/tweet/widgets/media/utils/video_utils.dart';
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
  VideoPlayerNotifier? _nextNotifier;
  bool _isActive = true;
  bool _isManuallyPaused = false;
  bool _isCaptionVisible = true;
  Timer? _captionTimer;
  bool _hasVideoEnded = false;
  bool _wasScrolledAway = false;
  bool _isLoadingMore = false;

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
      if (_nextNotifier != null) {
        _nextNotifier!.pause();
      }
    });
    _captionTimer?.cancel();
    // Clear active providers when disposing
    ref.read(activeReelsProvidersProvider.notifier).state = {};
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

  /// Helper method to preload the next video in the queue
  void _preloadNextVideo(int currentIndex) {
    if (currentIndex >= widget.entries.length - 1) return;

    final nextEntry = widget.entries[currentIndex + 1];
    final nextProvider = tweetProvider(nextEntry.tweet.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Initialize the next tweet if needed
      ref.read(nextProvider.notifier).initialize(nextEntry.tweet);

      // Get the video notifier for preloading
      final tweet = ref.read(nextProvider) ?? nextEntry.tweet;
      final videoData = tweet.media
          ?.firstWhereOrNull(
            (m) => m.type == MediaType.video,
          )
          ?.toVideoMediaData();

      if (videoData != null) {
        final arguments = createVideoArguments(videoData);
        final provider = videoPlayerProvider(arguments);
        _nextNotifier = ref.read(provider.notifier);
        _nextNotifier?.preload();
      }
    });
  }

  void _handleVideoPlayer(VideoPlayerNotifier notifier, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (index == _currentIndex) {
        final previousNotifier = _currentNotifier;
        _currentNotifier = notifier;

        // Only add listener if it's a new notifier
        if (previousNotifier != notifier) {
          notifier.controller.addListener(() {
            if (!mounted) return;

            final position = notifier.controller.value.position;
            final duration = notifier.controller.value.duration;
            final isPlaying = notifier.controller.value.isPlaying;

            // Check if video has ended
            if (position >= duration) {
              _hasVideoEnded = true;
            }

            // Update manual pause state
            if (!isPlaying && _isActive && !_hasVideoEnded) {
              setState(() => _isManuallyPaused = true);
            }
          });

          // Determine if we should play the video
          final shouldPlay = _isActive &&
              !_isManuallyPaused &&
              !notifier.controller.value.isPlaying &&
              (_wasScrolledAway || !_hasVideoEnded);

          if (shouldPlay) {
            notifier.controller.setVolume(1);
            notifier.controller.play();
          }

          // Reset scroll state
          _wasScrolledAway = false;

          // Update active providers
          _updateActiveProviders(index);

          // Preload the next video
          _preloadNextVideo(index);
        }
      } else if (index == _currentIndex - 1) {
        _previousNotifier = notifier;
      } else if (index == _currentIndex + 1) {
        _nextNotifier = notifier;
      }
    });
  }

  void _updateActiveProviders(int currentIndex) {
    final activeProviders = <VideoPlayerArguments>{};

    // Add current video
    if (currentIndex < widget.entries.length) {
      final currentEntry = widget.entries[currentIndex];
      final videoData = currentEntry.media.toVideoMediaData();
      if (videoData != null) {
        activeProviders.add(createVideoArguments(videoData));
      }
    }

    // Add previous video
    if (currentIndex > 0) {
      final previousEntry = widget.entries[currentIndex - 1];
      final videoData = previousEntry.media.toVideoMediaData();
      if (videoData != null) {
        activeProviders.add(createVideoArguments(videoData));
      }
    }

    // Add next video
    if (currentIndex < widget.entries.length - 1) {
      final nextEntry = widget.entries[currentIndex + 1];
      final videoData = nextEntry.media.toVideoMediaData();
      if (videoData != null) {
        activeProviders.add(createVideoArguments(videoData));
      }
    }

    // Update the active providers
    ref.read(activeReelsProvidersProvider.notifier).state = activeProviders;
  }

  void _onPageChanged(int index) {
    setState(() {
      // Mark that we scrolled away from the current video
      _wasScrolledAway = true;
      _currentIndex = index;
      // Reset states for new video
      _isManuallyPaused = false;
      _hasVideoEnded = false;
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
        _safeVideoOperation(_previousNotifier, (notifier) {
          if (notifier.controller.value.isPlaying) {
            notifier.pause();
          }
        });
      }

      // Update active providers for the new index
      _updateActiveProviders(index);

      // Preload the next video
      _preloadNextVideo(index);
    });

    // Load more content when reaching second to last video
    if (!_isLoadingMore && widget.onLoadMore != null && index >= widget.entries.length - 2) {
      setState(() => _isLoadingMore = true);
      widget.onLoadMore!();

      // Reset loading flag after a delay to prevent multiple calls
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      });
    }
  }

  void _handleTap() {
    if (!mounted || !_isActive) return;
    setState(() {
      if (_hasVideoEnded) {
        // If video has ended, restart it
        _hasVideoEnded = false;
        _isManuallyPaused = false;
        _safeVideoOperation(_currentNotifier, (notifier) {
          notifier.controller.seekTo(Duration.zero);
          notifier.controller.play();
        });
      } else {
        // Toggle pause state
        _isManuallyPaused = !_isManuallyPaused;
        _safeVideoOperation(_currentNotifier, (notifier) {
          if (_isManuallyPaused) {
            notifier.pause();
          } else {
            notifier.controller.play();
          }
        });
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
                  bottom: _isCaptionVisible ? spacing.base : -(spacing.large * 4),
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
                    GestureDetector(
                      onTap: () {
                        // Navigate to user profile
                        context.pushNamed(
                          UserPage.name,
                          pathParameters: {'authorDid': tweet.authorDid},
                        );
                      },
                      child: Column(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage: tweet.authorAvatar.isNotEmpty
                                  ? NetworkImage(tweet.authorAvatar)
                                  : null,
                              child: tweet.authorAvatar.isEmpty ? const Icon(Icons.person) : null,
                            ),
                          ),
                          SizedBox(height: spacing.small),
                          _ScrollingText(
                            text: tweet.author,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxWidth: 80,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.base),
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
                    SizedBox(height: spacing.base),
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
                    SizedBox(height: spacing.base),
                    Repliesbutton(
                      tweet: tweet,
                      onShowReplies: delegates.onShowTweet,
                      sizeDelta: 2,
                    ),
                    SizedBox(height: spacing.base),
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

/// A scrolling text widget that animates horizontally if the text overflows
class _ScrollingText extends StatefulWidget {
  const _ScrollingText({
    required this.text,
    required this.style,
    this.maxWidth = 100.0,
  });

  final String text;
  final TextStyle? style;
  final double maxWidth;

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late double _textWidth;
  final _textKey = GlobalKey();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureText();
      _startScrollingIfNeeded();
    });
  }

  void _measureText() {
    if (!mounted) return;
    final renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _textWidth = renderBox.size.width;
      if (_textWidth > widget.maxWidth) {
        _startScrollingIfNeeded();
      }
    }
  }

  void _startScrollingIfNeeded() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_textWidth > widget.maxWidth) {
        _startScrolling();
      }
    });
  }

  void _startScrolling() {
    if (!mounted) return;
    _scrollController
        .animateTo(
      _textWidth,
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (!mounted) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.maxWidth,
      height: 20,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          key: _textKey,
          style: widget.style,
        ),
      ),
    );
  }
}
