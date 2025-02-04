import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.tweet,
    required this.onFavorite,
    required this.onUnfavorite,
    required this.onShowLikes,
    this.sizeDelta = 0,
    this.foregroundColor,
  });

  final BlueskyPostData tweet;
  final TweetActionCallback? onFavorite;
  final TweetActionCallback? onUnfavorite;
  final TweetActionCallback? onShowLikes;
  final double sizeDelta;
  final Color? foregroundColor;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  Future<void> _showMenu() async {
    final renderBox = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
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
          leading: const Icon(FeatherIcons.heart),
          title: Text(
            widget.tweet.isLiked ? 'unlike' : 'like',
            style: TextStyle(color: onBackground),
          ),
        ),
        if (widget.onShowLikes != null)
           RbyPopupMenuListTile(
            value: 1,
            leading: const Icon(FeatherIcons.users),
            title: Text(
              'show likes',
              style: TextStyle(color: onBackground),
            ),
          ),
      ],
    );

    if (mounted) {
      if (result == 0) {
        widget.tweet.isLiked ? widget.onUnfavorite?.call(ref) : widget.onFavorite?.call(ref);
      } else if (result == 1) {
        widget.onShowLikes?.call(ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final harpyTheme = ref.watch(harpyThemeProvider);

    final iconSize = iconTheme.size! + widget.sizeDelta;

    return TweetActionButton(
      active: widget.tweet.isLiked,
      value: widget.tweet.likeCount,
      iconBuilder: (_) => Icon(FeatherIcons.heart, size: iconSize),
      iconAnimationBuilder: (animation, child) => ScaleTransition(
        scale: CurvedAnimation(curve: Curves.elasticOut, parent: animation),
        child: child,
      ),
      bubblesColor: BubblesColor(
        primary: Colors.red[300]!,
        secondary: Colors.red,
        tertiary: Colors.red[900],
        quaternary: Colors.red[800],
      ),
      circleColor: CircleColor(start: Colors.red[300]!, end: Colors.red),
      foregroundColor: widget.foregroundColor,
      iconSize: iconSize,
      sizeDelta: widget.sizeDelta,
      activeColor: harpyTheme.colors.favorite,
      activate: _showMenu,
      deactivate: _showMenu,
    );
  }
}
