import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

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
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final theme = Theme.of(context);
    final onBackground = theme.colorScheme.onSurface;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(
          renderBox.size.bottomLeft(Offset.zero),
          ancestor: overlay,
        ),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showRbyMenu(
      context: context,
      position: position,
      items: [
        RbyPopupMenuListTile(
          value: 0,
          leading: const Icon(FeatherIcons.repeat),
          title: Text(
            widget.tweet.isReposted ? 'unretweet' : 'retweet',
            style: TextStyle(color: onBackground),
          ),
        ),
        if (widget.onComposeQuote != null)
          RbyPopupMenuListTile(
            value: 1,
            leading: const Icon(FeatherIcons.feather),
            title: Text(
              'quote tweet',
              style: TextStyle(color: onBackground),
            ),
          ),
        if (widget.onShowRetweeters != null)
          RbyPopupMenuListTile(
            value: 2,
            leading: const Icon(FeatherIcons.users),
            title: Text(
              'view retweeters',
              style: TextStyle(color: onBackground),
            ),
          ),
      ],
    );

    if (mounted) {
      if (result == 0) {
        widget.tweet.isReposted
            ? widget.onUnretweet?.call(ref)
            : widget.onRetweet?.call(ref);
      } else if (result == 1) {
        widget.onComposeQuote?.call(ref);
      } else if (result == 2) {
        widget.onShowRetweeters?.call(ref);
      }
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
