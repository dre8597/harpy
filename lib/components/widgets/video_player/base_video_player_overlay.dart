import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

enum OverlayStyle {
  /// Auto-hiding controls for fullscreen videos
  dynamic,

  /// Always visible controls for tweet cards
  static,

  /// Compact controls for timeline
  compact,
}

class BaseVideoPlayerOverlay extends StatefulWidget {
  const BaseVideoPlayerOverlay({
    super.key,
    required this.child,
    required this.tweet,
    required this.notifier,
    required this.data,
    required this.style,
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
  final OverlayStyle style;
  final BlueskyMediaData media;
  final TweetDelegates delegates;
  final VideoMediaData? mediaData;
  final VoidCallback? onVideoTap;
  final VoidCallback? onVideoLongPress;

  @override
  State<BaseVideoPlayerOverlay> createState() => _BaseVideoPlayerOverlayState();
}

class _BaseVideoPlayerOverlayState extends State<BaseVideoPlayerOverlay>
    with VideoPlayerOverlayMixin {
  Timer? _timer;
  bool _showActions = true;

  bool get _isCompact => widget.style == OverlayStyle.compact;
  bool get _shouldAutoHide => widget.style == OverlayStyle.dynamic;

  @override
  bool get compact => _isCompact;

  @override
  void initState() {
    super.initState();

    overlayInit(widget.data);

    if (_shouldAutoHide && widget.data.isPlaying) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => setState(() => _showActions = false),
      );
    }
  }

  @override
  void didUpdateWidget(covariant BaseVideoPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.data.isFinished) {
      _showActions = true;
    } else if (oldWidget.data.isPlaying != widget.data.isPlaying) {
      _showActions = !widget.data.isPlaying;
    }

    overlayUpdate(oldWidget.data, widget.data);
  }

  void _scheduleHideActions() {
    if (!_shouldAutoHide) return;

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showActions = !widget.data.isPlaying);
    });
  }

  void _handleTap() {
    if (widget.data.isFinished ||
        !widget.data.isPlaying ||
        widget.onVideoTap == null) {
      HapticFeedback.lightImpact();
      widget.notifier.togglePlayback();
    } else {
      widget.onVideoTap?.call();
    }

    if (_shouldAutoHide) {
      if (_showActions) {
        setState(() => _showActions = false);
      } else {
        setState(() => _showActions = true);
        _scheduleHideActions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconTheme = theme.iconTheme;

    return GestureDetector(
      onTap: () {},
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          GestureDetector(
            onTap: _handleTap,
            onLongPress: widget.onVideoLongPress,
            child: widget.child,
          ),
          VideoPlayerDoubleTapActions(
            notifier: widget.notifier,
            data: widget.data,
            compact: _isCompact,
          ),
          Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: _buildControls(theme, iconTheme),
          ),
          if (widget.data.isBuffering)
            ImmediateOpacityAnimation(
              delay: const Duration(milliseconds: 500),
              duration: theme.animation.long,
              child: MediaThumbnailIcon(
                icon: const CircularProgressIndicator(),
                compact: _isCompact,
              ),
            ),
          if (centerIcon != null) centerIcon!,
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme, IconThemeData iconTheme) {
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoPlayerProgressIndicator(
          notifier: widget.notifier,
          compact: _isCompact,
        ),
        IconTheme(
          data: _isCompact
              ? iconTheme.copyWith(size: iconTheme.size! - 4)
              : iconTheme,
          child: VideoPlayerActions(
            data: widget.data,
            notifier: widget.notifier,
            children: [
              SizedBox(
                width:
                    _isCompact ? theme.spacing.small / 2 : theme.spacing.small,
              ),
              VideoPlayerPlaybackButton(
                data: widget.data,
                notifier: widget.notifier,
                padding:
                    _isCompact ? EdgeInsets.all(theme.spacing.small / 2) : null,
              ),
              VideoPlayerMuteButton(
                data: widget.data,
                notifier: widget.notifier,
                padding:
                    _isCompact ? EdgeInsets.all(theme.spacing.small / 2) : null,
              ),
              SizedBox(
                width:
                    _isCompact ? theme.spacing.small / 2 : theme.spacing.small,
              ),
              if (!_isCompact) VideoPlayerProgressText(data: widget.data),
              const Spacer(),
              if (widget.data.qualities.length > 1 && !_isCompact)
                VideoPlayerQualityButton(
                  data: widget.data,
                  notifier: widget.notifier,
                ),
              if (widget.style == OverlayStyle.dynamic)
                const VideoPlayerCloseFullscreenButton()
              else
                VideoPlayerFullscreenButton(
                  tweet: widget.tweet,
                  media: widget.media,
                  delegates: widget.delegates,
                  mediaData: widget.mediaData,
                  padding: _isCompact
                      ? EdgeInsets.all(theme.spacing.small / 2)
                      : null,
                ),
              SizedBox(
                width:
                    _isCompact ? theme.spacing.small / 2 : theme.spacing.small,
              ),
            ],
          ),
        ),
      ],
    );

    if (_shouldAutoHide) {
      return ClipRect(
        child: IgnorePointer(
          ignoring: !_showActions,
          child: AnimatedSlide(
            offset: _showActions ? Offset.zero : const Offset(0, .33),
            duration: theme.animation.short,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _showActions ? 1 : 0,
              duration: theme.animation.short,
              curve: Curves.easeInOut,
              child: controls,
            ),
          ),
        ),
      );
    }

    return controls;
  }
}
