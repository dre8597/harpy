import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

class Timeline extends ConsumerStatefulWidget {
  const Timeline({
    required this.provider,
    this.listKey,
    this.tweetBuilder = TweetList.defaultTweetBuilder,
    this.beginSlivers = const [],
    this.endSlivers = const [SliverBottomPadding()],
    this.refreshIndicatorOffset,
    this.scrollToTopOffset,
    this.onChangeFilter,
    this.onUpdatedTweetVisibility,
  });

  final AutoDisposeStateNotifierProvider<TimelineNotifier, TimelineState>
      provider;
  final Key? listKey;
  final TweetBuilder tweetBuilder;
  final List<Widget> beginSlivers;
  final List<Widget> endSlivers;
  final double? refreshIndicatorOffset;
  final double? scrollToTopOffset;

  /// A callback used to open the filter selection for the
  /// [TimelineState.noData] state.
  final VoidCallback? onChangeFilter;

  final ValueChanged<BlueskyPostData>? onUpdatedTweetVisibility;

  @override
  ConsumerState<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<Timeline> {
  ScrollController? _controller;
  bool _ownsController = false;

  /// The index of the newest visible tweet.
  int _newestVisibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    // Create our own controller
    _controller = ScrollController();
    _ownsController = true;
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller?.dispose();
    }
    _controller = null;
    super.dispose();
  }

  @override
  void deactivate() {
    // Remove listeners but don't dispose when widget is temporarily removed from tree
    _controller?.removeListener(_scrollListener);
    super.deactivate();
  }

  void _scrollListener() {
    // Add any scroll listening logic here if needed
  }

  void _onLayoutFinished({
    required BuiltList<BlueskyPostData> tweets,
    required int firstIndex,
    required int lastIndex,
  }) {
    final index = firstIndex ~/ 2;

    if (tweets.isNotEmpty && _newestVisibleIndex != index) {
      final tweet = tweets[index];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _newestVisibleIndex = index);

        // wait a second to see whether this tweet is still visible before
        // notifying
        Future<void>.delayed(const Duration(seconds: 1)).then((_) {
          if (mounted && _newestVisibleIndex == index) {
            widget.onUpdatedTweetVisibility?.call(tweet);
          }
        });
      });
    }
  }

  Widget _tweetBuilder(TimelineState state, BlueskyPostData tweet, int index) {
    return state.showNewTweetsExist(tweet.rootPostId)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NewTweetsText(state.initialResultsCount),
              VerticalSpacer.normal,
              widget.tweetBuilder(tweet, index),
            ],
          )
        : widget.tweetBuilder(tweet, index);
  }

  void _providerListener(TimelineState? previous, TimelineState next) {
    if (next.scrollToEnd) {
      // scroll to the end after the list has been built
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final mediaQuery = MediaQuery.of(context);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final maxScrollExtend = _controller!.positions.fold<double>(
          0,
          (previousValue, element) => max(
            previousValue,
            element.maxScrollExtent,
          ),
        );

        _controller!.jumpTo(
          // + extra height to make sure we reach the end
          maxScrollExtend + mediaQuery.size.height,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(widget.provider);
    final notifier = ref.watch(widget.provider.notifier);

    ref.listen(widget.provider, _providerListener);

    return ScrollToTop(
      controller: _controller,
      bottomPadding: widget.scrollToTopOffset,
      content: AnimatedNumber(
        duration: theme.animation.short,
        number: _newestVisibleIndex + 1,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          UserScrollDirection.of(context)?.idle();
          await notifier.load();
        },
        edgeOffset: widget.refreshIndicatorOffset ?? 0,
        child: RbyAnimatedSwitcher(
          child: state.maybeWhen(
            loading: () => CustomScrollView(
              slivers: [
                ...widget.beginSlivers,
                VerticalSpacer.normalSliver,
                const TweetListLoadingSliver(),
                ...widget.endSlivers,
              ],
            ),
            error: () => CustomScrollView(
              slivers: [
                ...widget.beginSlivers,
                SliverFillLoadingError(
                  message: const Text('error loading tweets'),
                  onRetry: () => notifier.load(clearPrevious: true),
                ),
                ...widget.endSlivers,
              ],
            ),
            noData: () => CustomScrollView(
              slivers: [
                ...widget.beginSlivers,
                SliverFillLoadingError(
                  message: const Text('no tweets found'),
                  onChangeFilter:
                      notifier.filter != null ? widget.onChangeFilter : null,
                ),
                ...widget.endSlivers,
              ],
            ),
            orElse: () => LoadMoreHandler(
              controller: _controller!,
              listen: state.canLoadMore,
              onLoadMore: notifier.load,
              child: TweetList(
                state.tweets.toList(),
                key: widget.listKey,
                controller: _controller,
                tweetBuilder: (tweet, index) => _tweetBuilder(
                  state,
                  tweet,
                  index,
                ),
                onLayoutFinished: (firstIndex, lastIndex) => _onLayoutFinished(
                  tweets: state.tweets,
                  firstIndex: firstIndex,
                  lastIndex: lastIndex,
                ),
                beginSlivers: widget.beginSlivers,
                endSlivers: [
                  ...?state.mapOrNull(
                    data: (data) => [
                      if (!data.canLoadMore) ...[
                        const SliverFillInfoMessage(
                          secondaryMessage: Text('no more tweets available'),
                        ),
                      ],
                    ],
                    loadingMore: (_) => [
                      const SliverLoadingIndicator(),
                      VerticalSpacer.normalSliver,
                    ],
                  ),
                  ...widget.endSlivers,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
