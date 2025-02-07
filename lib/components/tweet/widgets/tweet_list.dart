import 'dart:math';

import 'package:flutter/material.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

typedef TweetBuilder = Widget Function(BlueskyPostData tweet, int index);
typedef LoadMoreCallback = Future<void> Function();

/// Signature for a function that is called at the end of layout in the list
/// builder.
typedef OnLayoutFinished = void Function(int firstIndex, int lastIndex);

/// Builds a [CustomScrollView] for the [tweets].
class TweetList extends StatefulWidget {
  const TweetList(
    this.tweets, {
    this.controller,
    this.tweetBuilder = defaultTweetBuilder,
    this.onLayoutFinished,
    this.beginSlivers = const [],
    this.endSlivers = const [SliverBottomPadding()],
    this.loadMore,
    this.hasReachedEnd = true,
    this.isLoadingMore = false,
    super.key,
  });

  final List<BlueskyPostData> tweets;
  final ScrollController? controller;
  final TweetBuilder tweetBuilder;
  final OnLayoutFinished? onLayoutFinished;
  final LoadMoreCallback? loadMore;
  final bool hasReachedEnd;
  final bool isLoadingMore;

  final List<Widget> beginSlivers;
  final List<Widget> endSlivers;

  static Widget defaultTweetBuilder(BlueskyPostData tweet, int index) => TweetCard(
        tweet: tweet,
        index: index,
      );

  @override
  State<TweetList> createState() => _TweetListState();
}

class _TweetListState extends State<TweetList> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        !widget.hasReachedEnd &&
        widget.loadMore != null &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _isLoadingMore = true);
      widget.loadMore!().then((_) {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
  }

  Widget _itemBuilder(BuildContext context, int index) {
    return index.isEven
        ? widget.tweetBuilder(widget.tweets[index ~/ 2], index ~/ 2)
        : VerticalSpacer.normal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      controller: _scrollController,
      cacheExtent: 0,
      slivers: [
        ...widget.beginSlivers,
        SliverPadding(
          padding: theme.spacing.edgeInsets,
          sliver: SuperSliverList(
            delegate: _TweetListBuilderDelegate(
              _itemBuilder,
              onLayoutFinished: widget.onLayoutFinished,
              childCount: max(widget.tweets.length * 2 - 1, 0),
            ),
          ),
        ),
        if (widget.isLoadingMore || _isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ...widget.endSlivers,
      ],
    );
  }
}

class _TweetListBuilderDelegate extends SliverChildBuilderDelegate {
  _TweetListBuilderDelegate(
    super.builder, {
    this.onLayoutFinished,
    super.childCount,
  }) : super(
          addAutomaticKeepAlives: false,
        );

  final OnLayoutFinished? onLayoutFinished;

  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    onLayoutFinished?.call(firstIndex, lastIndex);
  }
}
