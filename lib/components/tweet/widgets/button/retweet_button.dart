import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/widgets/button/tweet_action_menu.dart';

class RetweetButton extends ConsumerStatefulWidget {
  const RetweetButton({
    required this.tweet,
    required this.onRetweet,
    required this.onUnretweet,
    required this.onShowRetweeters,
    required this.onComposeQuote,
    this.sizeDelta = 0,
    this.foregroundColor,
  });

  final BlueskyPostData tweet;
  final TweetActionCallback? onRetweet;
  final TweetActionCallback? onUnretweet;
  final TweetActionCallback? onShowRetweeters;
  final TweetActionCallback? onComposeQuote;
  final double sizeDelta;
  final Color? foregroundColor;

  @override
  ConsumerState<RetweetButton> createState() => _RetweetButtonState();
}

class _RetweetButtonState extends ConsumerState<RetweetButton> {
  Future<void> _showMenu() async {
    final renderBox = context.findRenderObject()! as RenderBox;
    if (mounted) {
      await showRepostActionMenu(
        context: context,
        ref: ref,
        tweet: widget.tweet,
        delegates: TweetDelegates(
          onRetweet: widget.onRetweet,
          onUnretweet: widget.onUnretweet,
          onShowRetweeters: widget.onShowRetweeters,
          onComposeQuote: widget.onComposeQuote,
        ),
        renderBox: renderBox,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final harpyTheme = ref.watch(harpyThemeProvider);

    final iconSize = iconTheme.size! + widget.sizeDelta;

    return TweetActionButton(
      active: widget.tweet.isReposted,
      value: widget.tweet.repostCount,
      iconBuilder: (_) => Icon(FeatherIcons.repeat, size: iconSize - 1),
      iconAnimationBuilder: (animation, child) => RotationTransition(
        turns: CurvedAnimation(curve: Curves.easeOutBack, parent: animation),
        child: child,
      ),
      bubblesColor: BubblesColor(
        primary: Colors.lime,
        secondary: Colors.limeAccent,
        tertiary: Colors.green,
        quaternary: Colors.green[900],
      ),
      circleColor: const CircleColor(start: Colors.green, end: Colors.lime),
      foregroundColor: widget.foregroundColor,
      iconSize: iconSize,
      sizeDelta: widget.sizeDelta,
      activeColor: harpyTheme.colors.retweet,
      activate: _showMenu,
      deactivate: _showMenu,
    );
  }
}
