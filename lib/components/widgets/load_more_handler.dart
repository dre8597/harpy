import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rby/rby.dart';

/// Listens to the [controller] and calls the [onLoadMore] callback when
/// reaching the end of the scrollable.
///
/// Similar to [LoadMoreListener], except an explicit [controller] is provided
/// which allows us to query the scrollable's extent after loading more to
/// continuesly call [onLoadMore].
class LoadMoreHandler extends StatefulWidget {
  const LoadMoreHandler({
    required this.child,
    required this.controller,
    required this.onLoadMore,
    this.listen = true,
    this.extentTrigger,
    this.scrollThreshold = 0.5,
  });

  final Widget child;
  final ScrollController controller;
  final AsyncCallback onLoadMore;
  final bool listen;

  /// How little quantity of content conceptually "below" the viewport needs to
  /// be scrollable to trigger the [onLoadMore].
  ///
  /// Defaults to half of the scrollable's viewport size.
  final double? extentTrigger;

  /// The scroll threshold (0.0 to 1.0) that determines when to load more content.
  /// A value of 0.5 means the user needs to scroll through 50% of the current
  /// content before more content is loaded.
  final double scrollThreshold;

  @override
  State<LoadMoreHandler> createState() => _LoadMoreHandlerState();
}

class _LoadMoreHandlerState extends State<LoadMoreHandler> {
  bool _loading = false;
  bool _canLoadMore = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LoadMoreHandler oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrollListener);
      widget.controller.addListener(_scrollListener);
    }

    if (!oldWidget.listen && widget.listen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
    }
  }

  void _scrollListener() {
    if (_loading || !widget.listen || !mounted) return;
    if (!widget.controller.hasClients) return;
    if (widget.controller.positions.length != 1) return;

    final position = widget.controller.positions.first;

    // Calculate the scroll progress (0.0 to 1.0)
    final scrollProgress = position.pixels / position.maxScrollExtent;

    // Only allow loading more if we've scrolled past the threshold
    if (scrollProgress >= widget.scrollThreshold) {
      _canLoadMore = true;
    }

    if (_canLoadMore &&
        position.extentAfter <=
            (widget.extentTrigger ?? position.viewportDimension / 2)) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_canLoadMore) return;

    try {
      if (mounted) setState(() => _loading = true);
      await widget.onLoadMore();
      // Reset the load more flag until we scroll past threshold again
      _canLoadMore = false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollListener();
      }
    }
  }

  bool _onNotification(ScrollNotification notification) {
    if (!mounted) return false;

    // Calculate scroll progress for notification-based scrolling
    final scrollProgress =
        notification.metrics.pixels / notification.metrics.maxScrollExtent;

    if (scrollProgress >= widget.scrollThreshold) {
      _canLoadMore = true;
    }

    if (_canLoadMore &&
        notification.metrics.extentAfter <=
            (widget.extentTrigger ??
                notification.metrics.viewportDimension / 2)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: widget.listen && !_loading ? _onNotification : null,
      child: widget.child,
    );
  }
}
