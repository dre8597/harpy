import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/detail/provider/tweet_detail_provider.dart';
import 'package:harpy/components/tweet/detail/widgets/tweet_detail_content.dart';
import 'package:rby/rby.dart';

class TweetDetailPage extends ConsumerStatefulWidget {
  const TweetDetailPage({
    required this.id,
    this.tweet,
  });

  final String id;
  final BlueskyPostData? tweet;

  static const name = 'detail';

  @override
  ConsumerState<TweetDetailPage> createState() => _TweetDetailPageState();
}

class _TweetDetailPageState extends ConsumerState<TweetDetailPage> {
  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback(
      (_) => ref.read(tweetDetailProvider(widget.id).notifier).load(widget.tweet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tweetDetailState = ref.watch(tweetDetailProvider(widget.id));

    return HarpyScaffold(
      child: widget.tweet != null
          ? TweetDetailContent(tweet: widget.tweet!)
          : RbyAnimatedSwitcher(
              child: tweetDetailState.when(
                data: (tweet) => TweetDetailContent(tweet: tweet),
                loading: _TweetDetailLoading.new,
                error: (_, __) => const _TweetDetailError(),
              ),
            ),
    );
  }
}

class _TweetDetailLoading extends StatelessWidget {
  const _TweetDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        HarpySliverAppBar(title: Text('tweet')),
        SliverFillLoadingIndicator(),
      ],
    );
  }
}

class _TweetDetailError extends StatelessWidget {
  const _TweetDetailError();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        HarpySliverAppBar(title: Text('tweet')),
        SliverFillLoadingError(message: Text('error loading tweet')),
      ],
    );
  }
}
