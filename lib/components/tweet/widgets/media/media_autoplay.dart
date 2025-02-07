import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';

/// Starts initialization for a video player when the child becomes visible.
///
/// Requires a [VisibilityChangeListener] to be built above this widget.
/// This widget focuses on managing video playback based on visibility changes
/// and autoplay preferences.
class MediaAutoplay extends ConsumerStatefulWidget {
  const MediaAutoplay({
    required this.child,
    required this.state,
    required this.notifier,
    required this.enableAutoplay,
  });

  final Widget child;
  final VideoPlayerState state;
  final VideoPlayerNotifier notifier;
  final bool enableAutoplay;

  @override
  ConsumerState<MediaAutoplay> createState() => _MediaAutoplayState();
}

class _MediaAutoplayState extends ConsumerState<MediaAutoplay> {
  bool _visible = false;

  VisibilityChange? _visibilityChange;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _visibilityChange ??= VisibilityChange.of(context)
      ?..addCallback(_onVisibilityChanged);

    assert(_visibilityChange != null);
  }

  @override
  void dispose() {
    _visibilityChange?.removeCallback(_onVisibilityChanged);
    super.dispose();
  }

  Future<void> _onVisibilityChanged(bool visible) async {
    if (!mounted) return;

    final wasVisible = _visible;
    _visible = visible;

    // Handle visibility changes
    if (!visible) {
      // Pause video when it becomes invisible
      if (widget.state is VideoPlayerStateData) {
        final data = widget.state as VideoPlayerStateData;
        if (data.isPlaying) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_visible) {
              widget.notifier.pause();
            }
          });
        }
      }
      return;
    }

    // Only proceed if we're becoming visible and autoplay is enabled
    if (!visible || !widget.enableAutoplay) return;

    // Handle different video player states when becoming visible
    if (widget.state is VideoPlayerStateUninitialized) {
      // Start initialization process if not already initialized
      await widget.notifier.initialize();
    } else if (widget.state is VideoPlayerStateData && !wasVisible) {
      // Resume playback if video was previously playing
      final data = widget.state as VideoPlayerStateData;
      if (!data.isPlaying && !data.isFinished) {
        await widget.notifier.togglePlayback();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
