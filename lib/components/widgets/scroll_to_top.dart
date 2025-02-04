import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

/// Builds a button at the bottom of the screen that animate in or out of the
/// screen based on the scroll offset and direction.
///
/// A [ScrollDirectionListener] must be built above this widget to provide the
/// current [ScrollDirection].
///
/// If no [controller] is provided, a new ScrollController will be created and
/// managed by this widget.
class ScrollToTop extends ConsumerStatefulWidget {
  const ScrollToTop({
    required this.child,
    this.content,
    this.bottomPadding,
    this.controller,
  });

  final Widget child;
  final Widget? content;
  final double? bottomPadding;
  final ScrollController? controller;

  @override
  ConsumerState<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends ConsumerState<ScrollToTop> {
  ScrollController? _controller;
  bool _show = false;
  bool _isAttached = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (widget.controller != null) {
      _controller = widget.controller;
      _ownsController = false;
    } else {
      _controller = ScrollController();
      _ownsController = true;
    }
    _tryAttachController();
  }

  void _tryAttachController() {
    if (_isAttached || _controller == null) return;

    if (_controller!.hasClients) {
      _controller!.addListener(_scrollListener);
      _isAttached = true;
    }
  }

  @override
  void didUpdateWidget(ScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _detachController();

      // If we were using our own controller, dispose it
      if (_ownsController) {
        _controller?.dispose();
      }

      // Initialize with new controller
      _initializeController();
    }
  }

  void _detachController() {
    if (_controller != null && _isAttached) {
      _controller!.removeListener(_scrollListener);
      _isAttached = false;
    }
  }

  @override
  void dispose() {
    _detachController();
    // Only dispose the controller if we created it
    if (_ownsController) {
      _controller?.dispose();
    }
    _controller = null;
    super.dispose();
  }

  void _scrollListener() {
    if (!mounted || _controller == null || !_controller!.hasClients) {
      _detachController();
      return;
    }

    if (_controller!.positions.length != 1) return;

    final mediaQuery = MediaQuery.of(context);
    final scrollDirection = UserScrollDirection.scrollDirectionOf(context);

    final show = _controller!.positions.first.pixels > mediaQuery.size.height &&
        scrollDirection == ScrollDirection.forward;

    if (mounted && show != _show) setState(() => _show = show);
  }

  void _scrollToTop() {
    if (!mounted || _controller == null || !_controller!.hasClients) return;
    if (_controller!.positions.length != 1) return;

    final mediaQuery = MediaQuery.of(context);
    final animationOffsetLimit = mediaQuery.size.height * 5;

    final position = _controller!.positions.first;

    if (position.pixels > animationOffsetLimit) {
      position.jumpTo(0);
    } else {
      position.animateTo(
        0,
        duration: lerpDuration(
          const Duration(milliseconds: 500),
          const Duration(seconds: 1),
          mediaQuery.size.height / animationOffsetLimit,
        ),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,
        Align(
          alignment: AlignmentDirectional.bottomCenter,
          child: AnimatedOpacity(
            opacity: _show ? 1 : 0,
            curve: Curves.easeInOut,
            duration: theme.animation.short,
            child: AnimatedSlide(
              offset: _show ? Offset.zero : const Offset(0, 1),
              curve: Curves.easeInOut,
              duration: theme.animation.short,
              child: _ScrollToTopButton(
                onTap: _scrollToTop,
                content: widget.content,
                bottomPadding: widget.bottomPadding,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollToTopButton extends ConsumerWidget {
  const _ScrollToTopButton({
    required this.onTap,
    this.content,
    this.bottomPadding,
  });

  final VoidCallback onTap;
  final Widget? content;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final harpyTheme = ref.watch(harpyThemeProvider);

    return Padding(
      padding: theme.spacing.edgeInsets.copyWith(
        bottom: bottomPadding ?? theme.spacing.base + mediaQuery.padding.bottom,
      ),
      child: Material(
        color: harpyTheme.colors.alternateCardColor,
        borderRadius: theme.shape.borderRadius,
        child: InkWell(
          borderRadius: theme.shape.borderRadius,
          onTap: onTap,
          child: Padding(
            padding: theme.spacing.edgeInsets,
            child: AnimatedSize(
              duration: theme.animation.short,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.arrow_up),
                  if (content != null) ...[HorizontalSpacer.small, content!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
